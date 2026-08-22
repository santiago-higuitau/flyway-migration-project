"""
ELT: Neon (dominio biblioteca) -> Snowflake LIBRARY_DW.RAW.

Uso:
    uv run elt_neon_to_library_dw.py                      # dev (default)
    uv run elt_neon_to_library_dw.py --entorno main
    uv run elt_neon_to_library_dw.py --tabla books
    uv run elt_neon_to_library_dw.py --solo-verificar
"""

from __future__ import annotations

import argparse
import os
import sys

import pandas as pd
import psycopg2
import snowflake.connector
from dotenv import load_dotenv
from snowflake.connector.pandas_tools import write_pandas

TABLAS = [
    "authors",
    "categories",
    "books",
    "books_authors",
    "books_categories",
    "editions",
    "copies",
    "users",
    "librarians",
    "loans",
    "penalties",
]

MAPA_TIPOS_SNOWFLAKE = {
    "int64": "NUMBER",
    "float64": "FLOAT",
    "bool": "BOOLEAN",
    "datetime64[ns]": "TIMESTAMP_NTZ",
    "object": "VARCHAR",
}


def conectar_neon(entorno: str) -> psycopg2.extensions.connection:
    variable = "NEON_DEV_DATABASE_URL" if entorno == "dev" else "NEON_MAIN_DATABASE_URL"
    url = os.getenv(variable)
    if not url:
        print(f"ERROR: falta {variable} en .env", file=sys.stderr)
        sys.exit(1)
    return psycopg2.connect(url)


def extraer_tabla(conexion_pg, tabla: str) -> pd.DataFrame:
    with conexion_pg.cursor() as cursor:
        cursor.execute(f"SELECT * FROM {tabla}")
        columnas = [c.name.upper() for c in cursor.description]
        filas = cursor.fetchall()
    return pd.DataFrame(filas, columns=columnas)


def calcular_drift(columnas_dataframe: set[str], columnas_snowflake: set[str]) -> set[str]:
    return columnas_dataframe - columnas_snowflake


def construir_ddl_evolucion(tabla: str, columnas_nuevas: set[str], df: pd.DataFrame) -> str:
    lineas = []
    for columna in sorted(columnas_nuevas):
        tipo_pandas = str(df[columna].dtype)
        tipo_snowflake = MAPA_TIPOS_SNOWFLAKE.get(tipo_pandas, "VARCHAR")
        lineas.append(f'ALTER TABLE {tabla.upper()} ADD COLUMN "{columna}" {tipo_snowflake};')
    return "\n".join(lineas)


def conectar_snowflake() -> snowflake.connector.SnowflakeConnection:
    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        password=os.environ["SNOWFLAKE_PASSWORD"],
        warehouse=os.environ["SNOWFLAKE_WAREHOUSE"],
        database=os.environ["SNOWFLAKE_DATABASE"],
        schema=os.environ.get("SNOWFLAKE_SCHEMA", "RAW"),
        role=os.environ.get("SNOWFLAKE_ROLE"),
    )


def columnas_existentes_en_snowflake(conexion_sf, esquema: str, tabla: str) -> set[str]:
    with conexion_sf.cursor() as cursor:
        cursor.execute(
            "SELECT column_name FROM information_schema.columns "
            "WHERE table_schema = %s AND table_name = %s",
            (esquema.upper(), tabla.upper()),
        )
        return {fila[0] for fila in cursor.fetchall()}


def cargar_tabla(conexion_sf, tabla: str, df: pd.DataFrame, esquema: str) -> int:
    existentes = columnas_existentes_en_snowflake(conexion_sf, esquema, tabla)

    if existentes:
        drift = calcular_drift(set(df.columns), existentes)
        if drift:
            ddl = construir_ddl_evolucion(tabla, drift, df)
            raise RuntimeError(
                f"\nSchema drift en {tabla.upper()}: columna(s) nueva(s) en Neon "
                f"que Snowflake no tiene: {sorted(drift)}.\n\n"
                f"Aplica esto en Snowsight y vuelve a correr:\n\n{ddl}\n"
            )

    exito, _, num_filas, _ = write_pandas(
        conexion_sf, df, table_name=tabla.upper(),
        auto_create_table=True, overwrite=True,
    )
    if not exito:
        raise RuntimeError(f"write_pandas reporto fallo al cargar {tabla}")

    return num_filas


def main() -> int:
    parser = argparse.ArgumentParser(description="ELT de Neon (biblioteca) hacia LIBRARY_DW.RAW.")
    parser.add_argument("--entorno", choices=["dev", "main"], default="dev", help="Branch de Neon origen (default: dev).")
    parser.add_argument("--tabla", choices=TABLAS, help="Cargar solo esta tabla.")
    parser.add_argument("--solo-verificar", action="store_true", help="Detecta drift, no carga.")
    argumentos = parser.parse_args()

    load_dotenv()
    tablas = [argumentos.tabla] if argumentos.tabla else TABLAS
    esquema = os.environ.get("SNOWFLAKE_SCHEMA", "RAW")

    print(f"Entorno Neon: {argumentos.entorno}")
    conexion_pg = conectar_neon(argumentos.entorno)
    conexion_sf = conectar_snowflake()
    try:
        for tabla in tablas:
            print(f"Extrayendo {tabla} desde Neon...")
            df = extraer_tabla(conexion_pg, tabla)
            print(f"  {len(df)} filas - columnas: {list(df.columns)}")

            if argumentos.solo_verificar:
                existentes = columnas_existentes_en_snowflake(conexion_sf, esquema, tabla)
                drift = calcular_drift(set(df.columns), existentes) if existentes else set()
                print(f"  [verificacion] {'DRIFT: ' + str(sorted(drift)) if drift else 'sin drift'}")
                continue

            num_filas = cargar_tabla(conexion_sf, tabla, df, esquema)
            print(f"  OK -> {num_filas} filas en {esquema}.{tabla.upper()}")

        return 0
    except RuntimeError as error:
        print(f"\nERROR: {error}", file=sys.stderr)
        return 1
    finally:
        conexion_pg.close()
        conexion_sf.close()


if __name__ == "__main__":
    sys.exit(main())
