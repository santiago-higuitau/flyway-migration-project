-- Baseline schema: library domain (10 of 11 tables; `penalties` arrives later).

CREATE TABLE authors (
    id             INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name           VARCHAR(150) NOT NULL,
    place_of_birth VARCHAR(150),
    nationality    VARCHAR(100),
    birth_date     DATE,
    death_date     DATE
);

CREATE TABLE categories (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE,
    description VARCHAR(255)
);

CREATE TABLE books (
    id                 INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title              VARCHAR(255) NOT NULL,
    isbn               VARCHAR(20) UNIQUE,
    original_language  VARCHAR(50)
);

CREATE TABLE books_authors (
    book_id   INTEGER NOT NULL REFERENCES books(id),
    author_id INTEGER NOT NULL REFERENCES authors(id),
    PRIMARY KEY (book_id, author_id)
);

CREATE TABLE books_categories (
    book_id     INTEGER NOT NULL REFERENCES books(id),
    category_id INTEGER NOT NULL REFERENCES categories(id),
    PRIMARY KEY (book_id, category_id)
);

CREATE TABLE editions (
    id                INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    book_id           INTEGER NOT NULL REFERENCES books(id),
    publisher         VARCHAR(150) NOT NULL,
    release_year      SMALLINT NOT NULL,
    page_count        INTEGER,
    language          VARCHAR(50) NOT NULL,
    replacement_cost  NUMERIC(8,2) NOT NULL
);

CREATE TABLE copies (
    id                 INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    edition_id         INTEGER NOT NULL REFERENCES editions(id),
    inventory_code     VARCHAR(30) NOT NULL UNIQUE,
    status             VARCHAR(20) NOT NULL DEFAULT 'available'
                       CHECK (status IN ('available', 'loaned', 'damaged')),
    acquired_at        DATE NOT NULL,
    physical_location  VARCHAR(50)
);

CREATE TABLE users (
    id            INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name          VARCHAR(150) NOT NULL,
    registered_at DATE NOT NULL DEFAULT CURRENT_DATE,
    status        VARCHAR(20) NOT NULL DEFAULT 'active'
                  CHECK (status IN ('active', 'inactive')),
    birth_date    DATE,
    email         VARCHAR(150) UNIQUE
);

CREATE TABLE librarians (
    id        INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name      VARCHAR(150) NOT NULL,
    hired_at  DATE NOT NULL DEFAULT CURRENT_DATE,
    status    VARCHAR(20) NOT NULL DEFAULT 'active'
              CHECK (status IN ('active', 'inactive')),
    email     VARCHAR(150) UNIQUE,
    role      VARCHAR(50)
);

CREATE TABLE loans (
    id             INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    copy_id        INTEGER NOT NULL REFERENCES copies(id),
    user_id        INTEGER NOT NULL REFERENCES users(id),
    librarian_id   INTEGER NOT NULL REFERENCES librarians(id),
    loan_date      DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date       DATE NOT NULL,
    returned_at    DATE,
    CHECK (due_date >= loan_date)
);
