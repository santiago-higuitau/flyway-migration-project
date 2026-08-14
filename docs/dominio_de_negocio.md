# Dominio de negocio para Biblioteca

<div style="text-align: justify">
Este proyecto modela el sistema de gestión de una Biblioteca, cuya operación central es
el control de préstamos de libros a sus usuarios. El corazón del negocio gira básicamente 
alrededor de tres entidades: los libros (el catálogo que se ofrece), los usuarios (el público 
que solicita los préstamos) y los préstamos (el registro de qué copia se entregó, a quién, 
y cuándo debe devolverse).
</div>

<br>

<div style="text-align: justify">
El modelo separa deliberadamente `libros`, `ediciones` y `copias` en tres niveles en lugar de uno solo. 
Un libro (por ejemplo, "Cien años de soledad") puede tener varias ediciones distintas (la de la editorial Macondo, la de Pingüino, etc), y cada edición puede existir en varias copias físicas simultáneamente. 
Si esta jerarquía se colapsara en una sola tabla con un contador de disponibilidad, se perdería la trazabilidad de qué copia física exacta está en manos de qué usuario, es decir, no podría distinguirse la copia dañada 
de la disponible, ni saber cuál copia en particular se prestó dos veces en momentos distintos. 
De forma similar, `usuarios` y `bibliotecarios` se modelan como tablas independientes, y 
no como una sola tabla con un campo de rol, porque representan conceptos de negocio distintos 
con atributos propios, por ejemplo, un bibliotecario tiene fecha de ingreso y cargo, mientras 
que un usuario tiene fecha de registro y datos de contacto, y porque una misma persona podría 
en principio tener presencia en ambas tablas sin que eso implique una relación entre sí.
</div>

## Diagrama entidad-relación

```mermaid
erDiagram
    authors {
        int id PK
        string name
        string place_of_birth
        string nationality
        date birth_date
        date death_date
    }

    categories {
        int id PK
        string name
        string description
    }

    books {
        int id PK
        string title
        string isbn
        string original_language
    }

    books_authors {
        int book_id PK, FK
        int author_id PK, FK
    }

    books_categories {
        int book_id PK, FK
        int category_id PK, FK
    }

    editions {
        int id PK
        int book_id FK
        string publisher
        int release_year
        int page_count
        string language
        decimal replacement_cost
    }

    copies {
        int id PK
        int edition_id FK
        string inventory_code
        string status "available, loaned or damaged"
        date acquired_at
        string physical_location
    }

    users {
        int id PK
        string name
        date registered_at
        string status "active or inactive"
        date birth_date
        string email
        string phone
    }

    librarians {
        int id PK
        string name
        date hired_at
        string status "active or inactive"
        string email
        string role
    }

    loans {
        int id PK
        int copy_id FK
        int user_id FK
        int librarian_id FK
        date loan_date
        date due_date
        date returned_at
    }

    penalties {
        int id PK
        int loan_id FK
        string reason
        date issued_at
        decimal fee
        boolean paid
    }

    authors ||--o{ books_authors : writes
    books ||--o{ books_authors : has
    categories ||--o{ books_categories : classifies
    books ||--o{ books_categories : has
    books ||--o{ editions : has
    editions ||--o{ copies : has
    copies ||--o{ loans : loaned_in
    users ||--o{ loans : requests
    librarians ||--o{ loans : manages
    loans ||--o{ penalties : generates
```

---
