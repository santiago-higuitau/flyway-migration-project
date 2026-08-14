"""
Genera datos sinteticos para el modelo de biblioteca y escribe el resultado
como una migracion Flyway (sql_migrations/V<timestamp>__seed_data.sql).

Este script NUNCA se conecta a una base de datos. Solo produce texto SQL.
Por eso los ids no se generan con RETURNING de psycopg2: se asumen
secuenciales (1, 2, 3...) en el mismo orden en que se insertan las filas,
sobre tablas que empiezan vacias. Coincide con lo que Postgres asignaria
via GENERATED ALWAYS AS IDENTITY al correr el INSERT real.

Uso:
    uv run data_generation.py
"""

from __future__ import annotations

import random
from dataclasses import dataclass
from datetime import date, timedelta
from pathlib import Path

from faker import Faker

# ---------------------------------------------------------------------------
# Reproducibilidad: fijamos la semilla para que el archivo SQL generado sea
# revisable y comparable entre corridas (mismos datos, mismo diff en git).
# ---------------------------------------------------------------------------
SEED = 20260811
random.seed(SEED)
Faker.seed(SEED)

# Varios locales a la vez: Faker elige uno al azar en cada llamada, lo que
# mezcla nombres en espanol e ingles de forma natural, sin logica propia.
fake = Faker(["es_CO", "en_US"])

MIGRATIONS_DIR = Path(__file__).resolve().parent.parent / "sql_migrations"
OUTPUT_FILE = MIGRATIONS_DIR / "V202608111535__seed_data.sql"

# Volumenes por tabla.
N_AUTHORS = 40
N_CATEGORIES = 16
N_BOOKS = 80
N_USERS = 160
N_LIBRARIANS = 12
N_LOANS = 400

CATEGORY_NAMES = [
    "Ficcion", "Ciencia ficcion",
    "Fantasia", "Historia", "Biografia",
    "Ciencia", "Tecnologia", "Poesia",
    "Ensayo", "Misterio", "Romance", 
    "Aventura", "Filosofia", "Economia", 
    "Arte", "Infantil",
]

BOOK_TITLE_WORDS_ES = [
    "sombra", "camino", "jardin", 
    "silencio", "viaje", "memoria",
    "espejo", "rio", "invierno", 
    "ciudad", "estrella", "puerta",
]
BOOK_TITLE_WORDS_EN = [
    "shadow", "road", "garden", 
    "silence", "journey", "memory",
    "mirror", "river", "winter", 
    "city", "star", "door",
]


def sql_escape(value: str) -> str:
    """Escapa comillas simples para insertarlas de forma segura en SQL."""
    return value.replace("'", "''")


def sql_str(value: str | None) -> str:
    if value is None:
        return "NULL"
    return f"'{sql_escape(value)}'"


def sql_date(value: date | None) -> str:
    if value is None:
        return "NULL"
    return f"'{value.isoformat()}'"


def sql_num(value) -> str:
    return "NULL" if value is None else str(value)


def sql_bool(value: bool) -> str:
    return "TRUE" if value else "FALSE"


def make_isbn13() -> str:
    """
    Genera un ISBN-13 con formato valido (no verifica el digito de control).
    Faker no trae un provider de ISBN por defecto, y agregar una dependencia
    extra solo para esto no se justifica en un script de datos sinteticos.
    """
    digits = "".join(str(random.randint(0, 9)) for _ in range(9))
    return f"978{digits}"[:13]


def make_title() -> tuple:
    """Devuelve (titulo, idioma_original), mezclando espanol e ingles."""
    if random.random() < 0.5:
        word = random.choice(BOOK_TITLE_WORDS_ES)
        title = f"El {word.capitalize()} de {fake.first_name()}"
        return title, "es"

    word = random.choice(BOOK_TITLE_WORDS_EN)
    title = f"The {word.capitalize()} of {fake.first_name()}"
    return title, "en"


def batched_insert(table: str, columns: list, rows: list, chunk_size: int = 100) -> str:
    """Construye uno o mas INSERT multi-fila, en bloques, para legibilidad."""
    if not rows:
        return ""

    col_list = ", ".join(columns)
    statements = []
    for start in range(0, len(rows), chunk_size):
        chunk = rows[start : start + chunk_size]
        values_sql = ",\n    ".join(f"({', '.join(row)})" for row in chunk)
        statements.append(f"INSERT INTO {table} ({col_list}) VALUES\n    {values_sql};")

    return "\n\n".join(statements)


@dataclass
class Generated:
    sql_blocks: list[str]


def generate() -> Generated:
    blocks: list[str] = []

    # -----------------------------------------------------------------
    # authors (~20% de autores historicos, con fecha de fallecimiento.)
    # -----------------------------------------------------------------
    author_rows = []
    for _ in range(N_AUTHORS):
        name = fake.name()
        place_of_birth = fake.city()
        nationality = fake.current_country()
        birth_date = fake.date_of_birth(minimum_age=30, maximum_age=90)
        death_date = None
        if random.random() < 0.2:
            candidate = birth_date + timedelta(days=random.randint(60 * 365, 85 * 365))

            if candidate < date.today():
                death_date = candidate

        author_rows.append(
            (
                sql_str(name),
                sql_str(place_of_birth),
                sql_str(nationality),
                sql_date(birth_date),
                sql_date(death_date),
            )
        )
    blocks.append(
        batched_insert(
            "authors",
            ["name", "place_of_birth", "nationality", "birth_date", "death_date"],
            author_rows,
        )
    )

    # -----------------------------------------------------------------
    # categories
    # -----------------------------------------------------------------
    category_rows = []
    for name in CATEGORY_NAMES:
        description = f"Libros clasificados bajo el genero {name.lower()}."
        category_rows.append((sql_str(name), sql_str(description)))

    blocks.append(batched_insert("categories", ["name", "description"], category_rows))

    # -----------------------------------------------------------------
    # books
    # -----------------------------------------------------------------
    book_rows = []
    book_languages: list[str] = []
    for _ in range(N_BOOKS):
        title, lang = make_title()
        isbn = make_isbn13()
        book_languages.append(lang)
        book_rows.append((sql_str(title), sql_str(isbn), sql_str(lang)))

    blocks.append(batched_insert("books", ["title", "isbn", "original_language"], book_rows))

    # -----------------------------------------------------------------
    # books_authors (1 o 2 autores por libro)
    # -----------------------------------------------------------------
    books_authors_rows = []
    for book_id in range(1, N_BOOKS + 1):
        n_authors = 1 if random.random() < 0.75 else 2
        chosen = random.sample(range(1, N_AUTHORS + 1), k=n_authors)

        for author_id in chosen:
            books_authors_rows.append((sql_num(book_id), sql_num(author_id)))

    blocks.append(
        batched_insert("books_authors", ["book_id", "author_id"], books_authors_rows)
    )

    # -----------------------------------------------------------------
    # books_categories (1 o 2 categorias por libro)
    # -----------------------------------------------------------------
    books_categories_rows = []
    for book_id in range(1, N_BOOKS + 1):
        n_categories = 1 if random.random() < 0.6 else 2
        chosen = random.sample(range(1, N_CATEGORIES + 1), k=n_categories)

        for category_id in chosen:
            books_categories_rows.append((sql_num(book_id), sql_num(category_id)))

    blocks.append(
        batched_insert("books_categories", ["book_id", "category_id"], books_categories_rows)
    )

    # -----------------------------------------------------------------
    # editions (120 en total: 40 libros con 2 ediciones, 40 con 1)
    # -----------------------------------------------------------------
    edition_rows = []
    edition_book_ids: list[int] = []
    books_with_two = set(random.sample(range(1, N_BOOKS + 1), k=40))
    for book_id in range(1, N_BOOKS + 1):
        n_editions = 2 if book_id in books_with_two else 1

        for _ in range(n_editions):
            publisher = fake.company()
            release_year = random.randint(1990, 2025)
            page_count = random.randint(120, 620)
            language = book_languages[book_id - 1]
            replacement_cost = round(random.uniform(8.0, 45.0), 2)
            edition_book_ids.append(book_id)
            edition_rows.append(
                (
                    sql_num(book_id),
                    sql_str(publisher),
                    sql_num(release_year),
                    sql_num(page_count),
                    sql_str(language),
                    sql_num(replacement_cost),
                )
            )
    blocks.append(
        batched_insert(
            "editions",
            ["book_id", "publisher", "release_year", "page_count", "language", "replacement_cost"],
            edition_rows,
        )
    )
    n_editions_total = len(edition_rows)

    # -----------------------------------------------------------------
    # copies (300 en total, repartidas entre las ediciones)
    # -----------------------------------------------------------------
    copy_rows = []
    copy_edition_ids: list[int] = []
    remaining = 300
    for edition_id in range(1, n_editions_total + 1):
        editions_left = n_editions_total - edition_id + 1
        max_for_this = remaining - (editions_left - 1)  # al menos 1 para cada edicion restante
        n_copies = min(max_for_this, random.randint(1, 4)) if editions_left > 1 else remaining
        n_copies = max(1, n_copies)
        remaining -= n_copies

        for i in range(n_copies):
            inventory_code = f"BIB-{edition_id:04d}-{i + 1:02d}"
            status_roll = random.random()
            status = "available" if status_roll < 0.75 else ("loaned" if status_roll < 0.95 else "damaged")
            acquired_at = fake.date_between(start_date="-10y", end_date="-30d")
            shelf = random.choice("ABCDEF")
            section = random.randint(1, 12)
            physical_location = f"Estante {shelf}, Seccion {section}"
            copy_edition_ids.append(edition_id)
            copy_rows.append(
                (
                    sql_num(edition_id),
                    sql_str(inventory_code),
                    sql_str(status),
                    sql_date(acquired_at),
                    sql_str(physical_location),
                )
            )
    blocks.append(
        batched_insert(
            "copies",
            ["edition_id", "inventory_code", "status", "acquired_at", "physical_location"],
            copy_rows,
        )
    )
    n_copies_total = len(copy_rows)

    # -----------------------------------------------------------------
    # users
    # -----------------------------------------------------------------
    user_rows = []
    for _ in range(N_USERS):
        name = fake.name()
        registered_at = fake.date_between(start_date="-6y", end_date="-1d")
        status = "active" if random.random() < 0.9 else "inactive"
        birth_date = fake.date_of_birth(minimum_age=14, maximum_age=80)
        email = fake.unique.email()
        user_rows.append(
            (
                sql_str(name),
                sql_date(registered_at),
                sql_str(status),
                sql_date(birth_date),
                sql_str(email),
            )
        )
    blocks.append(
        batched_insert(
            "users",
            ["name", "registered_at", "status", "birth_date", "email"],
            user_rows,
        )
    )

    # -----------------------------------------------------------------
    # librarians
    # -----------------------------------------------------------------
    librarian_rows = []
    roles = ["auxiliar", "coordinador", "bibliotecario senior"]
    for _ in range(N_LIBRARIANS):
        name = fake.name()
        hired_at = fake.date_between(start_date="-8y", end_date="-30d")
        status = "active" if random.random() < 0.95 else "inactive"
        email = fake.unique.email()
        role = random.choice(roles)
        librarian_rows.append(
            (
                sql_str(name),
                sql_date(hired_at),
                sql_str(status),
                sql_str(email),
                sql_str(role),
            )
        )
    blocks.append(
        batched_insert(
            "librarians",
            ["name", "hired_at", "status", "email", "role"],
            librarian_rows,
        )
    )

    # -----------------------------------------------------------------
    # loans: mezcla realista de a tiempo, atrasados y aun abiertos.
    # -----------------------------------------------------------------
    loan_rows = []
    today = date.today()
    for _ in range(N_LOANS):
        copy_id = random.randint(1, n_copies_total)
        user_id = random.randint(1, N_USERS)
        librarian_id = random.randint(1, N_LIBRARIANS)

        loan_date = fake.date_between(start_date="-2y", end_date="-1d")
        due_date = loan_date + timedelta(days=14)

        outcome = random.random()
        if outcome < 0.15 and loan_date >= today - timedelta(days=25):
            returned_at = None

        elif outcome < 0.75:
            days_early = random.randint(0, 14)
            returned_at = min(due_date, loan_date + timedelta(days=random.randint(1, 14 - days_early + 1)))

        else:
            # Devuelto tarde.
            returned_at = due_date + timedelta(days=random.randint(1, 20))

        if returned_at is not None and returned_at > today:
            returned_at = today

        loan_rows.append(
            (
                sql_num(copy_id),
                sql_num(user_id),
                sql_num(librarian_id),
                sql_date(loan_date),
                sql_date(due_date),
                sql_date(returned_at),
            )
        )
    blocks.append(
        batched_insert(
            "loans",
            ["copy_id", "user_id", "librarian_id", "loan_date", "due_date", "returned_at"],
            loan_rows,
        )
    )

    return Generated(sql_blocks=[b for b in blocks if b])


def write_migration(generated: Generated) -> None:
    header = f"""-- Datos sinteticos para el modelo de biblioteca.
-- Generado por code/data_generation.py (semilla Faker/random = {SEED}).
-- No se conecta a ninguna base: solo produce las sentencias INSERT que
-- Flyway aplica como cualquier otra migracion versionada.
"""
    content = header + "\n\n".join(generated.sql_blocks) + "\n"
    OUTPUT_FILE.write_text(content, encoding="utf-8")
    print(f"Escrito: {OUTPUT_FILE}")


def main() -> None:
    generated = generate()
    write_migration(generated)


if __name__ == "__main__":
    main()
