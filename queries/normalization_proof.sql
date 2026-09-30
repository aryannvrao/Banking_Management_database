-- ============================================================================
--  FinCore - Normalization, proven by execution
--  File    : queries/normalization_proof.sql
--  Target  : MySQL 8.0.16+ · run AFTER schema/create_tables.sql (DDL v2.1)
--            and data/insert_data.sql (seed v1.1)
--  Owner   : Aryan Rao (AU25UG-006)
--
--  docs/NORMALIZATION.md proves all nine relations are in BCNF (and argues
--  4NF / 5NF) by hand, FD by FD. This script is that same proof EXECUTED:
--  eleven checks, 1NF -> BCNF, each one a plain SELECT with its expected
--  result written next to it. The seed is deterministic, so a fresh run
--  reproduces every number below exactly. Screenshots of each result:
--  docs/screenshots/ (walked through in docs/NORMALIZATION.md section 9).
--
--  HOW TO RUN
--    mysql -u root -p < schema/create_tables.sql
--    mysql -u root -p < data/insert_data.sql
--    mysql -u root -p < queries/normalization_proof.sql
--    (or open in MySQL Workbench and execute block by block)
--
--  RESULTS AT A GLANCE
--    N1 - N2    1NF    atomic domains; repeating groups eliminated
--    N3 - N5    2NF    no composite PKs; both composite candidate keys
--                      tested on the data
--    N6 - N8    3NF    every fact has exactly one home; would-be
--                      transitive dependencies refuted on the data
--    N9 - N11   BCNF   every determinant is an enforced key; the FDs
--                      hold in the data; "looks unique" refuted
-- ============================================================================

USE fincore;

-- ===== [N1] 1NF · atomic domains =========================================
-- CLAIM: every one of the 57 attributes holds a single scalar value -
--        no SET (multi-valued) and no JSON (structured) columns exist.
-- EXPECT: total_columns = 57, non_atomic_columns = 0
SELECT COUNT(*) AS total_columns,
       SUM(DATA_TYPE IN ('set', 'json')) AS non_atomic_columns
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'fincore';

-- ===== [N2] 1NF · no repeating groups ====================================
-- CLAIM: the broken emi1_due / emi2_due / ... column pattern does not
--        exist; an instalment is one ROW, not one column pair. Any tenure
--        is just more rows (a 36-EMI loan would have needed 72 columns).
-- EXPECT: 6 rows - loan 1's schedule, one instalment per row
SELECT loan_id, instalment_no, due_date, amount
FROM loan_payments
WHERE loan_id = 1
ORDER BY instalment_no;

-- ===== [N3] 2NF · single-column primary keys =============================
-- CLAIM: no primary key is composite (decision D1), so no non-key column
--        can be dependent on PART of the PK - 2NF holds by construction.
-- EXPECT: 9 rows, pk_columns = 1 in every row
SELECT TABLE_NAME, COUNT(*) AS pk_columns
FROM information_schema.KEY_COLUMN_USAGE
WHERE TABLE_SCHEMA = 'fincore'
  AND CONSTRAINT_NAME = 'PRIMARY'
GROUP BY TABLE_NAME
ORDER BY TABLE_NAME;

-- ===== [N4] 2NF · composite candidate key tested: loan_payments ==========
-- CLAIM: loan_payments DOES have a composite candidate key (loan_id,
--        instalment_no). 2NF is tested on the data anyway: if due_date
--        were determined by HALF the key, one of these counts would be
--        nonzero (a whole schedule collapsing to one date).
-- EXPECT: 0 / 0 - neither half of the key determines the schedule
SELECT 'loan_id' AS part_of_key, COUNT(*) AS groups_with_constant_due_date
FROM (SELECT loan_id FROM loan_payments
      GROUP BY loan_id
      HAVING COUNT(DISTINCT due_date) = 1) x
UNION ALL
SELECT 'instalment_no', COUNT(*)
FROM (SELECT instalment_no FROM loan_payments
      GROUP BY instalment_no
      HAVING COUNT(DISTINCT due_date) = 1) y;

-- ===== [N5] 2NF · composite candidate key tested: beneficiaries ==========
-- CLAIM: beneficiaries' candidate key is (customer_id, account_no,
--        ifsc_code). If the payee name were a fact about customer_id
--        ALONE (part of the key), a customer's payees would all share
--        one name - a partial dependency. The data refutes it.
-- EXPECT: empty set - no customer's registered payees collapse to one name
SELECT customer_id, COUNT(*) AS payees_registered, COUNT(DISTINCT name) AS distinct_payee_names
FROM beneficiaries
GROUP BY customer_id
HAVING COUNT(*) > 1
   AND COUNT(DISTINCT name) = 1;

-- ===== [N6] 3NF · one home per fact ======================================
-- CLAIM: no table stores a second copy of another table's fact (the
--        transitive-dependency trap). The city of a branch lives in
--        branches - and nowhere else. (beneficiaries.ifsc_code is the
--        PAYEE'S bank, an outside-bank fact by design D3, not a copy of
--        any FinCore branch row.)
-- EXPECT: city appears in branches only; ifsc_code in branches and
--         beneficiaries
SELECT TABLE_NAME, COLUMN_NAME
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'fincore'
  AND COLUMN_NAME IN ('city', 'ifsc_code')
ORDER BY COLUMN_NAME, TABLE_NAME;

-- ===== [N7] 3NF · the update anomaly, measured ===========================
-- CLAIM: twelve accounts and eight loans depend on branch 1, yet its city
--        is stored in exactly ONE row - relocating the branch is a
--        one-row UPDATE. In the un-normalized lending_flat (NORMALIZATION
--        section 1) this was the update anomaly: same fact, many rows,
--        one missed edit and the data contradicts itself.
-- EXPECT: 1 / 12 / 8
SELECT (SELECT COUNT(*) FROM branches WHERE branch_id = 1) AS city_fact_rows,
       (SELECT COUNT(*) FROM accounts WHERE branch_id = 1) AS accounts_serviced,
       (SELECT COUNT(*) FROM loans   WHERE branch_id = 1) AS loans_booked;

-- ===== [N8] 3NF · would-be transitive dependencies, refuted =============
-- CLAIM: a 3NF violation needs a non-key column determining another
--        non-key column. The two plausible candidates are tested on the
--        data - designation does NOT determine an employee's branch, and
--        account_type determines neither customer nor branch. Every
--        value spans many parents, so no such FD exists.
-- EXPECT: each of the 4 designations spans 50 branches; each account
--         type spans many customers and many branches
SELECT designation, COUNT(*) AS staff, COUNT(DISTINCT branch_id) AS branches
FROM employees
GROUP BY designation
ORDER BY designation;

SELECT account_type, COUNT(*) AS accounts,
       COUNT(DISTINCT customer_id) AS customers,
       COUNT(DISTINCT branch_id)  AS branches
FROM accounts
GROUP BY account_type
ORDER BY account_type;

-- ===== [N9] BCNF · every determinant is an enforced key ==================
-- CLAIM: BCNF asks that every non-trivial determinant be a candidate key.
--        In this schema the determinants ARE the PK and UNIQUE columns -
--        and here is the engine's own inventory of them: 9 primary keys
--        + 7 UNIQUE keys, exactly the candidate keys of the section-5
--        proof table. The FDs and the constraints are the same statement
--        in two languages.
-- EXPECT: 16 rows - 9 PRIMARY KEY + 7 UNIQUE (2 of them composite)
SELECT kcu.TABLE_NAME,
       tc.CONSTRAINT_TYPE AS key_kind,
       tc.CONSTRAINT_NAME,
       GROUP_CONCAT(kcu.COLUMN_NAME ORDER BY kcu.ORDINAL_POSITION
                    SEPARATOR ', ') AS key_columns
FROM information_schema.TABLE_CONSTRAINTS tc
JOIN information_schema.KEY_COLUMN_USAGE kcu
  ON  kcu.CONSTRAINT_SCHEMA = tc.CONSTRAINT_SCHEMA
  AND kcu.TABLE_NAME        = tc.TABLE_NAME
  AND kcu.CONSTRAINT_NAME   = tc.CONSTRAINT_NAME
WHERE tc.CONSTRAINT_SCHEMA = 'fincore'
  AND tc.CONSTRAINT_TYPE IN ('PRIMARY KEY', 'UNIQUE')
GROUP BY kcu.TABLE_NAME, tc.CONSTRAINT_TYPE, tc.CONSTRAINT_NAME
ORDER BY kcu.TABLE_NAME, tc.CONSTRAINT_TYPE, tc.CONSTRAINT_NAME;

-- ===== [N10] BCNF · the FDs hold in the data =============================
-- CLAIM: every functional dependency claimed in the section-5 proof is
--        verified against the loaded data: each determinant below must
--        identify exactly one row (zero duplicate groups). One query,
--        seven determinants, one verdict.
-- EXPECT: 7 rows, duplicate_groups = 0 everywhere
SELECT 'branches.ifsc_code' AS determinant, COUNT(*) AS duplicate_groups
FROM (SELECT ifsc_code FROM branches GROUP BY ifsc_code HAVING COUNT(*) > 1) x
UNION ALL
SELECT 'customers.phone', COUNT(*)
FROM (SELECT phone FROM customers GROUP BY phone HAVING COUNT(*) > 1) x
UNION ALL
SELECT 'customers.email', COUNT(*)
FROM (SELECT email FROM customers GROUP BY email HAVING COUNT(*) > 1) x
UNION ALL
SELECT 'accounts.account_number', COUNT(*)
FROM (SELECT account_number FROM accounts GROUP BY account_number HAVING COUNT(*) > 1) x
UNION ALL
SELECT 'cards.card_number', COUNT(*)
FROM (SELECT card_number FROM cards GROUP BY card_number HAVING COUNT(*) > 1) x
UNION ALL
SELECT 'loan_payments.(loan_id, instalment_no)', COUNT(*)
FROM (SELECT loan_id, instalment_no FROM loan_payments
      GROUP BY loan_id, instalment_no HAVING COUNT(*) > 1) x
UNION ALL
SELECT 'beneficiaries.(customer_id, account_no, ifsc_code)', COUNT(*)
FROM (SELECT customer_id, account_no, ifsc_code FROM beneficiaries
      GROUP BY customer_id, account_no, ifsc_code HAVING COUNT(*) > 1) x;

-- ===== [N11] BCNF · "looks unique" is not a determinant ==================
-- CLAIM: full_name appears in three tables and determines NOTHING - names
--        are not identifiers, only enforced keys are determinants. The
--        seed draws customers and staff from the same 40 x 40 name pools,
--        so the same full name identifies both a customer and an employee
--        - proof by lived example.
-- EXPECT: 40 - names shared by a customer and an employee
SELECT COUNT(*) AS names_used_by_both_a_customer_and_an_employee
FROM (SELECT DISTINCT full_name FROM customers) c
JOIN (SELECT DISTINCT full_name FROM employees) e
  ON e.full_name = c.full_name;

-- ============================================================================
--  TWO HONEST NOTES (instance vs schema), for anyone probing further
--
--  1. The seed gives every instalment of a loan the same EMI amount, and
--     every product its typical flat rate (all home loans at 8.50%). Those
--     are properties of the DEMO DATA, not functional dependencies of the
--     relations: nothing in the schema constrains amount per instalment or
--     rate per product - a step-up EMI schedule or a negotiated 8.90% home
--     loan is perfectly insertable. "Looks determining in one instance" is
--     not an FD - the same argument as full_name in N11.
--  2. accounts.balance is stored, not derived - the ONE documented,
--     deliberate deviation (NORMALIZATION.md section 7), with its reason
--     written next to it.
-- ============================================================================
