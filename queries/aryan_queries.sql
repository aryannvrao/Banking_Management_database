-- ============================================================================
--  FinCore - Aryan's three curated questions (Q8, Q9, Q10)
--  File    : queries/aryan_queries.sql
--  Target  : MySQL 8.0.16+ · run AFTER schema/create_tables.sql (DDL v2.1)
--            and data/insert_data.sql (seed v1.1)
--  Owner   : Aryan Rao (AU25UG-006)
--
--  These three close the team's curated set (README section 13.1): Q1-Q7
--  live in the team's queries/query.sql, one owner each, and these are
--  mine. Each follows the house rules the other seven followed - the
--  question is one plain sentence a banker would use, every join follows
--  a declared foreign key, anything time-dependent is derived at query
--  time (D6), never stored, and each has an exact expected answer on the
--  deterministic seed, so all three can be demonstrated live.
--
--  One design decision each: Q8 quantifies D3 (payees may bank anywhere,
--  so beneficiaries carries no FK on the payee account), Q9 exercises D2
--  (a transfer is two paired rows sharing a transfer_ref), and Q10 is the
--  purest demonstration of D6 in the whole set (recovery is computed,
--  never stored).
--
--  The answers - exact result grids and how to read them - are in
--  docs/ANSWERS.md Part A (Q8-Q10). Result screenshots:
--  docs/screenshots/queries/q08_result.png, q09_result.png, q10_result.png.
--
--  HOW TO RUN
--    mysql -u root -p < schema/create_tables.sql
--    mysql -u root -p < data/insert_data.sql
--    mysql -u root -p < queries/aryan_queries.sql
--    (or open in MySQL Workbench and execute block by block)
--
--  RESULTS AT A GLANCE
--    Q8  payee bank split      200 payees classified by IFSC prefix -
--                              160 bank elsewhere (80%), 40 with FinCore
--                              (registered by just 29 customers)
--    Q9  top-5 transfers       the biggest is Rs 47,910 (account 111 to
--                              136, TR0000000010); 30 transfers in all,
--                              averaging Rs 25,160.50
--    Q10 recovery book         closed loans 100.0% collected, the active
--                              book 98.1% - and the defaulted book just
--                              16.7% of its scheduled value
-- ============================================================================

USE fincore;

-- ===== [Q8] Where do our customers send money? — the payee bank split ====
-- QUESTION: of the payees our customers have registered, how many bank
--           with FinCore and how many bank elsewhere? This is the D3
--           question in disguise - beneficiaries deliberately carries no
--           FK on the payee account precisely because payees may hold
--           accounts at any bank in India, and this query quantifies that
--           design choice. FinCore branches are identifiable by their
--           IFSC prefix (AUSB); classification needs no join at all.
-- EXPECT: 2 rows - FinCore: 40 payees registered by 29 customers; Other
--         banks: 160 payees registered by 160 customers. The finding
--         worth saying aloud: four in five registered payees (80%) bank
--         elsewhere - exactly the population the "rigorous" FK design
--         would have made unrepresentable. (Scale note: beneficiaries is
--         200 rows and classified with a single CASE - a full scan, no
--         index needed and none exists.)
SELECT CASE WHEN b.ifsc_code LIKE 'AUSB%' THEN 'FinCore'
            ELSE 'Other banks' END       AS payee_bank,
       COUNT(*)                          AS payees_registered,
       COUNT(DISTINCT b.customer_id)     AS registering_customers
FROM beneficiaries b
GROUP BY payee_bank
ORDER BY payee_bank;

-- ===== [Q9] The five largest transfers, reassembled ======================
-- QUESTION: show the five largest transfers ever moved, with the sending
--           and receiving accounts. This is the D2 model doing what it
--           was built for - a transfer is two paired rows sharing a
--           transfer_ref (guaranteed a pair by chk_txn_transfer_pairing),
--           and this query reassembles the pairs with two conditional
--           aggregates, the same pivot as the README's every-transfer
--           demo with a LIMIT bolted on.
-- EXPECT: 5 rows - the biggest transfer on the seed is Rs 47,910
--         (account 111 to 136, ref TR0000000010), then 45,820 / 43,730 /
--         43,319 / 41,229. Context: 30 transfers in all, averaging
--         Rs 25,160.50, so the top five all sit well above the mean.
--         (The GROUP BY includes amount because it is functionally
--         dependent on the pair - MySQL-legal and honest under
--         ONLY_FULL_GROUP_BY.)
SELECT transfer_ref,
       MIN(CASE WHEN txn_type = 'transfer_out' THEN account_id END) AS from_account,
       MIN(CASE WHEN txn_type = 'transfer_in'  THEN account_id END) AS to_account,
       amount
FROM transactions
WHERE transfer_ref IS NOT NULL
GROUP BY transfer_ref, amount
ORDER BY amount DESC
LIMIT 5;

-- ===== [Q10] The recovery book — collected vs scheduled, by status =======
-- QUESTION: for each loan status, how much of the scheduled value has
--           actually been collected? The lending side's summary query and
--           the purest demonstration of D6 in the set - scheduled versus
--           collected are both derived from loan_payments at query time,
--           and the recovery percentage is computed, never stored. And
--           unlike Q7's overdue count it is date-stable: paid_date is
--           history, a fact that never changes, so the answer cannot
--           drift with the calendar.
-- EXPECT: 3 rows - active: 141 loans, 846 instalments, Rs 8,608,383.84
--         scheduled, Rs 8,441,565.84 collected, 98.1% recovery; closed:
--         48 / 288, Rs 571,654.08 / Rs 571,654.08, 100.0%; defaulted:
--         11 / 66, Rs 588,799.44 scheduled but only Rs 98,133.24
--         collected - 16.7%. The finding is the payload: the defaulted
--         book collected one-sixth of its scheduled value before default.
--         (Join rides the primary keys: loan_payments.loan_id is the FK
--         InnoDB indexes automatically; the grouping happens on the
--         loans side of that index.)
SELECT l.status,
       COUNT(DISTINCT l.loan_id)                                          AS loans,
       COUNT(*)                                                           AS instalments,
       SUM(lp.amount)                                                     AS scheduled_total,
       SUM(CASE WHEN lp.paid_date IS NOT NULL THEN lp.amount ELSE 0 END)  AS collected_total,
       ROUND(100 * SUM(CASE WHEN lp.paid_date IS NOT NULL THEN lp.amount ELSE 0 END)
             / SUM(lp.amount), 1)                                         AS recovery_pct
FROM loans l
JOIN loan_payments lp ON lp.loan_id = l.loan_id
GROUP BY l.status
ORDER BY l.status;

-- ============================================================================
--  NOTE: the three unique questions beyond the assignment (recursive CTE,
--  ranking window, Benford screen) live in queries/bonus_queries.sql and
--  are answered in docs/ANSWERS.md Part B; these three are the assigned
--  set's closing tranche, answered in docs/ANSWERS.md Part A.
-- ============================================================================
