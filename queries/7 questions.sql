-- ============================================================================ --
-- Query 1: Which customers have multiple accounts? --
-- ============================================================================ --
use fincore;
SELECT c.customer_id,
       c.full_name,
       COUNT(a.account_id)              AS account_count,
       GROUP_CONCAT(a.account_number)  AS account_numbers
FROM   customers c
JOIN   accounts   a ON a.customer_id = c.customer_id
GROUP  BY c.customer_id, c.full_name
HAVING COUNT(a.account_id) > 1
ORDER  BY account_count DESC, c.customer_id;



-- ============================================================================ --
-- Query 2: Which branch manages the highest deposits? --
-- Concepts  : JOIN,SUM,ORDERBY,LIMIT --
-- ============================================================================ --
USE fincore;

SELECT
    b.branch_id,
    b.name AS branch_name,
    SUM(t.amount) AS total_deposits  
FROM branches b
JOIN accounts a
    ON b.branch_id = a.branch_id
JOIN transactions t
    ON a.account_id = t.account_id
WHERE t.txn_type = 'deposit'
GROUP BY b.branch_id, b.name
ORDER BY total_deposits DESC
LIMIT 1;  
-- ============================================================================ --
-- Query 3 : What is the average account balance by branch? --
-- Concepts: AVG, GROUP BY --
-- ============================================================================ --
SELECT 
    b.branch_id,
    b.name AS branch_name,
    AVG(a.balance) AS average_balance
FROM branches b
JOIN accounts a 
    ON b.branch_id = a.branch_id
GROUP BY b.branch_id, b.name;
-- ============================================================================ --
-- Q4 · Which customers have no transactions? --
-- Concepts:  A customer counts only if NONE of their --
-- accounts has ever transacted. --
-- ============================================================================ --

USE fincore;

SELECT
    c.customer_id,
    c.full_name
FROM customers c
LEFT JOIN accounts a
    ON c.customer_id = a.customer_id
LEFT JOIN transactions t
    ON a.account_id = t.account_id
WHERE t.txn_id IS NULL; 

-- ============================================================================ --
-- Q5 · Q5	Who are the customers with the highest total balances?	--
-- Concepts:  SUM across accounts, ranking them with dense_rank --
-- ============================================================================ --
use fincore;

select
    c.customer_id,
    c.full_name,
    COUNT(a.account_id) AS account_count,
    SUM(a.balance)      AS total_balance,
    dense_rank() over (ORDER BY SUM(a.balance) desc) AS balance_rank
from customers c
JOIN accounts a
    ON a.customer_id = c.customer_id
group by c.customer_id, c.full_name
order by total_balance desc
limit 5;


-- ============================================================================ --
-- Query 6 : Which customers have active loans? --
-- Concept: JOIN with WHERE status filter --
-- ============================================================================ --
SELECT 
    c.customer_id,
    c.full_name,
    l.loan_id,
    l.loan_type,
    l.principal
FROM customers c
JOIN loans l 
    ON c.customer_id = l.customer_id
WHERE l.status = 'active';
-- ============================================================================ --
-- Query 7:Which loan payments are overdue?  --
-- Concepts : Datecomparison,NULLhandling --
-- ============================================================================ --
USE fincore;

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
