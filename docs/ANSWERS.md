# The answers — every question, its result on the loaded seed

> **Owner:** Aryan Rao (AU25UG-006) · **DDL:** v2.1 · **Seed:** [`data/insert_data.sql`](../data/insert_data.sql) v1.1 (3,242 rows)

This file is the answers file. The questions live where they belong — the curated business set in the [README](../README.md#13--the-questions-it-answers), the three unique questions in [README §13.2](../README.md#132-the-three-unique-questions--beyond-the-assignment), the normalization proof checks in [`queries/normalization_proof.sql`](../queries/normalization_proof.sql) — and every *answer*, with its exact expected result on the loaded seed, lives here. The three parts:

- **[Part A](#part-a-the-curated-business-questions-q1-to-q10)** — the curated business questions, Q1 to Q10 (the team's assignment set)
- **[Part B](#part-b-the-three-unique-questions-b1-to-b3)** — the three unique questions, B1 to B3 (beyond the assignment)
- **[Part C](#part-c-the-normalization-proof-questions-n1-to-n11)** — the normalization proof questions, N1 to N11 (1NF → BCNF, executed)

**How the answers were produced.** Every number below was computed by replaying the seed's deterministic insert formulas against the queries — the same replay that verified all 3,242 rows against every DDL rule (0 violations, [README §14](../README.md#14--how-the-design-was-verified)). The seed contains no `RAND()` and no `CURDATE()`, so a fresh run reproduces every answer exactly. To see any of them live:

```text
mysql -u root -p < schema/create_tables.sql     -- the DDL (idempotent — the reset button)
mysql -u root -p < data/insert_data.sql         -- the seed
mysql -u root -p < queries/aryan_queries.sql         -- Part A's Q8–Q10, executed
mysql -u root -p < queries/normalization_proof.sql   -- Part C, executed
mysql -u root -p < queries/bonus_queries.sql         -- Part B, executed
```

One convention throughout: a *screenshot slot* is the exact path where that question's result screenshot goes (`docs/screenshots/queries/` for the business and unique questions, [`docs/screenshots/`](screenshots) for the proof checks — those 11 already exist).

---

## Part A. The curated business questions (Q1 to Q10)

These are the team's ten assigned questions, split across the six of us per [README §16](../README.md#16--team-and-contributions). The questions and their owners are listed in [README §13.1](../README.md#131-the-curated-set--who-did-what-and-where-the-screenshots-go); Q1–Q7 live in `queries/query.sql` (that file is the team's, maintained together) and Q8–Q10 are Aryan's, in [`queries/aryan_queries.sql`](../queries/aryan_queries.sql) — each following the same house rules: one plain sentence, joins only along declared foreign keys, everything time-dependent derived (D6), never stored. All ten answers are below.

### Q1. Customers holding more than one account

**Owner:** Harsita · **Screenshot slot:** `docs/screenshots/queries/q01_result.png`

**Answer: 50 customers.** The seed registers 200 customers holding 250 accounts — 150 hold exactly one account, and the remaining 50 hold two. The query groups `accounts` by `customer_id` and keeps the groups with `HAVING COUNT(*) > 1`; the expected result grid is 50 rows of *(full name, accounts held = 2)*.

### Q2. Branch league table — deposits by branch

**Owner:** Thanmiksha · **Screenshot slot:** `docs/screenshots/queries/q02_result.png`

**Answer: Branch 1 leads with ₹83.92 lakh in deposits — 5.4× the runner-up.** The top of the league table:

| Rank | Branch | Total deposits (₹) |
|---|---|---|
| 1 | Branch 1 | 8,392,051 |
| 2 | Branch 13 | 1,546,962 |
| 3 | Branch 8 | 1,424,027 |

One measurement note worth having ready for the viva: if the league is measured on *stored balances* (`SUM(a.balance)`) instead of *deposit transactions*, Branch 1 still leads but by 4.5× (₹2.38 crore vs ₹52.63 lakh) — the 5.4× figure is the deposit basis, which is what the question asks. The two bases legitimately differ because balances move with withdrawals and transfers too.

### Q3. *(text in `queries/query.sql`)*

**Owner:** Jashan · **Screenshot slot:** `docs/screenshots/queries/q03_result.png`

The question text and SQL are Jashan's, in `queries/query.sql`. Its expected result joins this file with the screenshot when it is captured.

### Q4. Dormant accounts — open, never transacted

**Owner:** Ganga · **Screenshot slot:** `docs/screenshots/queries/q04_result.png`

**Answer: 46 accounts** — a `LEFT JOIN transactions` that keeps the rows where `txn_id IS NULL`:

| Account type | Dormant | Of which engineered dormant |
|---|---|---|
| fixed_deposit | 38 | 2 |
| savings | 6 | 6 |
| current | 2 | 2 |
| **Total** | **46** | **10** |

The honest note, because it will be asked: the seed deliberately engineered 10 dormant accounts (241–250), but 36 fixed deposits land in the same result — FDs never take teller traffic by design, so the `LEFT JOIN` sees them as "never transacted". Whether an untouched FD should count as *dormant* is a business-semantics question, flagged in the seed's own self-check; the count 46 is correct for the query as posed.

### Q5. *(text in `queries/query.sql`)*

**Owner:** Amruta · **Screenshot slot:** `docs/screenshots/queries/q05_result.png`

The question text and SQL are Amruta's, in `queries/query.sql`. Its expected result joins this file with the screenshot when it is captured.

### Q6. *(text in `queries/query.sql`)*

**Owner:** Jashan · **Screenshot slot:** `docs/screenshots/queries/q06_result.png`

The question text and SQL are Jashan's, in `queries/query.sql`. Its expected result joins this file with the screenshot when it is captured.

### Q7. Overdue instalments — derived, never stored

**Owner:** Thanmiksha · **Screenshot slot:** `docs/screenshots/queries/q07_result.png`

**Answer: 71 rows** — instalments with `paid_date IS NULL AND due_date < CURRENT_DATE`:

| Loan status | Overdue instalments |
|---|---|
| active | 16 |
| defaulted | 55 |
| **Total** | **71** |

The count is date-stable: the newest unpaid due date anywhere in the seed is **2026-07-09**, already in the past, so the answer no longer moves with the calendar. This is decision D6 in action — there is no `is_overdue` column; the truth is derived at query time (`idx_payment_due` keeps it off a full table read).

### Q8. Where do our customers send money? — the payee bank split

**Owner:** Aryan · **Screenshot slot:** `docs/screenshots/queries/q08_result.png`

**Answer: four in five registered payees (160 of 200, 80%) bank elsewhere; the 40 who bank with FinCore were registered by just 29 customers.** Each of the 200 payees is classified by its IFSC prefix — `AUSB` marks a FinCore branch — with a single `CASE`, no join needed:

| Payee bank | Payees registered | Registering customers |
|---|---|---|
| FinCore (`AUSB…`) | 40 | 29 |
| Other banks | 160 | 160 |

This is design decision D3, quantified. `beneficiaries` deliberately carries **no** foreign key on the payee account — payees may hold accounts at any bank in India, and a "rigorous" FK there would have made four fifths of this population unrepresentable. The `CASE`/`LIKE` on the IFSC prefix is classification, not verification; the audit variant ("are any `AUSB`-coded payees pointing at branches that do not exist?") would be a `LEFT JOIN` to `branches` — a data-quality question, deliberately not this one. One more read worth having ready: the 200 payees were registered by 160 distinct customers in total, and the 29 FinCore registrants all sit inside that 160 — registering a fellow FinCore account holder is something repeat registrants do.

### Q9. The five largest transfers, reassembled

**Owner:** Aryan · **Screenshot slot:** `docs/screenshots/queries/q09_result.png`

**Answer: the biggest transfer ever moved on the seed is ₹47,910 — account 111 → account 136, reference `TR0000000010`.** The five largest of the seed's 30 transfers:

| # | transfer_ref | from_account | to_account | amount (₹) |
|---|---|---|---|---|
| 1 | TR0000000010 | 111 | 136 | 47,910.00 |
| 2 | TR0000000020 | 21 | 46 | 45,820.00 |
| 3 | TR0000000030 | 131 | 156 | 43,730.00 |
| 4 | TR0000000009 | 100 | 125 | 43,319.00 |
| 5 | TR0000000019 | 10 | 35 | 41,229.00 |

This is the D2 transfer model doing what it was built for: a transfer is two paired rows sharing a `transfer_ref` (`chk_txn_transfer_pairing` guarantees the pairing), and the query reassembles each pair with two conditional aggregates — the `transfer_out` leg supplies `from_account`, the `transfer_in` leg `to_account`, and `MIN` simply picks the single non-NULL value each column holds. It is a pivot by hand, two columns wide. Context to quote: 30 transfers in all, averaging ₹25,160.50, so the top five all sit well above the mean. The `GROUP BY` includes `amount` because it is functionally dependent on the pair — MySQL-legal, and it keeps the query honest under `ONLY_FULL_GROUP_BY`.

### Q10. The recovery book — collected vs scheduled, by loan status

**Owner:** Aryan · **Screenshot slot:** `docs/screenshots/queries/q10_result.png`

**Answer: closed loans are 100.0% collected and the active book 98.1% — and the defaulted book collected just 16.7% of its scheduled value before default.**

| Loan status | Loans | Instalments | Scheduled (₹) | Collected (₹) | Recovery |
|---|---|---|---|---|---|
| active | 141 | 846 | 8,608,383.84 | 8,441,565.84 | 98.1% |
| closed | 48 | 288 | 571,654.08 | 571,654.08 | 100.0% |
| defaulted | 11 | 66 | 588,799.44 | 98,133.24 | 16.7% |

The purest demonstration of D6 in the whole set: there is no `recovery_pct`, no `outstanding_amount` column anywhere — scheduled and collected are both derived from `loan_payments` at query time, and the percentage is computed in the `SELECT`. The finding is the payload: the defaulted book (11 loans, ₹5.89 lakh scheduled) yielded one sixth of its value before default, while the closed book is fully collected by definition. And unlike Q7's overdue count, this answer is *date-stable*: `paid_date` is history — once an instalment is paid, that fact never changes — so the recovery percentages cannot drift with the calendar. Past facts are safe to aggregate; calendar-dependent truths must be derived fresh.

*(Q8–Q10 are Aryan's closing tranche of the assigned set — distinct from the three *unique* questions in Part B below, which are extras beyond the assignment.)*

---

## Part B. The three unique questions (B1 to B3)

Each of these uses a MySQL 8 capability that none of the ten assigned questions needs — a recursive CTE, a ranking window function, and a logarithmic audit screen. All three are runnable as-is from [`queries/bonus_queries.sql`](../queries/bonus_queries.sql), each with its expected result in comments; this part is the answers and the walkthrough. Screenshot slots: `docs/screenshots/queries/b1_result.png`, `b2_result.png`, `b3_result.png`.

### B1. The org chart, unrolled (recursive CTE)

**The question.** How deep does the reporting line actually go, and who sits at each depth? The self-referencing `MANAGES` foreign key (`employees.manager_id`, the one recursive relationship in the model) answers "who reports to whom" one level at a time — walking it needs recursion.

<details>
<summary>The SQL (also in <a href="../queries/bonus_queries.sql">queries/bonus_queries.sql</a>)</summary>

```sql
WITH RECURSIVE org_chart AS (
    SELECT employee_id, full_name, manager_id,
           1 AS depth,
           CAST(full_name AS CHAR(500)) AS chain
    FROM employees
    WHERE manager_id IS NULL              -- the top of each reporting tree
    UNION ALL
    SELECT e.employee_id, e.full_name, e.manager_id,
           oc.depth + 1,
           CONCAT(oc.chain, ' > ', e.full_name)
    FROM employees e
    JOIN org_chart oc ON e.manager_id = oc.employee_id
)
SELECT depth AS org_level, COUNT(*) AS staff_at_level
FROM org_chart
GROUP BY depth
ORDER BY depth;
```
</details>

**Answer: 2 rows.**

| org_level | staff_at_level |
|---|---|
| 1 | 50 |
| 2 | 150 |

Level 1 is the 50 branch heads (`manager_id IS NULL` — one per branch); level 2 is everyone else. The seed's reporting forest is deliberately flat, and the query is depth-agnostic: swap the final `SELECT` for the `chain`/`depth` variant in the script (B1b) and the longest reporting line comes back — depth 2, e.g. `Lakshmi Bose > Vikas Pai`. Run it on a deeper org chart and it simply returns more levels.

### B2. Dominance, or spike? (ranking window function)

**The question.** The branch league table (Q2) crowns Branch 1 with a 5.4× lead on deposits — but was it ahead every month, or did a few explosive months carry it? This query *audits another query's conclusion*: one leaderboard per month, rank 1 only.

<details>
<summary>The SQL (also in <a href="../queries/bonus_queries.sql">queries/bonus_queries.sql</a>)</summary>

```sql
WITH monthly AS (
    SELECT a.branch_id,
           DATE_FORMAT(t.txn_date, '%Y-%m') AS ym,
           SUM(t.amount) AS deposits
    FROM transactions t
    JOIN accounts a ON a.account_id = t.account_id
    WHERE t.txn_type = 'deposit'
    GROUP BY a.branch_id, ym
),
ranked AS (
    SELECT ym, branch_id, deposits,
           RANK() OVER (PARTITION BY ym ORDER BY deposits DESC) AS rnk
    FROM monthly
)
SELECT r.ym AS month, b.name AS leading_branch, r.deposits
FROM ranked r
JOIN branches b ON b.branch_id = r.branch_id
WHERE r.rnk = 1
ORDER BY r.ym;
```
</details>

**Answer: 12 rows — and the verdict is "spike, not dominance."**

| Month | Leading branch | Deposits (₹) | Margin over runner-up |
|---|---|---|---|
| 2025-10 | Branch 16 | 223,965 | 1.1× |
| 2025-11 | Branch 6 | 215,665 | 1.0× |
| 2025-12 | Branch 6 | 207,365 | 1.1× |
| 2026-01 | Branch 25 | 282,786 | 1.4× |
| 2026-02 | Branch 20 | 234,806 | 1.5× |
| 2026-03 | Branch 8 | 260,638 | 1.2× |
| 2026-04 | Branch 10 | 218,206 | 1.1× |
| **2026-05** | **Branch 1** | **1,728,094** | **6.6×** |
| **2026-06** | **Branch 1** | **2,469,186** | **10.5×** |
| **2026-07** | **Branch 1** | **1,989,465** | **9.7×** |
| **2026-08** | **Branch 1** | **1,350,482** | **8.6×** |
| 2026-09 | Branch 8 | 147,544 | 1.0× |

Branch 1 leads only the four months from May to August 2026; the other eight months go to six different branches (16 once, 6 twice, 25 once, 20 once, 8 twice, 10 once). The league-table crown is four explosive months, not steady dominance — exactly the kind of thing a `GROUP BY` total hides and a window function per partition exposes.

### B3. The Benford screen (first-digit audit)

**The question.** Real transaction amounts follow Benford's law — the chance of a first digit *d* is log₁₀(1 + 1/d), so amounts starting with 1 should be about 30.1% and amounts starting with 9 about 4.6%. Fabricated, formula-built amounts deviate. Where do our 552 amounts land?

<details>
<summary>The SQL (also in <a href="../queries/bonus_queries.sql">queries/bonus_queries.sql</a>)</summary>

```sql
WITH digits AS (
    SELECT CAST(SUBSTRING(CAST(amount AS CHAR), 1, 1) AS UNSIGNED) AS first_digit,
           COUNT(*) AS observed
    FROM transactions
    GROUP BY first_digit
),
totals AS (SELECT COUNT(*) AS n FROM transactions)
SELECT d.first_digit, d.observed,
       ROUND(100 * d.observed / t.n, 1)               AS actual_pct,
       ROUND(100 * LOG10(1 + 1 / d.first_digit), 1)   AS benford_pct,
       ROUND(100 * d.observed / t.n
             - 100 * LOG10(1 + 1 / d.first_digit), 1) AS deviation_pp
FROM digits d CROSS JOIN totals t
ORDER BY ABS(100 * d.observed / t.n - 100 * LOG10(1 + 1 / d.first_digit)) DESC;
```
</details>

**Answer: 9 rows — digit 1 over-produced, digit 2 under.**

| First digit | Observed | Actual % | Benford % | Deviation (pp) |
|---|---|---|---|---|
| 1 | 208 | 37.7 | 30.1 | **+7.6** |
| 2 | 55 | 10.0 | 17.6 | **−7.6** |
| 3 | 47 | 8.5 | 12.5 | −4.0 |
| 4 | 47 | 8.5 | 9.7 | −1.2 |
| 5 | 43 | 7.8 | 7.9 | −0.1 |
| 6 | 41 | 7.4 | 6.7 | +0.7 |
| 7 | 37 | 6.7 | 5.8 | +0.9 |
| 8 | 37 | 6.7 | 5.1 | +1.6 |
| 9 | 37 | 6.7 | 4.6 | +2.1 |

That is the exact fingerprint of formula-built amounts — which is precisely what a deterministic seed is, so the screen *worked*: it flagged our manufactured data as manufactured. The honest note: Benford's law describes populations, not 552-row samples, so this is a demonstration of the technique (one CTE + `LOG10()` turning an amounts column into a fraud-audit signal), not evidence of anything wrong.

---

## Part C. The normalization proof questions (N1 to N11)

The proof that all nine relations are in BCNF is *argued* in [`NORMALIZATION.md`](NORMALIZATION.md) (FD by FD) and *executed* as eleven plain SELECTs in [`queries/normalization_proof.sql`](../queries/normalization_proof.sql) — each check is a question about the schema or the data, and this part is the answers. The eleven result screenshots are in [`docs/screenshots/`](screenshots) (numbered `01`–`11` in the order below), walked through in [NORMALIZATION.md §9](NORMALIZATION.md#9--the-proof-executed--sql-and-results).

| Check | The question | Verdict on the seed |
|---|---|---|
| [N1](#n1-1nf-atomic-domains) | 1NF · atomic domains | 57 columns, 0 non-atomic |
| [N2](#n2-1nf-no-repeating-groups) | 1NF · no repeating groups | an instalment is a row, not a column |
| [N3](#n3-2nf-single-column-primary-keys) | 2NF · single-column PKs | 9 tables, `pk_columns = 1` each |
| [N4](#n4-2nf-composite-key-tested-loan_payments) | 2NF · composite key: `loan_payments` | 0 / 0 — no partial dependency |
| [N5](#n5-2nf-composite-key-tested-beneficiaries) | 2NF · composite key: `beneficiaries` | empty set — no partial dependency |
| [N6](#n6-3nf-one-home-per-fact) | 3NF · one home per fact | `city` lives in `branches` only |
| [N7](#n7-3nf-the-update-anomaly-measured) | 3NF · update anomaly, measured | 1 / 12 / 8 |
| [N8](#n8-3nf-would-be-transitive-dependencies-refuted) | 3NF · transitive candidates refuted | no non-key column determines another |
| [N9](#n9-bcnf-every-determinant-is-an-enforced-key) | BCNF · determinants are enforced keys | 16 keys: 9 PK + 7 UNIQUE |
| [N10](#n10-bcnf-the-fds-hold-in-the-data) | BCNF · the FDs hold in the data | 7 determinants, 0 duplicates |
| [N11](#n11-bcnf-looks-unique-is-not-a-determinant) | BCNF · "looks unique" refuted | 40 shared names determine nothing |

### N1. 1NF atomic domains

**The question.** Does every attribute hold a single scalar value — any `SET` (multi-valued) or `JSON` (structured) columns? **Answer: 57 columns total, 0 non-atomic.** One row: `total_columns = 57, non_atomic_columns = 0`.

### N2. 1NF no repeating groups

**The question.** Does the broken `emi1_due / emi2_due / …` column pattern exist anywhere — or is an instalment one *row*? **Answer: loan 1's schedule comes back as 6 rows, one per instalment** (a 36-EMI loan would have needed 72 columns; here it is just 36 rows):

| loan_id | instalment_no | due_date | amount |
|---|---|---|---|
| 1 | 1 | 2023-03-04 | 1026.78 |
| 1 | 2 | 2023-04-04 | 1026.78 |
| 1 | 3 | 2023-05-04 | 1026.78 |
| 1 | 4 | 2023-06-04 | 1026.78 |
| 1 | 5 | 2023-07-04 | 1026.78 |
| 1 | 6 | 2023-08-04 | 1026.78 |

### N3. 2NF single-column primary keys

**The question.** Is any primary key composite (which would open the door to partial dependencies)? **Answer: 9 rows — every table's PK is exactly one column** (decision D1, surrogate keys). 2NF holds by construction; there is no *part* of a key to depend on.

### N4. 2NF composite key tested: loan_payments

**The question.** `loan_payments` *does* have a composite candidate key — `(loan_id, instalment_no)`. Does either *half* of it already determine `due_date` (a partial dependency)? **Answer: 0 / 0** — no `loan_id` and no `instalment_no` group collapses to a single due date. Neither half carries the schedule; only the pair does.

### N5. 2NF composite key tested: beneficiaries

**The question.** `beneficiaries`' candidate key is `(customer_id, account_no, ifsc_code)`. If the payee *name* were a fact about `customer_id` alone (part of the key), all of a customer's payees would share one name. **Answer: the empty set** — no customer with multiple payees has them all under one name.

### N6. 3NF one home per fact

**The question.** Does any table store a second copy of another table's fact (the transitive-dependency trap)? **Answer: 3 rows — `city` exists in `branches` only; `ifsc_code` in `branches` and `beneficiaries`** — and the latter is the *payee's* bank, an outside-bank fact by design D3, not a copy of any FinCore branch row.

### N7. 3NF the update anomaly, measured

**The question.** How many rows would you edit to relocate branch 1? **Answer: 1 / 12 / 8** — the city fact sits in **1** row, while **12** accounts and **8** loans depend on that branch. One `UPDATE` moves the branch; in the un-normalized `lending_flat` table the same fact sat in every dependent row, and one missed edit contradicted the data.

### N8. 3NF would-be transitive dependencies, refuted

**The question.** A 3NF violation needs a non-key column determining another non-key column. Do the two plausible candidates hold? **Answer: neither** — each of the 4 designations spans 50 branches (so `designation` does not determine `branch_id`), and every account type spans many customers and many branches (so `account_type` determines neither):

| designation | staff | branches spanned |
|---|---|---|
| cashier | 50 | 50 |
| loan_officer | 50 | 50 |
| manager | 50 | 50 |
| teller | 50 | 50 |

| account_type | accounts | customers | branches |
|---|---|---|---|
| current | 50 | 46 | 11 |
| fixed_deposit | 50 | 46 | 10 |
| savings | 150 | 114 | 25 |

### N9. BCNF every determinant is an enforced key

**The question.** BCNF demands every non-trivial determinant be a candidate key — so what does the *engine itself* report as enforced keys? **Answer: 16 rows — 9 PRIMARY + 7 UNIQUE, exactly the candidate keys of the proof table** in [NORMALIZATION.md §5](NORMALIZATION.md#5--the-proof--all-nine-relations-fd-by-fd): `pk_*` on all nine tables plus `uq_branches_ifsc` (`ifsc_code`), `uq_customers_phone`, `uq_customers_email`, `uq_accounts_number`, `uq_cards_number`, `uq_payment_instalment` (`loan_id, instalment_no`), `uq_beneficiary_per_customer` (`customer_id, account_no, ifsc_code`). The FDs and the constraints are the same statement in two languages.

### N10. BCNF the FDs hold in the data

**The question.** Does every FD claimed in the proof actually hold on the loaded data — does each determinant identify exactly one row? **Answer: 7 rows, `duplicate_groups = 0` everywhere:**

| determinant | duplicate groups |
|---|---|
| branches.ifsc_code | 0 |
| customers.phone | 0 |
| customers.email | 0 |
| accounts.account_number | 0 |
| cards.card_number | 0 |
| loan_payments.(loan_id, instalment_no) | 0 |
| beneficiaries.(customer_id, account_no, ifsc_code) | 0 |

### N11. BCNF "looks unique" is not a determinant

**The question.** `full_name` appears in three tables — does a name identify anyone? **Answer: 40 names are shared by a customer and an employee** (the seed draws both from the same 40 × 40 name pools — e.g. Ananya Agarwal, Ananya Bansal, Ananya Chauhan are each both a customer and a staff member). Names are not identifiers; only *enforced* keys are determinants. That is the difference between a functional dependency and an instance pattern.

---

## Keeping this file honest

The DDL is the source of truth and the seed is the source of every number here; if either changes, this file is regenerated with them (the sync contract in [README §14](../README.md#14--how-the-design-was-verified)). Answers still landing here with the final update: Q3, Q5, Q6 (with their screenshots). The two honest instance-vs-schema notes from the proof script — flat EMI amounts and flat product rates being *seed* properties, not schema FDs — carry over unchanged: "looks determining in one load of data" is never a functional dependency, which is exactly what N11 is for.
