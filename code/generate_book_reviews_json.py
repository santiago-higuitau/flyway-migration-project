"""
Genera 5 archivos JSON de resenas de lectores por libro (fuente semi-
estructurada para el Modulo M2-3: External Stage + VARIANT + LATERAL FLATTEN).
No se conecta a ninguna base de datos. `book_id` usa el mismo rango 1..80
de code/data_generation.py.

Uso:
    uv run generate_book_reviews_json.py
"""

from __future__ import annotations

import json
import random
from datetime import date, datetime
from pathlib import Path

from faker import Faker

SEED = 20260821
random.seed(SEED)
Faker.seed(SEED)

fake = Faker(["es_CO", "en_US"])

JSON_OUTPUT_DIR = Path(__file__).resolve().parent.parent / "data" / "json"
N_BATCHES = 5
N_BOOKS_IN_CATALOG = 80

BOOK_TITLE_WORDS_ES = [
    "sombra", "camino", "jardin", "silencio", "viaje", "memoria",
    "espejo", "rio", "invierno", "ciudad", "estrella", "puerta",
]
BOOK_TITLE_WORDS_EN = [
    "shadow", "road", "garden", "silence", "journey", "memory",
    "mirror", "river", "winter", "city", "star", "door",
]

REVIEW_TAGS = [
    "ritmo-lento", "ritmo-agil", "final-inesperado", "final-predecible",
    "bien-escrito", "traduccion-mejorable", "recomendado", "sobrevalorado",
    "para-releer", "denso", "emotivo", "divertido",
]

COMMENT_TEMPLATES_ES = [
    "Me atrapo desde el primer capitulo, no pude dejarlo.",
    "La trama se siente repetitiva hacia la mitad del libro.",
    "Uno de los mejores que he leido este anio.",
    "Esperaba mas desarrollo de los personajes secundarios.",
    "El final me dejo pensando varios dias.",
    "La edicion tiene varias erratas que distraen la lectura.",
    "Perfecto para quienes disfrutan un ritmo pausado.",
    "No lo recomendaria, se sintio muy predecible.",
]
COMMENT_TEMPLATES_EN = [
    "Couldn't put it down, finished it in two days.",
    "The pacing drags a lot in the middle section.",
    "One of the best releases I've read this year.",
    "Wished the secondary characters had more depth.",
    "The ending left me thinking for days.",
    "This edition has a few distracting typos.",
    "Great pick if you enjoy a slow-burn story.",
    "Wouldn't recommend it, felt too predictable.",
]


def make_book_title() -> tuple[str, str]:
    if random.random() < 0.5:
        word = random.choice(BOOK_TITLE_WORDS_ES)
        return f"El {word.capitalize()} de {fake.first_name()}", "es"

    word = random.choice(BOOK_TITLE_WORDS_EN)
    return f"The {word.capitalize()} of {fake.first_name()}", "en"


def make_isbn13() -> str:
    digits = "".join(str(random.randint(0, 9)) for _ in range(9))
    return f"978{digits}"[:13]


def make_comment(lang: str) -> str:
    return random.choice(COMMENT_TEMPLATES_ES if lang == "es" else COMMENT_TEMPLATES_EN)


def make_review(batch_number: int, review_seq: int, book_lang: str) -> dict:
    review = {
        "review_id": f"REV-{batch_number}-{review_seq:04d}",
        "reviewer_name": fake.name(),
        "rating": random.choices([1, 2, 3, 4, 5], weights=[3, 5, 12, 35, 45])[0],
        "comment": make_comment(book_lang),
        "submitted_at": fake.date_between(start_date="-90d", end_date="-1d").isoformat(),
        "verified_loan": random.random() < 0.55,
    }

    # ~30% sin `tags` (ni siquiera vacio) -- caso de prueba para FLATTEN.
    if random.random() >= 0.30:
        n_tags = random.randint(1, 3)
        review["tags"] = random.sample(REVIEW_TAGS, k=n_tags)

    return review


def make_batch(batch_number: int, batch_month: date) -> list[dict]:
    n_books_this_batch = random.randint(10, 20)
    book_ids = random.sample(range(1, N_BOOKS_IN_CATALOG + 1), k=n_books_this_batch)

    generated_at = datetime.combine(batch_month, datetime.min.time()).replace(
        hour=9, minute=0, second=0
    )

    entries = []
    review_seq = 1
    for book_id in book_ids:
        title, lang = make_book_title()
        n_reviews = random.randint(1, 6)
        reviews = []

        for _ in range(n_reviews):
            reviews.append(make_review(batch_number, review_seq, lang))
            review_seq += 1

        entries.append(
            {
                "book_id": book_id,
                "isbn": make_isbn13(),
                "title": title,
                "export_batch_id": f"lote-{batch_month:%Y-%m}",
                "generated_at": generated_at.isoformat(),
                "reviews": reviews,
            }
        )

    return entries


def write_batches() -> None:
    JSON_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    first_month = date(2026, 4, 1)
    for batch_number in range(1, N_BATCHES + 1):
        batch_month = date(
            first_month.year + (first_month.month + batch_number - 2) // 12,
            (first_month.month + batch_number - 2) % 12 + 1,
            1,
        )
        entries = make_batch(batch_number, batch_month)

        output_file = JSON_OUTPUT_DIR / f"resenas_lote_{batch_number}.json"
        output_file.write_text(
            json.dumps(entries, ensure_ascii=False, indent=2), encoding="utf-8"
        )
        n_reviews = sum(len(e["reviews"]) for e in entries)
        print(f"Escrito: {output_file} ({len(entries)} libros, {n_reviews} resenas)")


def main() -> None:
    write_batches()


if __name__ == "__main__":
    main()
