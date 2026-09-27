# FinCore — Database Design

**Aryan Rao (AU25UG-006) · Chief Architect, Team 3** · DBMS course project, Atria University
Design cross-checked by Amruta Nagavi

This page is my design write-up for the FinCore banking database: what the nine tables are,
how they connect, and — more importantly — *why* every choice is the way it is. The SQL is
the source of truth: [`schema/create_tables.sql`](../schema/create_tables.sql) (MySQL 8, DDL v2).
A longer report with the full functional-dependency walkthroughs goes with the print
submission; this page is the readable version of it.

![Table Relationships Map](../diagrams/table_relationships.png)

## 1 · What I optimised for, and the nine tables

Before drawing a single box, I fixed five ground rules for myself. A bank database lives or
dies on trust, so these came first and every later decision had to obey them:

1. **Every business rule that *can* live in the database, *must* live in the database.**
   If a rule is only enforced by application code, somebody will eventually bypass the
   application — a buggy import script, a DBA's manual fix, a future feature. So negative
   balances, zero-amount transactions, self-managing employees and malformed card numbers
   are all rejected by the engine itself (CHECK constraints and ENUMs), not by app logic.
2. **History is never destroyed.** A bank can explain any rupee's journey years later.
   Deletion of anything with financial history is structurally blocked (see §2).
3. **Nothing derived is ever stored.** If a value can be computed from stored facts, storing
   it creates a second copy of the truth that will eventually disagree with the first (§5, D6).
4. **Money is exact.** No `FLOAT`, no `DOUBLE` — binary fractions cannot represent ₹0.10
   exactly, and rounding drift across a million rows is unacceptable in this domain (§5, D5).
5. **Every choice must survive being questioned.** For each decision below I wrote down the
   alternatives I considered and why I rejected them — partly for the viva, mostly because
   a design I can't defend is a design I don't understand yet.

With those rules set, nine tables fall out naturally:

| Table | What it stores | Primary key | Foreign keys |
|---|---|---|---|
| `branches` | Bank branches (name, city, IFSC code) | `branch_id` | — |
| `customers` | KYC-registered people | `customer_id` | — |
| `accounts` | Savings / current / fixed-deposit accounts — **the core table** | `account_id` | `customer_id`, `branch_id` |
| `transactions` | Immutable audit trail: every deposit, withdrawal, transfer | `txn_id` | `account_id` |
| `loans` | Home / vehicle / personal / education loans | `loan_id` | `customer_id`, `branch_id` |
| `loan_payments` | EMI instalment schedule of each loan | `payment_id` | `loan_id` |
| `employees` | Branch staff, each reporting to one manager | `employee_id` | `branch_id`, `manager_id` (self) |
| `beneficiaries` | Payees registered by a customer (external banks too) | `beneficiary_id` | `customer_id` |
| `cards` | Debit / credit cards issued on an account | `card_id` | `account_id` |

**Why exactly these nine?** Three of them — `customers`, `branches`, `employees` — are
*master* entities: they describe things that exist in their own right, so they carry no
foreign keys. One — `accounts` — is the hub: every operational table either points at it or
points at something that points at it. The remaining five are *satellites*, one per business
domain: money movement (`transactions`), lending (`loans` and its schedule `loan_payments`),
and payment rails (`cards`, `beneficiaries`). The test I applied for each satellite was
simple: if I deleted it, where would its facts live? The only alternative is repeating
groups inside the parent — for example an `emi_1`, `emi_2`, `emi_3` column set inside
`loans` — which is an instant 1NF violation and caps the tenure at however many columns I
was willing to type. A separate table is the honest answer every time.

Where the nine tables sit in the overall system — five layers, top to bottom (users →
business modules → SQL & integrity → the MySQL schema → physical storage):

![System & database architecture](../diagrams/architecture_diagram.png)

The database is layer 4, but the constraints in layer 3 (the CHECKs, FKs and unique keys in
the DDL) are what make layer 5 trustworthy. In ANSI/SPARC terms the ER diagrams in §3 are
the conceptual view, the relational schema in §4 is the internal view, and future
application screens would be external views — the mapping between them is exactly what
this page documents.

## 2 · The 10 relationships — read this first

Every relationship is **1 : N** (one parent row → many child rows) and is enforced by a
`FOREIGN KEY` constraint **inside the child table** — the child holds the pointer, so the
child is where the rule is declared.

| # | Parent (1) | Child (N) | FK column | Meaning | ON DELETE |
|---|---|---|---|---|---|
| 1 | `customers` | `accounts` | `accounts.customer_id` | a customer holds many accounts | RESTRICT |
| 2 | `branches` | `accounts` | `accounts.branch_id` | each account is serviced by one branch | RESTRICT |
| 3 | `accounts` | `transactions` | `transactions.account_id` | every transaction hits exactly one account | RESTRICT |
| 4 | `customers` | `loans` | `loans.customer_id` | a customer can take many loans | RESTRICT |
| 5 | `branches` | `loans` | `loans.branch_id` | the branch that sanctioned the loan | RESTRICT |
| 6 | `loans` | `loan_payments` | `loan_payments.loan_id` | each loan has a schedule of EMIs | CASCADE |
| 7 | `branches` | `employees` | `employees.branch_id` | staff belong to exactly one branch | RESTRICT |
| 8 | `employees` | `employees` *(self)* | `employees.manager_id` | one manager has many reportees | SET NULL |
| 9 | `customers` | `beneficiaries` | `beneficiaries.customer_id` | a customer's saved payees | CASCADE |
| 10 | `accounts` | `cards` | `cards.account_id` | cards are issued on an account | CASCADE |

**Why the ON DELETE rules differ — the whole policy in 3 lines:**

- **RESTRICT — audit history.** You can never delete a customer, branch, account or loan
  that still has dependent history; MySQL answers the attempt with error **1451**. Closing
  an account is a *status change*, not a `DELETE`. Inserting a child that points at a
  non-existent parent fails with **1452** — both directions are covered.
- **CASCADE — owned data.** `loan_payments`, `beneficiaries` and `cards` are meaningless
  without their parent row: an EMI schedule with no loan, an access card with no account,
  a payee list with no customer. They are removed *with* the parent, so the database never
  accumulates orphans.
- **SET NULL — the reporting line.** If a manager's record is deleted, their subordinates
  keep their jobs; only `manager_id` is cleared to NULL. Deleting people should not delete
  other people.

The reasoning behind *not* using one action everywhere: `CASCADE` everywhere would silently
destroy financial history (my rule 2 broken), and `RESTRICT` everywhere would make owned
data undeletable in practice — you could never remove a customer without first hand-clearing
their payee list. The action per relationship encodes *who owns the data*: history is owned
by the bank (RESTRICT), personal conveniences are owned by their user (CASCADE), and an
org-chart link is owned by nobody in particular (SET NULL).

## 3 · Conceptual view — ER diagrams

![ER diagram](../diagrams/er_diagram.png)

The same model in **Chen's notation** — the textbook conceptual view: entity rectangles,
attribute ovals (underlined = PK, dotted = UNIQUE, dashed = nullable), relationship diamonds
with 1/N cardinality, double lines for total participation, and the label under each diamond
naming the exact FK column it will become:

![Chen ER diagram](../diagrams/er_diagram_chen.png)

Three things worth noticing:

1. **No many-to-many junction tables are needed.** The only true M:N situation — *a transfer
   between two accounts* — is resolved **inside `transactions`**: one transfer = two rows
   (`transfer_out` + `transfer_in`) sharing one `transfer_ref` (reasoning in §5, D2). Every
   other relationship is a plain 1:N, so a junction table would be over-engineering.
2. **`beneficiaries` has no line to `accounts` — on purpose.** A payee usually banks
   *elsewhere*, so `account_no` / `ifsc_code` are plain columns there. A foreign key could
   only ever point at FinCore's own accounts, which would make external payees impossible
   to even store (§5, D3).
3. **`employees` → `employees`** is the one recursive relationship — the reporting line.
   Chen's notation draws it as a loop on a single entity; physically it is
   `manager_id` pointing back at the same table's primary key.

## 4 · Physical view — relational schema

![Relational schema](../diagrams/relational_schema.png)

**Column-level version** — every one of the 57 columns with nullability, defaults, ENUM
domains, CHECK rules, composite keys, indexes, and each FK's ON DELETE action on its wire:

![Detailed relational schema](../diagrams/relational_schema_detailed.png)

- Full DDL with every constraint and its reasoning in the comments:
  [`schema/create_tables.sql`](../schema/create_tables.sql) — 9 tables, 10 foreign keys,
  9 CHECK constraints, 7 unique keys, 3 supporting indexes (v2).
- Column-by-column descriptions + the FK / CHECK / UQ / index / ENUM catalogs:
  [`DATA_DICTIONARY.md`](./DATA_DICTIONARY.md)

## 5 · Design decisions — each one with the alternatives I rejected

These are the six decisions that shape the whole schema (the same D-numbers are used in the
comments of `create_tables.sql`, so a reviewer can jump between this page and the SQL), plus
a few smaller choices at the end.

### D1 · Surrogate primary keys, business keys as UNIQUE

Every table has an `AUTO_INCREMENT` integer primary key, and the human-facing identifier
(`ifsc_code`, `phone`, `email`, `account_number`, `card_number`) sits behind a `UNIQUE`
constraint instead.

**Alternative considered:** natural keys — making `ifsc_code` the primary key of `branches`,
for instance. I rejected that for three reasons. First, joins: `CHAR(11)` vs `INT` makes
every join wider and every index bigger for zero benefit. Second, stability: if the RBI ever
re-issued IFSC codes (or a customer changed their phone number — which happens constantly),
a natural key would need cascading updates through every referencing table; with a surrogate,
the business identifier is just an editable column behind its UNIQUE. Third, honesty: a
business identifier exists for *humans* (printed on passbooks, quoted on calls); a primary
key exists for the *machine*. Keeping them separate lets each do its own job.

**Cost I accepted:** one extra index per table (the UNIQUE backing). Cheap, and worth it.

### D2 · Transfers are two paired rows, not one row with from/to

A transfer of ₹5,000 from account A to account B is stored as two rows in `transactions`:

```
row 1: account_id = A, txn_type = 'transfer_out', amount = 5000, transfer_ref = 'TR20260901X1'
row 2: account_id = B, txn_type = 'transfer_in',  amount = 5000, transfer_ref = 'TR20260901X1'
```

**Alternative 1 — one row with `from_account` and `to_account` columns.** This is the
obvious design and I rejected it for three reasons. Every per-account statement would need
`WHERE from_account = ? OR to_account = ?` — an OR over two columns kills index use. Both FK
columns would be NULLable for plain deposits/withdrawals, so the "exactly one side used"
rule would need its own CHECK and the schema would be half-null most of the time. And
`amount` would mean different things depending on which side you read — negative for the
sender? A sign convention? Ambiguity in a money column is a bug factory.

**Alternative 2 — a separate `transfers` table referenced by two transaction rows.** Also
workable, but it adds a join to every transfer report, and the real invariant ("both halves
exist and match") still isn't expressible declaratively — so the extra table buys nothing
the two-row design doesn't already give.

**What the two-row design buys:** every account statement is a plain single-column filter
(`WHERE account_id = ?`); `amount` is always a positive magnitude with the *type* carrying
direction; and the pairing rule itself is enforced by a CHECK —
`chk_txn_transfer_pairing` guarantees a transfer-typed row must carry a `transfer_ref` and a
deposit-typed row must not.

**Honest limitation:** the engine cannot force two *separate rows* to be inserted together —
that atomicity belongs to the insert routine (one transaction, both rows). I verified the
invariant can always be *checked* after the fact by reconciling the two halves per
`transfer_ref`, which is one of the team's demo queries.

### D3 · `beneficiaries` deliberately has no FK on the payee account

`account_no` and `ifsc_code` in `beneficiaries` are plain columns — not foreign keys.

**Alternative considered:** `FOREIGN KEY (account_no) REFERENCES accounts(...)`. It sounds
rigorous, but a foreign key can only ever reference *FinCore's own* accounts — and the whole
point of a registered payee is that they usually bank **elsewhere**. The "rigorous" version
would make external payees impossible to store, which breaks the feature entirely.

**What I did instead:** `uq_beneficiary_per_customer` — `UNIQUE (customer_id, account_no,
ifsc_code)` — so the same customer can't register the same payee twice, while the payee's
account can live at any bank in India. The format sanity that *is* checkable (IFSC is
11 characters) is enforced with the column type itself.

### D4 · Referential actions chosen per relationship, not by default

The 6 RESTRICT / 3 CASCADE / 1 SET NULL split from §2 is not decoration; each row has a
scenario behind it. Concretely: attempt `DELETE FROM accounts WHERE account_id = 1` while
transactions exist → **ERROR 1451**, history protected. Delete a loan → its EMI schedule
goes with it (CASCADE) — a schedule without its loan is noise. Delete a manager →
subordinates' `manager_id` becomes NULL (SET NULL) — and `chk_emp_not_own_manager` keeps the
reporting line from ever pointing at itself.

The one-line summary I keep coming back to: **the ON DELETE action encodes who owns the
data.** The bank owns its history (RESTRICT), a customer owns their convenience data
(CASCADE), and nobody owns an org-chart relationship (SET NULL).

### D5 · Money is `DECIMAL(12,2)`, rates are `DECIMAL(5,2)`, never FLOAT

`FLOAT` and `DOUBLE` store binary fractions: there is no exact binary representation of
0.10, so 10 paise stored as a float is already wrong by a fraction of a paise — and across
a million rows, those fractions stop being trivia and become an audit finding. `DECIMAL` is
exact base-10 arithmetic, which is what money actually is.

**Sizing:** `DECIMAL(12,2)` caps a single figure at 9,99,99,99,999.99 — more headroom than
a course-scale bank (and most real accounts) will ever need, while staying narrow enough to
index comfortably. `interest_rate` is `DECIMAL(5,2)` because the domain is 0.00–100.00; its
bounds are additionally enforced by `chk_loans_rate`.

### D6 · Time-dependent truths are never stored — they are derived

An EMI instalment is *overdue* exactly when `paid_date IS NULL AND due_date < CURRENT_DATE`.
There is no `is_overdue` column, anywhere, and that is deliberate: a stored flag is correct
at the moment it is written and wrong by tomorrow morning without any row changing. The same
principle covers a customer's age (derived from `dob`) and a loan's outstanding amount
(derived from its payments). The general rule: **store facts, derive opinions.** A query
cannot rot.

### Smaller choices worth defending

- **ENUM vs lookup tables vs free text.** For frozen vocabularies of 2–4 values that the
  *business* owns (`account_type`, `txn_type`, `loan_type`, `status` columns...), ENUM is
  the right tool: the engine itself rejects `'actve'`, the values are visible in the DDL,
  and no join is needed to read them. Where a vocabulary is *user-growable* — a product
  catalogue, say — ENUM would be wrong (adding a value means `ALTER TABLE`), and a lookup
  table would be the correct design. These seven lists are stable banking categories, so
  ENUM wins; I'm noting the trade-off because it's the first thing I'd revisit if the
  domain grew.
- **MySQL 8.0.16+ as a hard floor.** Not a preference — a fact: before 8.0.16, MySQL parses
  CHECK constraints and then *silently ignores* them. A schema whose 9 CHECKs might not
  fire is not a schema I can hand over. The floor guarantees every rule in this page is
  actually enforced (violations fail with error 3819). InnoDB because it's the only engine
  with real foreign keys and transactions; `utf8mb4` because it's actual 4-byte UTF-8 —
  customer names with any diacritic, and the ₹ symbol itself, must survive round-trips.
- **`DATE` vs `DATETIME`.** Business dates (`dob`, `due_date`, `expiry_date`...) are day
  precision, so `DATE`. `txn_date` is `DATETIME` because an audit trail needs same-day
  ordering — and it defaults to `CURRENT_TIMESTAMP` so the *server's* clock stamps the row,
  not whatever the application thinks the time is.
- **`CHAR` vs `VARCHAR`.** Fixed-length identifiers (IFSC `CHAR(11)`, card number `CHAR(16)`)
  are always exactly that length; `CHAR` documents that fact and saves the length byte.
  Names, addresses and account numbers vary, so `VARCHAR`.
- **Only 3 secondary indexes.** InnoDB already indexes every PK, UNIQUE and FK column
  automatically — an explicit index on a FK column is a pure duplicate (v2 deleted
  `idx_accounts_customer` for exactly that reason). The three that exist
  (`idx_payment_due`, `idx_loan_status`, `idx_txn_date`) each back a real recurring query —
  the overdue scan, the active-loan portfolio, and date-range statements. Every additional
  index taxes every `INSERT` and `UPDATE`, so "index what the questions ask", not everything.

## 6 · Normalization — all nine tables are in BCNF

**Method.** For each relation I listed the functional dependencies, found the candidate
keys, and applied the BCNF test: *every* non-trivial determinant must be a candidate key.
A few observations that made the verification cleaner:

- **2NF is structurally guaranteed** by D1: with single-column surrogate primary keys there
  are no composite keys for a non-key column to be *partially* dependent on. (The one
  composite candidate key in the design — `(loan_id, instalment_no)` in `loan_payments` —
  was checked explicitly anyway; both of its components are needed to pin down a row.)
- **3NF/BCNF: the classic trap is transitive dependency on a parent's attributes.** The
  mistake I was most careful to avoid is storing branch facts inside `accounts` — say
  `branch_city`. If a branch relocates, that's thousands of account rows to update; miss
  one and the database now contradicts itself about where a branch is. City lives in
  `branches`, once, and everything else references it. Same reasoning for every parent
  attribute: `full_name` is never copied into `accounts`, loan facts are never copied into
  `loan_payments`.
- **Each fact has exactly one home.** `balance` lives on `accounts` (current truth);
  movements live in `transactions` (history); the two are reconcilable but not duplicated.
  `paid_date` lives on `loan_payments` and nowhere else. No relation stores a second copy
  of another relation's fact, so there are no update anomalies to hunt.

| Relation | Candidate key(s) | Verdict |
|---|---|---|
| `branches` | `branch_id`; `ifsc_code` | BCNF ✓ |
| `customers` | `customer_id`; `phone`; `email` | BCNF ✓ |
| `accounts` | `account_id`; `account_number` | BCNF ✓ |
| `transactions` | `txn_id` | BCNF ✓ |
| `loans` | `loan_id` | BCNF ✓ |
| `loan_payments` | `payment_id`; `(loan_id, instalment_no)` | BCNF ✓ |
| `employees` | `employee_id` | BCNF ✓ |
| `beneficiaries` | `beneficiary_id`; `(customer_id, account_no, ifsc_code)` | BCNF ✓ |
| `cards` | `card_id`; `card_number` | BCNF ✓ |

**4NF and 5NF, briefly:** there are no multivalued attributes (every attribute of every
relation is a single scalar fact, not a list), so 4NF holds by construction; and since each
fact is stored in exactly one table, there are no join dependencies to decompose — 5NF
holds for the same reason 3NF did: one home per fact.

The full FD-by-FD walkthrough — including a worked 1NF → 2NF → 3NF → BCNF progression on a
deliberately broken version of the design, and one BCNF decomposition exercise (a
`loan_officer` attribute that would have created a non-key determinant) — is Chapter 7 of
the print report.

## 7 · How this design was verified

Verification was not a single pass at the end; every artifact below was cross-checked
against the DDL, and the DDL itself was executed and probed:

- ✓ **10 rows in §2 ⇔ 10 `FOREIGN KEY` clauses** in `create_tables.sql`
  (`fk_accounts_customer` … `fk_card_account`).
- ✓ **ON DELETE distribution matches the DDL: 6 RESTRICT · 3 CASCADE · 1 SET NULL.**
- ✓ **Counts from `information_schema` after running the script:** 9 tables · 10 FK ·
  9 CHECK · 7 UNIQUE · 3 secondary indexes · 57 columns.
- ✓ **Diagram ⇔ dictionary ⇔ DDL:** table list in §1 ⇔ cards on `relational_schema.png`
  ⇔ `CREATE TABLE` statements; `relational_schema_detailed.png` ⇔ `DATA_DICTIONARY.md`
  column-for-column.
- ✓ **`beneficiaries` has exactly one FK** (`fk_ben_customer`) — the missing second one is
  design decision D3, not an oversight.
- ✓ **No `FLOAT`/`DOUBLE` anywhere in the DDL**; every money column is `DECIMAL`.
- ✓ **Transfer pairing enforced** by `chk_txn_transfer_pairing`; **no `is_overdue` column
  exists anywhere** — overdue is a query (D6).
- ✓ **Negative tests:** each CHECK/FK rule was deliberately violated to confirm the engine
  rejects it (errors 3819 for CHECKs, 1452/1451 for FKs in the two directions).

**The v2 corrections — what review actually caught.** The first version of the DDL had two
defects that only surfaced when the design was reviewed against real banking behaviour, and
I think they're worth owning rather than hiding:

1. **`chk_payment_dates` (`paid_date >= due_date`) was removed.** It sounds defensive but
   it rejects *early* EMI payments — paying an instalment before its due date is completely
   normal banking, and the v1 rule made it unrecordable. There is now deliberately **no**
   date-order check between the two columns; early, on-time and late are all legitimate.
2. **`idx_accounts_customer` was removed.** It duplicated the index InnoDB creates
   automatically for `fk_accounts_customer` — a duplicate index costs write throughput and
   buys nothing. The lesson generalised into the index policy in §5: never index FK columns
   explicitly.

## 8 · What's in this repository

| File | What it is |
|---|---|
| [`README.md`](../README.md) | project overview, how to run the DDL, reading order |
| [`DATA_DICTIONARY.md`](./DATA_DICTIONARY.md) | column-by-column reference + FK / CHECK / UQ / index / ENUM catalogs |
| [`diagrams/table_relationships.png`](../diagrams/table_relationships.png) | the hero map: all 9 tables and 10 links |
| [`diagrams/er_diagram_chen.png`](../diagrams/er_diagram_chen.png) | ER in Chen's notation — the conceptual view, all 47 attributes |
| [`diagrams/er_diagram.png`](../diagrams/er_diagram.png) | simplified ER (table names + PK/FK badges) |
| [`diagrams/relational_schema.png`](../diagrams/relational_schema.png) | physical schema, all columns and FK arrows |
| [`diagrams/relational_schema_detailed.png`](../diagrams/relational_schema_detailed.png) | column-level schema: 57 columns, defaults, ENUMs, CHECKs, ON DELETE chips |
| [`diagrams/architecture_diagram.png`](../diagrams/architecture_diagram.png) | 5-layer system & database architecture (ANSI/SPARC mapping) |
| [`schema/create_tables.sql`](../schema/create_tables.sql) | the DDL (v2) — the single source of truth |
