USE fincore;


-- ============================================================
-- TC01: Find all customers who have at least one bank account.
-- JOIN connects customers with the accounts they own.
-- ============================================================

SELECT DISTINCT
    c.customer_id,
    c.full_name,
    a.account_number,
    a.account_type,
    a.balance
FROM customers c
JOIN accounts a
    ON c.customer_id = a.customer_id;


-- ============================================================
-- TC02: Find customers who have more than one bank account.
-- GROUP BY groups accounts customer-wise.
-- HAVING keeps only customers with more than 1 account.
-- ============================================================

SELECT
    c.customer_id,
    c.full_name,
    COUNT(a.account_id) AS account_count
FROM customers c
JOIN accounts a
    ON c.customer_id = a.customer_id
GROUP BY c.customer_id, c.full_name
HAVING COUNT(a.account_id) > 1;


-- ============================================================
-- TC03: Calculate the total balance held by each customer.
-- SUM adds the balances of all accounts belonging to each customer.
-- ============================================================

SELECT
    c.customer_id,
    c.full_name,
    SUM(a.balance) AS total_balance
FROM customers c
JOIN accounts a
    ON c.customer_id = a.customer_id
GROUP BY c.customer_id, c.full_name;


-- ============================================================
-- TC04: Find accounts whose balance is greater than
-- the average balance of all accounts.
-- The subquery calculates the average balance.
-- ============================================================

SELECT
    account_id,
    account_number,
    balance
FROM accounts
WHERE balance > (
    SELECT AVG(balance)
    FROM accounts
);


-- ============================================================
-- TC05: Calculate the total account balance for each branch.
-- SUM adds all account balances belonging to each branch.
-- ORDER BY shows the branches from highest to lowest balance.
-- ============================================================

SELECT
    b.branch_id,
    b.name AS branch_name,
    SUM(a.balance) AS total_balance
FROM branches b
JOIN accounts a
    ON b.branch_id = a.branch_id
GROUP BY b.branch_id, b.name
ORDER BY total_balance DESC;


-- ============================================================
-- TC06: Find customers who have BOTH a savings account
-- and a current account.
-- COUNT(DISTINCT) checks for both account types.
-- ============================================================

SELECT
    c.customer_id,
    c.full_name
FROM customers c
JOIN accounts a
    ON c.customer_id = a.customer_id
WHERE a.account_type IN ('savings', 'current')
GROUP BY c.customer_id, c.full_name
HAVING COUNT(DISTINCT a.account_type) = 2;


-- ============================================================
-- TC07: Find accounts that have BOTH a debit card
-- and a credit card.
-- ============================================================

SELECT
    a.account_id,
    a.account_number
FROM accounts a
JOIN cards c
    ON a.account_id = c.account_id
GROUP BY a.account_id, a.account_number
HAVING COUNT(DISTINCT c.card_type) = 2;


-- ============================================================
-- TC08: Find blocked cards belonging to accounts
-- whose balance is greater than ₹50,000.
-- ============================================================

SELECT
    c.card_id,
    c.card_number,
    a.account_number,
    a.balance
FROM cards c
JOIN accounts a
    ON c.account_id = a.account_id
WHERE c.status = 'blocked'
  AND a.balance > 50000;


-- ============================================================
-- TC09: Find cards whose expiry date has already passed.
-- CURRENT_DATE gives today's date.
-- ============================================================

SELECT
    card_id,
    card_number,
    expiry_date,
    status
FROM cards
WHERE expiry_date < CURRENT_DATE;


-- ============================================================
-- TC10: Display employees together with their managers.
-- This uses a SELF JOIN because employees and managers
-- are stored in the same employees table.
-- ============================================================

SELECT
    e.employee_id,
    e.full_name AS employee_name,
    m.employee_id AS manager_id,
    m.full_name AS manager_name
FROM employees e
JOIN employees m
    ON e.manager_id = m.employee_id;


-- ============================================================
-- TC11: Test the INSERT self-manager trigger.
-- Attempts to create an employee whose manager_id
-- is the same as their own employee_id.
-- EXPECTED RESULT: ERROR.
-- ============================================================

INSERT INTO employees
(employee_id, full_name, branch_id,
 designation, manager_id, hire_date)
VALUES
(2001, 'Test Employee', 1,
 'manager', 2001, '2026-09-01');


-- ============================================================
-- TC12: Test the UPDATE self-manager trigger.
-- Attempts to change an employee's manager_id
-- to their own employee_id.
-- EXPECTED RESULT: ERROR.
-- ============================================================

UPDATE employees
SET manager_id = employee_id
WHERE employee_id = 1003;


-- ============================================================
-- TC13: Find branches that have accounts, employees,
-- and loans.
-- COUNT counts the number of each item in every branch.
-- ============================================================

SELECT
    b.branch_id,
    b.name,
    COUNT(DISTINCT a.account_id) AS accounts,
    COUNT(DISTINCT e.employee_id) AS employees,
    COUNT(DISTINCT l.loan_id) AS loans
FROM branches b
JOIN accounts a
    ON b.branch_id = a.branch_id
JOIN employees e
    ON b.branch_id = e.branch_id
JOIN loans l
    ON b.branch_id = l.branch_id
GROUP BY b.branch_id, b.name;


-- ============================================================
-- TC14: Find customers whose account branch is different
-- from the branch where their loan was issued.
-- ============================================================

SELECT DISTINCT
    c.customer_id,
    c.full_name,
    a.branch_id AS account_branch,
    l.branch_id AS loan_branch
FROM customers c
JOIN accounts a
    ON c.customer_id = a.customer_id
JOIN loans l
    ON c.customer_id = l.customer_id
WHERE a.branch_id <> l.branch_id;


-- ============================================================
-- TC15: Find early EMI payments.
-- An early payment means the paid_date is BEFORE the due_date.
-- ============================================================

SELECT
    payment_id,
    loan_id,
    instalment_no,
    due_date,
    paid_date,
    amount
FROM loan_payments
WHERE paid_date IS NOT NULL
  AND paid_date < due_date;


-- ============================================================
-- TC16: Find overdue and unpaid loan instalments.
-- An instalment is overdue when:
-- 1. It has not been paid (paid_date IS NULL)
-- 2. Its due date has already passed.
-- ============================================================

SELECT
    payment_id,
    loan_id,
    instalment_no,
    due_date,
    paid_date,
    amount
FROM loan_payments
WHERE paid_date IS NULL
  AND due_date < CURRENT_DATE;


-- ============================================================
-- TC17: Find active loans that have at least one
-- unpaid instalment.
-- ============================================================

SELECT DISTINCT
    l.loan_id,
    l.customer_id,
    l.loan_type,
    l.principal,
    l.status
FROM loans l
JOIN loan_payments lp
    ON l.loan_id = lp.loan_id
WHERE l.status = 'active'
  AND lp.paid_date IS NULL;


-- ============================================================
-- TC18: Find customers who have more than one beneficiary.
-- COUNT counts how many beneficiaries each customer has.
-- ============================================================

SELECT
    c.customer_id,
    c.full_name,
    COUNT(b.beneficiary_id) AS beneficiary_count
FROM customers c
JOIN beneficiaries b
    ON c.customer_id = b.customer_id
GROUP BY c.customer_id, c.full_name
HAVING COUNT(b.beneficiary_id) > 1;


-- ============================================================
-- TC19: Verify complete account-to-account transfers.
-- A complete transfer should contain:
-- 1 transfer_out row
-- 1 transfer_in row
-- Both should have the same transfer reference
-- Both amounts should be equal.
-- ============================================================

SELECT
    transfer_ref,
    COUNT(*) AS row_count,

    SUM(
        CASE
            WHEN txn_type = 'transfer_out' THEN 1
            ELSE 0
        END
    ) AS transfer_out_count,

    SUM(
        CASE
            WHEN txn_type = 'transfer_in' THEN 1
            ELSE 0
        END
    ) AS transfer_in_count,

    SUM(
        CASE
            WHEN txn_type = 'transfer_out' THEN amount
            ELSE 0
        END
    ) AS outgoing_amount,

    SUM(
        CASE
            WHEN txn_type = 'transfer_in' THEN amount
            ELSE 0
        END
    ) AS incoming_amount

FROM transactions
WHERE transfer_ref IS NOT NULL
GROUP BY transfer_ref
HAVING row_count = 2
   AND transfer_out_count = 1
   AND transfer_in_count = 1
   AND outgoing_amount = incoming_amount;


-- ============================================================
-- TC20: Find all transactions within a specific date range.
-- BETWEEN selects transactions from September 1 to September 30.
-- ============================================================

SELECT
    txn_id,
    account_id,
    txn_type,
    amount,
    txn_date
FROM transactions
WHERE txn_date BETWEEN '2026-09-01 00:00:00'
                   AND '2026-09-30 23:59:59'
ORDER BY txn_date;
