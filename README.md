# FinCore — Banking & Transaction Management Database

**Team 3 · DBMS course project · Atria University**
## Team

Aryan Rao — database design & DDL · Amruta Nagavi — design review · Siva — database
implementation · Jashan — SQL queries · Harsita — seed data

FinCore is a MySQL 8 database for a small bank: customers, accounts, money movement,
lending, cards and registered payees — **nine tables, normalized to BCNF**, with every
business rule the engine *can* enforce actually enforced *in* the engine (10 foreign keys,
9 CHECK constraints, 7 unique keys). The design reasoning behind every choice — including
the alternatives that were considered and rejected — is written up in the docs folder.

## What's where

| Path | Contents |
|---|---|
| [`docs/DATABASE_DESIGN.md`](docs/DATABASE_DESIGN.md) | the design write-up: tables, relationships, every decision with its reasoning, normalization to BCNF |
| [`docs/NORMALIZATION.md`](docs/NORMALIZATION.md) | the full working: 1NF → BCNF progression on a broken table, FD-by-FD proof for all 9 relations, 4NF/5NF |
| [`docs/DATA_DICTIONARY.md`](docs/DATA_DICTIONARY.md) | all 57 columns explained + full FK / CHECK / UNIQUE / index / ENUM catalogs |
| [`diagrams/`](diagrams) | ER diagrams (Chen's notation + simplified), relational schema (incl. column-level), relationships map, 5-layer architecture |
| [`schema/create_tables.sql`](schema/create_tables.sql) | the DDL (v2) — single source of truth, safe to re-run |

## Running it

You need **MySQL 8.0.16 or newer** — that is a hard requirement, not a preference: older
servers parse CHECK constraints and then *silently ignore them*, and this design relies on
all nine of them firing (violations fail with error 3819).

```sql
mysql -u root -p < schema/create_tables.sql
```

The script is idempotent — it tears down any existing tables first (children before
parents), so re-running it from scratch always works. After running, these counts should
come out of `information_schema`:

```
9 tables · 57 columns · 10 FK (6 RESTRICT / 3 CASCADE / 1 SET NULL)
9 CHECK · 7 UNIQUE (2 composite) · 3 secondary indexes
```

## Reading order

1. [`docs/DATABASE_DESIGN.md`](docs/DATABASE_DESIGN.md) — start here; §2 is the map of how
   everything connects
2. [`docs/NORMALIZATION.md`](docs/NORMALIZATION.md) — the proof that every table is in BCNF,
   with the working shown
3. [`docs/DATA_DICTIONARY.md`](docs/DATA_DICTIONARY.md) — when you need column-level detail
4. [`schema/create_tables.sql`](schema/create_tables.sql) — the source of truth, with the
   reasoning for every constraint in its comments


