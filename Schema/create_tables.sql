-- ============================================================================
--  FinCore - Banking and Transaction Management System
--  File      : schema/create_tables.sql
--  Target    : MySQL 8.0.16+ (InnoDB engine - required for FOREIGN KEY
--              support; CHECK constraints are enforced only from 8.0.16)
--  Team      : Team 3, DBMS Course Project, Atria University
--  Author    : Aryan Rao (AU25UG-006) - database design & DDL
--  Purpose   : Creates the database, all 9 tables, integrity constraints,
--              supporting indexes and 2 triggers, in dependency-safe order.
--
--  CHANGELOG
--    v2.1 2026-09-27  implementation fix (Siva - caught while bringing v2 up
--          on MySQL; reviewed and signed off by Aryan):
--      - MOVED chk_emp_not_own_manager from a CHECK constraint to two
--        TRIGGERS (trg_emp_not_own_manager_ins / _upd). MySQL 8 forbids a
--        CHECK on any column used in a foreign key referential action
--        (ERROR 3823 on manager_id / fk_emp_manager - see the manual,
--        "CHECK Constraints" limitations). Same rule, same name kept in
--        the error message; a violation now fails with ERROR 1644
--        (SIGNAL SQLSTATE '45000') instead of 3819.
--      - Named constraints: 35 -> 34 (PK 9 + FK 10 + UNIQUE 7 + CHECK 8),
--        plus the 2 triggers. Cascaded FK actions never activate triggers
--        (manual, CREATE TRIGGER), which is safe here: the only cascade
--        touching manager_id sets it to NULL.
--    v2  2026-09-27  design-review fixes (Aryan, after Amruta's review):
--      - REMOVED chk_payment_dates (loan_payments): it rejected valid EARLY
--        EMI payments. paid_date may legitimately fall before due_date.
--      - REMOVED idx_accounts_customer: a pure duplicate of the index InnoDB
--        creates automatically for fk_accounts_customer.
--      - ADDED idempotent teardown (DROP TABLE IF EXISTS, reverse order).
--    v1              initial release, cross-checked by Amruta
--
--  HOW TO RUN
--    mysql -u root -p < schema/create_tables.sql
--    (or open in MySQL Workbench and execute the whole script)
--
--  DESIGN DECISIONS ENCODED IN THIS FILE (full reasoning in the design report)
--    D1. Surrogate primary keys (AUTO_INCREMENT) everywhere, with business
--        keys (ifsc_code, email, card_number, account_number) as UNIQUE.
--    D2. Transfers are stored as TWO paired rows in `transactions`
--        (transfer_out + transfer_in) sharing one transfer_ref.
--    D3. `beneficiaries` deliberately has NO foreign key on account_no /
--        ifsc_code - payees may hold accounts at OTHER banks.
--    D4. Referential actions differ per relationship on purpose:
--        - transactions -> accounts      RESTRICT  (audit trail never dies)
--        - cards -> accounts             CASCADE   (card is useless alone)
--        - employees.manager_id -> emp   SET NULL  (staff survive a manager
--                                                   leaving)
--    D5. Money is always DECIMAL(12,2) - FLOAT/DOUBLE cause rounding errors.
--    D6. Time-dependent truths (e.g. "overdue") are NOT stored - they are
--        derived in queries, so the data can never contradict itself.
-- ============================================================================

CREATE DATABASE IF NOT EXISTS fincore
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;
USE fincore;

-- ============================================================================
--  IDEMPOTENT TEARDOWN - re-running the whole script from scratch always
--  works. Children first, parents last (reverse of the creation order).
-- ============================================================================
DROP TABLE IF EXISTS cards;
DROP TABLE IF EXISTS beneficiaries;
DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS loan_payments;
DROP TABLE IF EXISTS loans;
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS accounts;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS branches;

-- ============================================================================
--  TABLE 1: branches  (parent table - no foreign keys)
--  WHY FIRST : customers, accounts, loans and employees all reference it.
-- ============================================================================
CREATE TABLE branches (
    branch_id   INT           NOT NULL AUTO_INCREMENT,
    name        VARCHAR(100)  NOT NULL,
    city        VARCHAR(50)   NOT NULL,
    ifsc_code   CHAR(11)      NOT NULL,
    -- ifsc_code is the business-facing identifier of an Indian bank branch;
    -- it must be globally unique, so we back the surrogate key with UNIQUE.
    CONSTRAINT pk_branches             PRIMARY KEY (branch_id),
    CONSTRAINT uq_branches_ifsc        UNIQUE (ifsc_code)
) ENGINE = InnoDB;

-- ============================================================================
--  TABLE 2: customers  (parent table - no foreign keys)
--  KYC fields (name, dob, phone, email, address) identify a real person.
-- ============================================================================
CREATE TABLE customers (
    customer_id INT           NOT NULL AUTO_INCREMENT,
    full_name   VARCHAR(100)  NOT NULL,
    dob         DATE          NOT NULL,
    phone       VARCHAR(15)   NOT NULL,
    email       VARCHAR(100)  NOT NULL,
    address     VARCHAR(255)  NOT NULL,
    -- NOTE: a CHECK like (dob < CURDATE()) is ILLEGAL in MySQL - CHECK
    -- constraints may not call non-deterministic functions. Future-date
    -- validation is therefore an application-layer responsibility.
    -- (Deliberate, documented limitation - a good viva discussion point.)
    CONSTRAINT pk_customers            PRIMARY KEY (customer_id),
    CONSTRAINT uq_customers_phone      UNIQUE (phone),
    CONSTRAINT uq_customers_email      UNIQUE (email)
) ENGINE = InnoDB;

-- ============================================================================
--  TABLE 3: accounts  (the CORE table - links customers to branches)
-- ============================================================================
CREATE TABLE accounts (
    account_id     INT            NOT NULL AUTO_INCREMENT,
    account_number VARCHAR(20)    NOT NULL,
    customer_id    INT            NOT NULL,
    branch_id      INT            NOT NULL,
    account_type   ENUM('savings','current','fixed_deposit')
                                  NOT NULL,
    balance        DECIMAL(12,2)  NOT NULL DEFAULT 0.00,
    opened_on      DATE           NOT NULL,
    CONSTRAINT pk_accounts              PRIMARY KEY (account_id),
    -- account_number is the number printed on passbooks/statements; the
    -- surrogate account_id stays hidden inside the database.
    CONSTRAINT uq_accounts_number      UNIQUE (account_number),
    -- A customer may hold many accounts; an account belongs to exactly one
    -- customer in the base design (no joint accounts - see report §8).
    CONSTRAINT fk_accounts_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    -- Every account is serviced by exactly one branch.
    CONSTRAINT fk_accounts_branch
        FOREIGN KEY (branch_id) REFERENCES branches (branch_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    -- A branch with accounts cannot be deleted (RESTRICT); balances can
    -- never go negative.
    CONSTRAINT chk_accounts_balance    CHECK (balance >= 0)
) ENGINE = InnoDB;

-- ============================================================================
--  TABLE 4: transactions  (audit-trail table)
--  DESIGN D2 - the transfer solution:
--    A transfer of Rs 5,000 from account A to account B is stored as:
--      row 1: account_id = A, txn_type = 'transfer_out', amount = 5000,
--             transfer_ref = 'TR20260901X1'
--      row 2: account_id = B, txn_type = 'transfer_in',  amount = 5000,
--             transfer_ref = 'TR20260901X1'
--    Both rows share one transfer_ref, so a transfer is always either fully
--    visible or not visible at all, and per-account history stays intact.
-- ============================================================================
CREATE TABLE transactions (
    txn_id       INT            NOT NULL AUTO_INCREMENT,
    account_id   INT            NOT NULL,
    txn_type     ENUM('deposit','withdrawal','transfer_out','transfer_in')
                                 NOT NULL,
    amount       DECIMAL(12,2)  NOT NULL,
    txn_date     DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- NULL for plain deposits/withdrawals; NOT NULL for both halves of a
    -- transfer. The CHECK below enforces exactly that pairing.
    transfer_ref CHAR(12)       NULL,
    CONSTRAINT pk_transactions         PRIMARY KEY (txn_id),
    -- RESTRICT: financial history must never be destroyed by deleting an
    -- account. Closing an account is a status change, not a DELETE.
    CONSTRAINT fk_txn_account
        FOREIGN KEY (account_id) REFERENCES accounts (account_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_txn_amount          CHECK (amount > 0),
    -- Either it is a transfer (both halves carry the same ref) or it is a
    -- plain deposit/withdrawal (no ref allowed).
    CONSTRAINT chk_txn_transfer_pairing
        CHECK ( (txn_type IN ('transfer_out','transfer_in')) = (transfer_ref IS NOT NULL) )
) ENGINE = InnoDB;

-- ============================================================================
--  TABLE 5: loans
-- ============================================================================
CREATE TABLE loans (
    loan_id       INT            NOT NULL AUTO_INCREMENT,
    customer_id   INT            NOT NULL,
    branch_id     INT            NOT NULL,
    loan_type     ENUM('home','vehicle','personal','education')
                                 NOT NULL,
    principal     DECIMAL(12,2)  NOT NULL,
    interest_rate DECIMAL(5,2)   NOT NULL,
    tenure_months INT            NOT NULL,
    start_date    DATE           NOT NULL,
    status        ENUM('active','closed','defaulted')
                                 NOT NULL DEFAULT 'active',
    CONSTRAINT pk_loans              PRIMARY KEY (loan_id),
    CONSTRAINT fk_loans_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_loans_branch
        FOREIGN KEY (branch_id) REFERENCES branches (branch_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_loans_principal    CHECK (principal > 0),
    -- Annual percentage rate, sanity-bounded 0..100.
    CONSTRAINT chk_loans_rate         CHECK (interest_rate >= 0 AND interest_rate <= 100),
    -- Between 1 month and 30 years.
    CONSTRAINT chk_loans_tenure       CHECK (tenure_months BETWEEN 1 AND 360)
) ENGINE = InnoDB;

-- ============================================================================
--  TABLE 6: loan_payments  (EMI instalment schedule)
--  "Overdue" is NOT a stored column: a payment is overdue when
--  paid_date IS NULL AND due_date < CURRENT_DATE. Storing it would be
--  derived data that rots overnight (see report §5.6 / §7).
-- ============================================================================
CREATE TABLE loan_payments (
    payment_id    INT            NOT NULL AUTO_INCREMENT,
    loan_id       INT            NOT NULL,
    instalment_no INT            NOT NULL,
    due_date      DATE           NOT NULL,
    -- NULL = not paid yet. This single NULL is what powers business Q7.
    paid_date     DATE           NULL,
    amount        DECIMAL(12,2)  NOT NULL,
    CONSTRAINT pk_loan_payments      PRIMARY KEY (payment_id),
    -- A loan has instalments 1..N; the pair (loan_id, instalment_no) is a
    -- natural alternate key that prevents duplicated instalments.
    CONSTRAINT uq_payment_instalment UNIQUE (loan_id, instalment_no),
    -- CASCADE: the schedule belongs to the loan record and is meaningless
    -- without it (contrast with transactions, which are RESTRICTed).
    CONSTRAINT fk_payment_loan
        FOREIGN KEY (loan_id) REFERENCES loans (loan_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_payment_amount     CHECK (amount > 0)
    -- v2 NOTE: there is deliberately NO check comparing paid_date with
    -- due_date. v1's chk_payment_dates (paid_date >= due_date) wrongly
    -- rejected EARLY payments; paying an EMI before its due date is normal
    -- banking and must stay insertable (early / on-time / late are all
    -- legitimate values of paid_date).
) ENGINE = InnoDB;

-- ============================================================================
--  TABLE 7: employees  (branch staff, recursive reporting line)
-- ============================================================================
CREATE TABLE employees (
    employee_id  INT           NOT NULL AUTO_INCREMENT,
    full_name    VARCHAR(100)  NOT NULL,
    branch_id    INT           NOT NULL,
    designation  ENUM('manager','loan_officer','teller','cashier')
                                NOT NULL,
    manager_id   INT           NULL,
    hire_date    DATE          NOT NULL,
    CONSTRAINT pk_employees           PRIMARY KEY (employee_id),
    CONSTRAINT fk_emp_branch
        FOREIGN KEY (branch_id) REFERENCES branches (branch_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    -- SELF-REFERENCING foreign key: an employee reports to another
    -- employee. SET NULL: if a manager's record is removed, subordinates
    -- are re-assigned/unassigned rather than deleted.
    -- v2.1: "nobody manages themselves" is NOT a CHECK here - MySQL 8
    -- rejects a CHECK on a column used in an FK referential action
    -- (ERROR 3823). The rule is enforced by two triggers at the end of
    -- this file (trg_emp_not_own_manager_ins / _upd).
    CONSTRAINT fk_emp_manager
        FOREIGN KEY (manager_id) REFERENCES employees (employee_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB;

-- ============================================================================
--  TABLE 8: beneficiaries  (payees registered by a customer)
--  DESIGN D3: account_no and ifsc_code are deliberately PLAIN COLUMNS, not
--  foreign keys - a registered payee usually banks ELSEWHERE. A FK could
--  only reference accounts that exist in OUR bank.
-- ============================================================================
CREATE TABLE beneficiaries (
    beneficiary_id INT           NOT NULL AUTO_INCREMENT,
    customer_id    INT           NOT NULL,
    name           VARCHAR(100)  NOT NULL,
    account_no     VARCHAR(20)   NOT NULL,
    ifsc_code      CHAR(11)      NOT NULL,
    added_on       DATE          NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT pk_beneficiaries        PRIMARY KEY (beneficiary_id),
    -- The same customer must not register the same payee twice.
    CONSTRAINT uq_beneficiary_per_customer UNIQUE (customer_id, account_no, ifsc_code),
    -- CASCADE: a payee list is personal data owned by the customer and is
    -- removed with the customer (right-to-be-forgotten style cleanup).
    CONSTRAINT fk_ben_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB;

-- ============================================================================
--  TABLE 9: cards  (debit/credit cards linked to accounts)
-- ============================================================================
CREATE TABLE cards (
    card_id     INT           NOT NULL AUTO_INCREMENT,
    account_id  INT           NOT NULL,
    card_number CHAR(16)      NOT NULL,
    card_type   ENUM('debit','credit') NOT NULL,
    expiry_date DATE          NOT NULL,
    status      ENUM('active','blocked','expired')
                              NOT NULL DEFAULT 'active',
    issued_on   DATE          NOT NULL,
    CONSTRAINT pk_cards             PRIMARY KEY (card_id),
    CONSTRAINT uq_cards_number      UNIQUE (card_number),
    -- CASCADE: a card is an access token to an account; it is meaningless
    -- once the account is gone (contrast with transactions -> RESTRICT).
    CONSTRAINT fk_card_account
        FOREIGN KEY (account_id) REFERENCES accounts (account_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    -- Simple PAN-format sanity check (16 digits).
    CONSTRAINT chk_cards_number
        CHECK (card_number REGEXP '^[0-9]{16}$')
) ENGINE = InnoDB;

-- ============================================================================
--  SUPPORTING INDEXES (beyond the automatic FK indexes)
--  Reasoning: each index backs one of the business questions - a query that
--  filters or groups on a column should not force a full table scan.
--
--  DO NOT ADD INDEXES ON FOREIGN-KEY COLUMNS. InnoDB creates one
--  automatically for every FOREIGN KEY (accounts.customer_id,
--  transactions.account_id, loans.customer_id, ...), so an explicit index
--  there would be a pure duplicate - v2 removed idx_accounts_customer for
--  exactly that reason. Only non-FK query columns are indexed below.
-- ============================================================================
-- Q7: WHERE paid_date IS NULL AND due_date < CURRENT_DATE.
CREATE INDEX idx_payment_due  ON loan_payments (due_date);
-- Q6: WHERE status = 'active'.
CREATE INDEX idx_loan_status  ON loans (status);
-- Date-range reporting on transactions.
CREATE INDEX idx_txn_date     ON transactions (txn_date);

-- ============================================================================
--  TRIGGERS  (v2.1): chk_emp_not_own_manager
--  Rule: nobody manages themselves. This was a CHECK constraint in v2, but
--  MySQL 8 rejects a CHECK on any column used in a foreign key referential
--  action (ERROR 3823) - and manager_id is the ON DELETE SET NULL /
--  ON UPDATE CASCADE column of fk_emp_manager. So the same rule is enforced
--  by these two triggers; a violation fails with ERROR 1644, and the rule
--  name is kept in the message so the docs still cross-reference.
--  Coverage notes:
--    - BEFORE INSERT + BEFORE UPDATE covers every write path (REPLACE,
--      LOAD DATA and multi-row inserts all fire row triggers).
--    - Cascaded FK actions do NOT activate triggers (MySQL manual,
--      CREATE TRIGGER) - and the only cascade touching manager_id sets it
--      to NULL, which can never be self-management. No coverage gap.
--    - Idempotent: DROP TRIGGER IF EXISTS, then CREATE.
--  NOTE: the DELIMITER lines are mysql-CLI / Workbench client commands
--  (needed because the trigger bodies contain ';'). They must each sit on
--  their own line.
-- ============================================================================
DROP TRIGGER IF EXISTS trg_emp_not_own_manager_ins;
DROP TRIGGER IF EXISTS trg_emp_not_own_manager_upd;

DELIMITER $$

CREATE TRIGGER trg_emp_not_own_manager_ins
BEFORE INSERT ON employees
FOR EACH ROW
BEGIN
    IF NEW.manager_id IS NOT NULL AND NEW.manager_id = NEW.employee_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'chk_emp_not_own_manager: nobody can manage themselves';
    END IF;
END$$

CREATE TRIGGER trg_emp_not_own_manager_upd
BEFORE UPDATE ON employees
FOR EACH ROW
BEGIN
    IF NEW.manager_id IS NOT NULL AND NEW.manager_id = NEW.employee_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'chk_emp_not_own_manager: nobody can manage themselves';
    END IF;
END$$

DELIMITER ;

-- ============================================================================
--  VERIFICATION (uncomment to run after executing the script)
-- ============================================================================
-- SHOW TABLES;
-- SELECT TABLE_NAME, ENGINE FROM information_schema.TABLES
--   WHERE TABLE_SCHEMA = 'fincore';
-- SELECT TABLE_NAME, CONSTRAINT_NAME, CONSTRAINT_TYPE
--   FROM information_schema.TABLE_CONSTRAINTS
--   WHERE TABLE_SCHEMA = 'fincore' ORDER BY TABLE_NAME;
