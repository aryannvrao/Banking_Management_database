# The answers — every question, its result on the loaded seed

> **Owner:** Aryan Rao (AU25UG-006) · **DDL:** v2.1 · **Seed:** [`data/insert_data.sql`](../data/insert_data.sql) v1.1 (3,242 rows)

This file is the answers file. The questions live where they belong — the curated business set in the [README](../README.md#13--the-questions-it-answers)the normalization proof checks in [`queries/normalization_proof.sql`](../queries/normalization_proof.sql) — and every *answer*, with its exact expected result on the loaded seed, lives here. The two parts:

- **[Part A](#part-a-the-curated-business-questions-q1-to-q10)** — the curated business questions, Q1 to Q10 (the team's assignment set)

- **[Part B](#part-c-the-normalization-proof-questions-n1-to-n11)** — the normalization proof questions, N1 to N11 (1NF → BCNF, executed)

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

### Perfect. Based on **your actual MySQL output**, write Q2 like this:

### Q2. Branch league table — deposits by branch

**Owner:** Thammiksha · **Screenshot slot:** `docs/screenshots/queries/q02_result.png`

**Answer:** **Main Road Branch, Bengaluru** manages the highest deposits with **₹83.92 lakh** in total deposits.

| Rank | Branch                      | Total deposits (₹) |
| ---- | --------------------------- | -----------------: |
| 1    | Main Road Branch, Bengaluru |       8,392,051.00 |

**Conclusion:** Main Road Branch, Bengaluru has the highest total deposits of **₹83.92 lakh**.

### Q3. Average account balance by branch

**Owner:** Jashan · **Screenshot slot:** `docs/screenshots/queries/q03_result.png`

**Answer:** The average account balance varies across branches, with **Main Road Branch, Bengaluru** having the highest average account balance of **₹19,83,345.50** among the displayed branches.

| Branch ID | Branch                              | Average balance (₹) |
| --------: | ----------------------------------- | ------------------: |
|         1 | Main Road Branch, Bengaluru         |        1,983,345.50 |
|         4 | Riverside Branch, Hubballi          |          455,063.50 |
|         5 | Market Branch, Chamundi             |          462,982.50 |
|         6 | Central Branch, Coimbatore          |          470,901.50 |
|         7 | Tech Park Branch, Madurai           |          478,820.50 |
|         8 | Old Town Branch, Salem              |          486,739.50 |
|         9 | Main Road Branch, Erode             |          494,658.50 |
|        10 | City Centre Branch, Mumbai          |          502,577.50 |
|        11 | Industrial Estate Branch, Pune      |          510,496.50 |
|        12 | Riverside Branch, Nagpur            |          518,415.50 |
|        13 | Market Branch, Nashik               |          526,334.50 |
|        14 | Central Branch, Thane               |          439,753.50 |
|        15 | Tech Park Branch, New Delhi         |          447,672.50 |
|        16 | Old Town Branch, Gurugram           |          453,543.60 |
|        17 | Main Road Branch, Noida             |          460,770.70 |
|        18 | City Centre Branch, Ghaziabad       |          467,997.80 |
|        19 | Industrial Estate Branch, Hyderabad |          475,224.90 |
|        20 | Riverside Branch, Warangal          |          387,452.00 |

**Conclusion:** Based on the displayed result, **Main Road Branch, Bengaluru has the highest average account balance at ₹19.83 lakh**.


### Q4. Yes, this is the **actual output for Q4 — customers with no transactions**. Based on the result shown in your screenshot, write it like this:

### Q4. Customers with no transactions

**Owner:** siva · **Screenshot slot:** `docs/screenshots/queries/q04_result.png`

**Answer:** The query identifies customers who have **no transaction records associated with any of their accounts** by using `LEFT JOIN` and filtering for missing transaction IDs.

| Customer ID | Customer        |
| ----------: | --------------- |
|           3 | Deepa Nayak     |
|           7 | Meera Desai     |
|           8 | Naveen Joshi    |
|           9 | Rekha Sheikh    |
|          13 | Kavya Khanna    |
|          15 | Nidhi Rao       |
|          17 | Chaitra Agarwal |
|          18 | Karthik Shah    |
|          23 | Priya Krishnan  |
|          24 | Rohit Kapoor    |
|          25 | Ishita Shenoy   |
|          27 | Archana Bose    |
|          35 | Ananya Malhotra |
|          39 | Sunitha Yadav   |
|          45 | Geetha Das      |
|          55 | Nidhi Menon     |
|          59 | Lakshmi Shetty  |
|          69 | Sneha Sharma    |
|          75 | Ananya Bansal   |
|          79 | Sunitha Singh   |
|          89 | Rekha Sinha     |
|          99 | Lakshmi Hegde   |
|         105 | Ishita Desai    |
|         115 | Ananya Agarwal  |
|         119 | Sunitha Kaur    |

**Conclusion:** These customers have **no transactions recorded against their accounts** in the database.


### Q5. *(text in `queries/query.sql`)*

**Owner:** Amruta · **Screenshot slot:** `docs/screenshots/queries/q05_result.png`

The question text and SQL are Amruta's, in `queries/query.sql`. Its expected result joins this file with the screenshot when it is captured.

### Q6.### Q6. Customers with active loans

**Owner:** jashan· **Screenshot slot:** `docs/screenshots/queries/q06_result.png`

**Answer:** The query identifies customers who currently have **active loans**, along with their loan type and principal amount.

| Customer ID | Customer           | Loan ID | Loan Type | Principal (₹) |
| ----------: | ------------------ | ------: | --------- | ------------: |
|           4 | Prakash Nair       |       1 | Vehicle   |        53,571 |
|           7 | Meera Desai        |       2 | Personal  |        57,142 |
|          10 | Mohan Singh        |       3 | Education |        60,713 |
|          16 | Dinesh Das         |       5 | Vehicle   |        67,855 |
|          19 | Lakshmi Kulkarni   |       6 | Personal  |        71,426 |
|          22 | Ravi Patel         |       7 | Education |        74,997 |
|          28 | Ajay Chauhan       |       9 | Vehicle   |        82,139 |
|          31 | Pooja Sinha        |      10 | Personal  |        85,710 |
|          34 | Murali Subramanian |      11 | Education |        89,281 |
|          40 | Arjun Iyer         |      13 | Vehicle   |        96,423 |

**Conclusion:** The query successfully returns customers whose loan status is **`active`**, together with their corresponding loan details.



### Q7. Overdue loan payments

**Owner:** Thammiksha · **Screenshot slot:** `docs/screenshots/queries/q07_result.png`

**Answer:** The database contains **15 overdue loan payments**. These payments have a `NULL` paid date and a due date earlier than the current date.

| Payment ID | Loan ID | Instalment No. | Due Date   | Paid Date | Amount (₹) |
| ---------: | ------: | -------------: | ---------- | --------- | ---------: |
|         99 |      17 |              3 | 2025-08-29 | NULL      |   2,121.88 |
|        507 |      85 |              3 | 2025-09-03 | NULL      |   6,776.09 |
|        915 |     153 |              3 | 2025-09-07 | NULL      |  11,430.29 |
|        100 |      17 |              4 | 2025-09-29 | NULL      |   2,121.88 |
|        508 |      85 |              4 | 2025-10-03 | NULL      |   6,776.09 |
|        916 |     153 |              4 | 2025-10-07 | NULL      |  11,430.29 |
|        101 |      17 |              5 | 2025-10-29 | NULL      |   2,121.88 |
|        509 |      85 |              5 | 2025-11-03 | NULL      |   6,776.09 |
|        376 |      63 |              4 | 2025-11-06 | NULL      |   6,587.89 |
|        917 |     153 |              5 | 2025-11-07 | NULL      |  11,430.29 |
|        102 |      17 |              6 | 2025-11-29 | NULL      |   2,121.88 |
|        510 |      85 |              6 | 2025-12-03 | NULL      |   6,776.09 |
|        918 |     153 |              6 | 2025-12-07 | NULL      |  11,430.29 |
|        535 |      90 |              1 | 2026-03-25 | NULL      |  11,863.85 |
|        808 |     135 |              4 | 2026-06-10 | NULL      |  12,747.87 |
|        268 |      45 |              4 | 2026-07-09 | NULL      |   4,038.32 |

**Conclusion:** The query identifies loan payments that are **past their due date and still unpaid (`paid_date IS NULL`)**, which are treated as overdue in the FinCore database.


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


## Part b. The normalization proof questions (N1 to N11)

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
