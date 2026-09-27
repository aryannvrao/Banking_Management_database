# FinCore — Data Dictionary

> Column-level reference for [`schema/create_tables.sql`](../schema/create_tables.sql) · MySQL 8.0.16+ · InnoDB · utf8mb4
> Design: **Aryan Rao (AU25UG-006)** · Cross-check: **Amruta Nagavi** · Team 3, DBMS Project, Atria University

I wrote this dictionary for two readers: a teammate implementing against the schema who
needs to know exactly what a column means, and an examiner checking one specific column —
both should find their answer here without opening the SQL. Every fact below is taken
**verbatim from the DDL**: if the DDL ever changes, this file and the diagrams change with
it. The reasoning behind the *structure* (why these tables, why these relationships) is in
[`DATABASE_DESIGN.md`](./DATABASE_DESIGN.md); this file is about the columns themselves.

**How to read the column tables** — **PK** primary key · **FK** foreign key · **UQ** unique key ·
**AI** `AUTO_INCREMENT` · Null = `YES`/`NO` · Default = `DEFAULT` clause · money is always `DECIMAL` (never `FLOAT`).
All `CHECK` violations fail with MySQL error **3819**; duplicate unique keys with **1062**; FK violations with **1452** (insert) / **1451** (delete/update).

---

## 1 · `branches` — master list of bank branches (parent)

**Granularity:** one row per physical branch. Referenced by `accounts`, `loans`, `employees`.

| # | Column | Type | Null | Key | Default | Description |
|---|--------|------|:---:|-----|---------|-------------|
| 1 | `branch_id` | INT | NO | **PK** · AI | — | Surrogate primary key — small, stable integer used by every join (D1) |
| 2 | `name` | VARCHAR(100) | NO | | — | Branch display name, e.g. "MG Road" |
| 3 | `city` | VARCHAR(50) | NO | | — | Branch city — lives here once, not repeated on every account (3NF) |
| 4 | `ifsc_code` | CHAR(11) | NO | **UQ** | — | RBI IFSC code (e.g. `AUSB0000001`) — the business-facing branch identifier |

**Keys:** `pk_branches` (branch_id) · `uq_branches_ifsc` (ifsc_code)
**Indexes:** none beyond PK/UQ — a parent table this small is always reached through its keys.
**Design notes:** I kept `branches` deliberately minimal — name, city, IFSC. A full postal
address would be nice to have, but nothing in the business queries needs it, and every
column I add is a column somebody has to maintain. `ifsc_code` is `CHAR(11)` because an
IFSC is *always* exactly 11 characters — fixed length, no length byte, and the type itself
documents the format. It sits behind a UNIQUE rather than being the PK because it is the
identifier humans quote; `branch_id` is the one the machine joins on (D1).

## 2 · `customers` — KYC-registered people (parent)

**Granularity:** one row per natural person who has completed KYC.

| # | Column | Type | Null | Key | Default | Description |
|---|--------|------|:---:|-----|---------|-------------|
| 1 | `customer_id` | INT | NO | **PK** · AI | — | Surrogate primary key (D1) |
| 2 | `full_name` | VARCHAR(100) | NO | | — | Complete legal name exactly as on KYC documents |
| 3 | `dob` | DATE | NO | | — | Date of birth — age is always *derived* from it, never stored |
| 4 | `phone` | VARCHAR(15) | NO | **UQ** | — | Primary mobile — UNIQUE: one phone number identifies one customer |
| 5 | `email` | VARCHAR(100) | NO | **UQ** | — | Contact email — UNIQUE for the same reason (de-duplication key) |
| 6 | `address` | VARCHAR(255) | NO | | — | Postal address (single line) |

**Keys:** `pk_customers` · `uq_customers_phone` · `uq_customers_email`
**Design notes:** `phone` and `email` are both UNIQUE on purpose — they double as
de-duplication keys, so the same person cannot be KYC-registered twice under one number.
There is **no** `age` column: age is `TIMESTAMPDIFF(YEAR, dob, CURDATE())`, and a stored age
would silently become wrong every 365 days without any row changing (D6). One deliberate
limitation I want on record: there is **no** `CHECK (dob < CURDATE())` — MySQL forbids
non-deterministic functions inside CHECK constraints, so future-date validation has to live
in the application layer. Documented, not forgotten.

## 3 · `accounts` — customer deposit accounts (**core table**)

**Granularity:** one row per account. The hub every operational table points at.

| # | Column | Type | Null | Key | Default | Description |
|---|--------|------|:---:|-----|---------|-------------|
| 1 | `account_id` | INT | NO | **PK** · AI | — | Surrogate primary key — the internal join key for `transactions` / `cards` |
| 2 | `account_number` | VARCHAR(20) | NO | **UQ** | — | The number printed on passbooks/statements; the surrogate stays hidden (D1) |
| 3 | `customer_id` | INT | NO | **FK** → customers | — | Owning customer — one customer may hold many accounts (1:N) |
| 4 | `branch_id` | INT | NO | **FK** → branches | — | Servicing branch — every account belongs to exactly one branch |
| 5 | `account_type` | ENUM | NO | | — | `savings` · `current` · `fixed_deposit` |
| 6 | `balance` | DECIMAL(12,2) | NO | | `0.00` | Current balance in INR — exact decimal, never FLOAT; cannot go negative (CHECK) |
| 7 | `opened_on` | DATE | NO | | — | Date the account was opened |

**Keys:** `pk_accounts` · `uq_accounts_number` · FKs `fk_accounts_customer`, `fk_accounts_branch`
**Checks:** `chk_accounts_balance` — `balance >= 0` (error 3819 on a negative update)
**Design notes:** In the base design an account belongs to **exactly one customer** — no
joint accounts. Real co-ownership would need an `account_holders` junction table turning
this 1:N into M:N; I kept the simpler model because the business questions never need it,
and a junction table I cannot defend is complexity I should not add. `balance` is the
*current truth*; the history of how it got there lives in `transactions` and is never
duplicated here — two homes for one number is how balances start disagreeing with statements.

## 4 · `transactions` — the immutable audit trail

**Granularity:** one row per money movement. Rows are append-only; nothing is ever deleted (see `fk_txn_account`).

| # | Column | Type | Null | Key | Default | Description |
|---|--------|------|:---:|-----|---------|-------------|
| 1 | `txn_id` | INT | NO | **PK** · AI | — | Surrogate primary key — audit sequence |
| 2 | `account_id` | INT | NO | **FK** → accounts | — | The account this movement hit — exactly one per row |
| 3 | `txn_type` | ENUM | NO | | — | `deposit` · `withdrawal` · `transfer_out` · `transfer_in` |
| 4 | `amount` | DECIMAL(12,2) | NO | | — | Magnitude only, always > 0 — the *type* carries the direction (CHECK) |
| 5 | `txn_date` | DATETIME | NO | | `CURRENT_TIMESTAMP` | When it happened — defaults to insertion time |
| 6 | `transfer_ref` | CHAR(12) | **YES** | | — | Pairing key shared by the two halves of a transfer; NULL for plain deposit/withdrawal (CHECK-enforced) |

**Keys:** `pk_transactions` · FK `fk_txn_account` (`ON DELETE RESTRICT` — the audit trail can never be deleted out from under history)
**Design D2 — the transfer model:** a transfer of ₹5,000 from A to B is stored as
`transfer_out` on account A and `transfer_in` on account B, both rows carrying the same `transfer_ref`.
A transfer is therefore always fully visible or not at all, and per-account history stays single-table
(the alternatives I considered and rejected are in `DATABASE_DESIGN.md` §5, D2).
**Checks:** `chk_txn_amount` (`amount > 0`) · `chk_txn_transfer_pairing`
(`(txn_type IN ('transfer_out','transfer_in')) = (transfer_ref IS NOT NULL)` — a deposit can't smuggle a transfer ref, a transfer can't lose it).
**Design notes:** `txn_date` is the one `DATETIME` in a schema otherwise full of `DATE`s,
because an audit trail needs same-day ordering — and it defaults to `CURRENT_TIMESTAMP` so
the *server's* clock stamps the row, not whatever the application believes the time is.
`amount` is a positive magnitude in every row; direction is the *type's* job. Allowing signs
into money columns is how "-5000 means a withdrawal, except when it means a refund" enters
a codebase, and I refused to open that door.

## 5 · `loans` — lending products

**Granularity:** one row per sanctioned loan.

| # | Column | Type | Null | Key | Default | Description |
|---|--------|------|:---:|-----|---------|-------------|
| 1 | `loan_id` | INT | NO | **PK** · AI | — | Surrogate primary key |
| 2 | `customer_id` | INT | NO | **FK** → customers | — | Borrower — one customer may take many loans |
| 3 | `branch_id` | INT | NO | **FK** → branches | — | The branch that sanctioned the loan |
| 4 | `loan_type` | ENUM | NO | | — | `home` · `vehicle` · `personal` · `education` |
| 5 | `principal` | DECIMAL(12,2) | NO | | — | Original sanctioned amount (CHECK > 0) |
| 6 | `interest_rate` | DECIMAL(5,2) | NO | | — | Annual percentage rate, sanity-bounded 0–100 (CHECK) |
| 7 | `tenure_months` | INT | NO | | — | Repayment tenure, 1–360 months = 1 month–30 years (CHECK) |
| 8 | `start_date` | DATE | NO | | — | First disbursement date |
| 9 | `status` | ENUM | NO | | `'active'` | `active` · `closed` · `defaulted` — lifecycle flag |

**Keys:** `pk_loans` · FKs `fk_loans_customer`, `fk_loans_branch`
**Checks:** `chk_loans_principal` · `chk_loans_rate` · `chk_loans_tenure`
**Design notes:** `status` starts life as `'active'` by default — a loan enters the system
sanctioned and disbursed, and its lifecycle is a short, closed vocabulary (`closed`,
`defaulted`), not free text. The numeric bounds look like bureaucracy but each one blocks a
real class of typo: a negative principal (a loan that *gives* money), a rate of 1500 from a
missing decimal point, a tenure of 0 or 5000 months. I would rather reject nonsense at the
door than audit it out later. There is deliberately **no** `outstanding_amount` column —
outstanding is derived from the `loan_payments` schedule vs payments, and a stored copy
would drift the first time someone back-dated a payment (D6).

## 6 · `loan_payments` — the EMI instalment schedule

**Granularity:** one row per scheduled EMI of one loan (instalments 1..N).

| # | Column | Type | Null | Key | Default | Description |
|---|--------|------|:---:|-----|---------|-------------|
| 1 | `payment_id` | INT | NO | **PK** · AI | — | Surrogate primary key |
| 2 | `loan_id` | INT | NO | **FK** → loans | — | The loan this instalment belongs to |
| 3 | `instalment_no` | INT | NO | | — | Sequence number within the loan — with `loan_id`, a natural alternate key |
| 4 | `due_date` | DATE | NO | | — | When the EMI falls due — indexed, because overdue scans filter here |
| 5 | `paid_date` | DATE | **YES** | | — | NULL = not yet paid. This single NULL is what powers overdue detection |
| 6 | `amount` | DECIMAL(12,2) | NO | | — | EMI amount (CHECK > 0) |

**Keys:** `pk_loan_payments` · `uq_payment_instalment` **(loan_id, instalment_no)** — the same instalment can never exist twice
**Checks:** `chk_payment_amount` (`amount > 0`)
**Design notes:** the nullable `paid_date` is the quiet hero of the whole design: NULL is a
meaningful value ("not paid yet"), not a missing one, and it is what makes "overdue" a
one-line query instead of a synchronised flag. An instalment is overdue exactly when
`paid_date IS NULL AND due_date < CURRENT_DATE` — **"overdue" is never stored** (D6), because
a stored flag would rot overnight while the query stays correct forever.
> **v2 change:** `chk_payment_dates` (`paid_date >= due_date`) was **removed** — it rejected
> valid **early** EMI payments; `paid_date` may legitimately fall before `due_date` (early /
> on-time / late are all valid). The absence of a date-order check between these two columns
> is deliberate, not an omission.

## 7 · `employees` — branch staff and their reporting line

**Granularity:** one row per staff member.

| # | Column | Type | Null | Key | Default | Description |
|---|--------|------|:---:|-----|---------|-------------|
| 1 | `employee_id` | INT | NO | **PK** · AI | — | Surrogate primary key |
| 2 | `full_name` | VARCHAR(100) | NO | | — | Staff member's full name |
| 3 | `branch_id` | INT | NO | **FK** → branches | — | The branch they work at |
| 4 | `designation` | ENUM | NO | | — | `manager` · `loan_officer` · `teller` · `cashier` |
| 5 | `manager_id` | INT | **YES** | **FK** → employees *(self)* | — | Who they report to — NULL = top of that chain; the one recursive relationship |
| 6 | `hire_date` | DATE | NO | | — | Employment start date |

**Keys:** `pk_employees` · FKs `fk_emp_branch`, `fk_emp_manager` (self-referencing, `ON DELETE SET NULL`)
**Check:** `chk_emp_not_own_manager` (`manager_id IS NULL OR manager_id <> employee_id` — nobody manages themselves)
**Design notes:** the self-referencing `manager_id` is the design's one recursive
relationship, and it is the cheapest possible org chart: any reporting question is a
self-join, no extra table needed. `SET NULL` on delete is the humane choice — if a manager's
record goes away, their reportees keep their jobs and only the link clears; RESTRICT would
block the delete until every subordinate was reassigned by hand, CASCADE would delete the
subordinates outright (obviously wrong for people). The `manager_id IS NULL` case is the
head of the chain — NULL is doing real semantic work again, same as `paid_date`.

## 8 · `beneficiaries` — payees registered by a customer

**Granularity:** one row per (customer, payee account) registration.

| # | Column | Type | Null | Key | Default | Description |
|---|--------|------|:---:|-----|---------|-------------|
| 1 | `beneficiary_id` | INT | NO | **PK** · AI | — | Surrogate primary key |
| 2 | `customer_id` | INT | NO | **FK** → customers | — | The customer who saved this payee |
| 3 | `name` | VARCHAR(100) | NO | | — | Payee's registered display name |
| 4 | `account_no` | VARCHAR(20) | NO | | — | Payee's account number — **deliberately NOT a foreign key** (D3): payees usually bank elsewhere |
| 5 | `ifsc_code` | CHAR(11) | NO | | — | Payee's bank IFSC — same reasoning, any bank in India |
| 6 | `added_on` | DATE | NO | | `(CURRENT_DATE)` | When the payee was registered |

**Keys:** `pk_beneficiaries` · `uq_beneficiary_per_customer` **(customer_id, account_no, ifsc_code)** — the same customer cannot register the same payee twice
**Design notes — why only one FK (D3):** a foreign key on `account_no` could only ever
reference FinCore's own `accounts` — it would make external payees impossible to even
store, which defeats the entire feature. So `account_no` and `ifsc_code` stay plain columns
and the *real* integrity rule ("no duplicate payee per customer") is carried by the
composite UNIQUE instead. This is the table where I had to argue hardest with myself,
because a missing FK *looks* like an error to a reviewer — which is exactly why the
reasoning is written down here and in the design page.

## 9 · `cards` — debit/credit cards issued on an account

**Granularity:** one row per issued card.

| # | Column | Type | Null | Key | Default | Description |
|---|--------|------|:---:|-----|---------|-------------|
| 1 | `card_id` | INT | NO | **PK** · AI | — | Surrogate primary key |
| 2 | `account_id` | INT | NO | **FK** → accounts | — | The account the card draws on |
| 3 | `card_number` | CHAR(16) | NO | **UQ** | — | 16-digit PAN — UNIQUE; format enforced by CHECK (demo stores plaintext; production would store a hash) |
| 4 | `card_type` | ENUM | NO | | — | `debit` · `credit` |
| 5 | `expiry_date` | DATE | NO | | — | Card expiry |
| 6 | `status` | ENUM | NO | | `'active'` | `active` · `blocked` · `expired` |
| 7 | `issued_on` | DATE | NO | | — | Issue date |

**Keys:** `pk_cards` · `uq_cards_number` · FK `fk_card_account` (`ON DELETE CASCADE` — a card is an access token; without the account it is nothing)
**Check:** `chk_cards_number` (`card_number REGEXP '^[0-9]{16}$'`)
**Design notes:** `status` handles the card lifecycle the same way `loans.status` handles
loans: a short closed vocabulary with a sensible default. `CASCADE` here contrasts with
`transactions`' RESTRICT on purpose — a card is *owned* by the account it serves, while a
transaction is *history the bank owes everyone*. Same parent table (`accounts`), opposite
action, and the difference is the cleanest illustration of the §2 referential-integrity
policy. One honest caveat: this demo stores PANs in plaintext; a production system would
store only a hash and the last four digits — I am counting on the CHECK's regex keeping the
*shape* honest, not the secrecy.

---

## 10 · Foreign-key catalog — all 10, with actions

| # | Constraint | Child column | → Parent | ON DELETE | ON UPDATE | Why this action |
|---|-----------|--------------|----------|-----------|-----------|-----------------|
| 1 | `fk_accounts_customer` | `accounts.customer_id` | `customers` | **RESTRICT** | CASCADE | a customer with accounts can't be deleted |
| 2 | `fk_accounts_branch` | `accounts.branch_id` | `branches` | **RESTRICT** | CASCADE | a branch with accounts can't be deleted |
| 3 | `fk_txn_account` | `transactions.account_id` | `accounts` | **RESTRICT** | CASCADE | financial history never dies — closing an account is a status change, not a DELETE |
| 4 | `fk_loans_customer` | `loans.customer_id` | `customers` | **RESTRICT** | CASCADE | borrower's history is protected |
| 5 | `fk_loans_branch` | `loans.branch_id` | `branches` | **RESTRICT** | CASCADE | sanctioning branch's history is protected |
| 6 | `fk_payment_loan` | `loan_payments.loan_id` | `loans` | **CASCADE** | CASCADE | the schedule belongs to the loan — meaningless without it |
| 7 | `fk_emp_branch` | `employees.branch_id` | `branches` | **RESTRICT** | CASCADE | a branch with staff can't be deleted |
| 8 | `fk_emp_manager` | `employees.manager_id` | `employees` *(self)* | **SET NULL** | CASCADE | subordinates keep their jobs when a manager leaves — only the link clears |
| 9 | `fk_ben_customer` | `beneficiaries.customer_id` | `customers` | **CASCADE** | CASCADE | a payee list is personal data — removed with its owner |
| 10 | `fk_card_account` | `cards.account_id` | `accounts` | **CASCADE** | CASCADE | a card is an access token to the account — nothing alone |

**The whole policy in 3 lines:** RESTRICT = *audit history* · CASCADE = *owned data* · SET NULL = *reporting line*.
Count check: **6 RESTRICT · 3 CASCADE · 1 SET NULL**.

## 11 · CHECK constraint catalog — all 9 (v2)

| # | Constraint | Table | Rule | Rejects (error 3819) |
|---|-----------|-------|------|----------------------|
| 1 | `chk_accounts_balance` | accounts | `balance >= 0` | negative balances |
| 2 | `chk_txn_amount` | transactions | `amount > 0` | zero/negative movements |
| 3 | `chk_txn_transfer_pairing` | transactions | transfer type ⇔ `transfer_ref` present | deposits smuggling a ref; transfers missing one |
| 4 | `chk_loans_principal` | loans | `principal > 0` | non-positive loans |
| 5 | `chk_loans_rate` | loans | `0 <= interest_rate <= 100` | nonsense rates |
| 6 | `chk_loans_tenure` | loans | `tenure_months BETWEEN 1 AND 360` | tenures outside 1 month–30 years |
| 7 | `chk_payment_amount` | loan_payments | `amount > 0` | non-positive EMIs |
| 8 | `chk_emp_not_own_manager` | employees | `manager_id <> employee_id` (or NULL) | self-management |
| 9 | `chk_cards_number` | cards | `^[0-9]{16}$` | malformed PANs |

Remember the version floor: these fire only on MySQL **8.0.16+** — older servers accept the
syntax and then silently ignore every rule in this table.

## 12 · UNIQUE key catalog — all 7 (2 composite)

| # | Constraint | Table | Columns | Meaning |
|---|-----------|-------|---------|---------|
| 1 | `uq_branches_ifsc` | branches | `ifsc_code` | one IFSC per branch |
| 2 | `uq_customers_phone` | customers | `phone` | one phone per customer |
| 3 | `uq_customers_email` | customers | `email` | one email per customer |
| 4 | `uq_accounts_number` | accounts | `account_number` | account numbers never repeat |
| 5 | `uq_payment_instalment` | loan_payments | **(loan_id, instalment_no)** | no duplicated instalment within a loan — natural alternate key |
| 6 | `uq_beneficiary_per_customer` | beneficiaries | **(customer_id, account_no, ifsc_code)** | no duplicate payee per customer |
| 7 | `uq_cards_number` | cards | `card_number` | card numbers never repeat |

## 13 · Secondary indexes — the 3 beyond PK/UQ/FK indexes (v2)

| Index | Table (column) | Serves |
|-------|----------------|--------|
| `idx_txn_date` | transactions (txn_date) | date-range statements and reporting without a full scan |
| `idx_loan_status` | loans (status) | `WHERE status = 'active'` portfolio scans |
| `idx_payment_due` | loan_payments (due_date) | the overdue scan — `due_date < CURRENT_DATE` |

Rule of thumb encoded here: **a query that filters or groups on a column should not force a
full table scan.** PK, UNIQUE and FK columns are already indexed by InnoDB (every FK
creates/uses an index automatically) — v2 removed `idx_accounts_customer` because it
duplicated the automatic FK index, and the same logic forbids any new index on an FK column.

## 14 · ENUM domains — all 7

| Column | Allowed values | Default |
|--------|----------------|---------|
| `accounts.account_type` | savings · current · fixed_deposit | — |
| `transactions.txn_type` | deposit · withdrawal · transfer_out · transfer_in | — |
| `loans.loan_type` | home · vehicle · personal · education | — |
| `loans.status` | active · closed · defaulted | active |
| `employees.designation` | manager · loan_officer · teller · cashier | — |
| `cards.card_type` | debit · credit | — |
| `cards.status` | active · blocked · expired | active |

Why ENUM and not free text: the engine itself rejects typos like `'actve'` — integrity lives
in the database, not in application code. The trade-off is deliberate: ENUM suits frozen
business vocabularies; a *user-growable* list would need a lookup table instead (reasoning
in `DATABASE_DESIGN.md` §5).

## 15 · How the design supports the demo queries

| Demo query | Reads | Design feature that makes it work |
|--------------------------------|-------|-------------------------------------|
| Customers with an account but zero transactions | `accounts` ⟕ `transactions` | `LEFT JOIN … WHERE t.txn_id IS NULL` — no orphan noise |
| Overdue instalments (business Q7) | `loan_payments.paid_date`, `due_date` | derived, never stored (D6); `idx_payment_due` keeps the scan cheap |
| Customers holding more than one account | `accounts.customer_id` | pure `GROUP BY … HAVING COUNT(*) > 1` |
| A manager with ≥ 2 reportees | `employees.manager_id` | the self-referencing FK makes the self-join trivial |
| Complete transfer pairs | `transactions.transfer_ref` | 2-row transfer model (D2) + `chk_txn_transfer_pairing` |

Every query in this table reads like a plain sentence because the shape it needs is already
in the schema — that was the whole point of designing before querying.

---

**Sync contract:** 9 tables · 57 columns · 10 FK (6 RESTRICT / 3 CASCADE / 1 SET NULL) · 9 CHECK · 7 UNIQUE · 3 secondary indexes (DDL v2).
If `create_tables.sql` changes, this file, `DATABASE_DESIGN.md` §2 and all diagrams must be regenerated together.
