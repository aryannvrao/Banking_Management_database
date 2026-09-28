-- ============================================================================
--  FinCore - Banking and Transaction Management System
--  File      : schema/create_tables.sql
--  Target    : MySQL 8.0.16+ (InnoDB)
--  Team      : Team 3, DBMS Course Project, Atria University
--  Author    : Aryan Rao (AU25UG-006) - Chief Architect
--
--  CHANGELOG
--    v2.1 2026-09-27 (Siva, implementation fix - reported for Aryan's
--          sign-off): chk_emp_not_own_manager moved from CHECK to TRIGGER.
--          MySQL 8 forbids a CHECK on any column used in a FOREIGN KEY
--          (ERROR 3823 on manager_id / fk_emp_manager). Same rule, enforced
--          by trigger, violation = ERROR 1644.
--    v2    design-review fixes: removed chk_payment_dates (early EMI must be
--          allowed), removed idx_accounts_customer (duplicate of FK index),
--          added idempotent teardown.
-- ============================================================================

CREATE DATABASE IF NOT EXISTS fincore
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;
USE fincore;

-- ============================================================================
--  IDEMPOTENT TEARDOWN - children first, parents last.
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
--  TABLE 1: branches
-- ============================================================================
CREATE TABLE branches (
    branch_id   INT           NOT NULL AUTO_INCREMENT,
    name        VARCHAR(100)  NOT NULL,
    city        VARCHAR(50)   NOT NULL,
    ifsc_code   CHAR(11)      NOT NULL,
    CONSTRAINT pk_branches             PRIMARY KEY (branch_id),
    CONSTRAINT uq_branches_ifsc        UNIQUE (ifsc_code)
) ENGINE = InnoDB;

-- ============================================================================
--  TABLE 2: customers
-- ============================================================================
CREATE TABLE customers (
    customer_id INT           NOT NULL AUTO_INCREMENT,
    full_name   VARCHAR(100)  NOT NULL,
    dob         DATE          NOT NULL,
    phone       VARCHAR(15)   NOT NULL,
    email       VARCHAR(100)  NOT NULL,
    address     VARCHAR(255)  NOT NULL,
    -- NOTE: CHECK (dob < CURDATE()) is illegal in MySQL - CHECK may not call
    -- non-deterministic functions. Documented limitation, application layer.
    CONSTRAINT pk_customers            PRIMARY KEY (customer_id),
    CONSTRAINT uq_customers_phone      UNIQUE (phone),
    CONSTRAINT uq_customers_email      UNIQUE (email)
) ENGINE = InnoDB;

-- ============================================================================
--  TABLE 3: accounts  (the CORE table)
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
    CONSTRAINT uq_accounts_number      UNIQUE (account_number),
    CONSTRAINT fk_accounts_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_accounts_branch
        FOREIGN KEY (branch_id) REFERENCES branches (branch_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_accounts_balance    CHECK (balance >= 0)
) ENGINE = InnoDB;

-- ============================================================================
--  TABLE 4: transactions  (audit trail; transfers = 2 paired rows, D2)
-- ============================================================================
CREATE TABLE transactions (
    txn_id       INT            NOT NULL AUTO_INCREMENT,
    account_id   INT            NOT NULL,
    txn_type     ENUM('deposit','withdrawal','transfer_out','transfer_in')
                                 NOT NULL,
    amount       DECIMAL(12,2)  NOT NULL,
    txn_date     DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    transfer_ref CHAR(12)       NULL,
    CONSTRAINT pk_transactions         PRIMARY KEY (txn_id),
    CONSTRAINT fk_txn_account
        FOREIGN KEY (account_id) REFERENCES accounts (account_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_txn_amount          CHECK (amount > 0),
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
    CONSTRAINT chk_loans_rate         CHECK (interest_rate >= 0 AND interest_rate <= 100),
    CONSTRAINT chk_loans_tenure       CHECK (tenure_months BETWEEN 1 AND 360)
) ENGINE = InnoDB;

-- ============================================================================
--  TABLE 6: loan_payments  (EMI schedule; overdue is derived, never stored)
-- ============================================================================
CREATE TABLE loan_payments (
    payment_id    INT            NOT NULL AUTO_INCREMENT,
    loan_id       INT            NOT NULL,
    instalment_no INT            NOT NULL,
    due_date      DATE           NOT NULL,
    paid_date     DATE           NULL,
    amount        DECIMAL(12,2)  NOT NULL,
    CONSTRAINT pk_loan_payments      PRIMARY KEY (payment_id),
    CONSTRAINT uq_payment_instalment UNIQUE (loan_id, instalment_no),
    CONSTRAINT fk_payment_loan
        FOREIGN KEY (loan_id) REFERENCES loans (loan_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_payment_amount     CHECK (amount > 0)
    -- v2 NOTE: no chk_payment_dates - early EMI payments are legitimate.
) ENGINE = InnoDB;

-- ============================================================================
--  TABLE 7: employees  (recursive reporting line)
--  v2.1: chk_emp_not_own_manager is enforced by TRIGGERS at the end of this
--  file, because MySQL 8 rejects a CHECK on a FOREIGN KEY column (ERROR 3823).
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
    CONSTRAINT fk_emp_manager
        FOREIGN KEY (manager_id) REFERENCES employees (employee_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB;

-- ============================================================================
--  TABLE 8: beneficiaries  (payees; NO FK on account_no/ifsc_code, D3)
-- ============================================================================
CREATE TABLE beneficiaries (
    beneficiary_id INT           NOT NULL AUTO_INCREMENT,
    customer_id    INT           NOT NULL,
    name           VARCHAR(100)  NOT NULL,
    account_no     VARCHAR(20)   NOT NULL,
    ifsc_code      CHAR(11)      NOT NULL,
    added_on       DATE          NOT NULL DEFAULT (CURRENT_DATE),
    CONSTRAINT pk_beneficiaries        PRIMARY KEY (beneficiary_id),
    CONSTRAINT uq_beneficiary_per_customer UNIQUE (customer_id, account_no, ifsc_code),
    CONSTRAINT fk_ben_customer
        FOREIGN KEY (customer_id) REFERENCES customers (customer_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB;

-- ============================================================================
--  TABLE 9: cards
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
    CONSTRAINT fk_card_account
        FOREIGN KEY (account_id) REFERENCES accounts (account_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_cards_number
        CHECK (card_number REGEXP '^[0-9]{16}$')
) ENGINE = InnoDB;

-- ============================================================================
--  SUPPORTING INDEXES (non-FK columns only, D10)
-- ============================================================================
CREATE INDEX idx_payment_due  ON loan_payments (due_date);
CREATE INDEX idx_loan_status  ON loans (status);
CREATE INDEX idx_txn_date     ON transactions (txn_date);

-- ============================================================================
--  TRIGGERS: chk_emp_not_own_manager (v2.1 - MySQL 3823 workaround)
--  Rule: nobody manages themselves. Violation fails with ERROR 1644.
-- ============================================================================
DROP TRIGGER IF EXISTS trg_emp_not_own_manager_ins;
DROP TRIGGER IF EXISTS trg_emp_not_own_manager_upd;

DELIMITER $$ CREATE TRIGGER trg_emp_not_own_manager_ins
BEFORE INSERT ON employees
FOR EACH ROW
BEGIN
  IF NEW.manager_id IS NOT NULL AND NEW.manager_id = NEW.employee_id THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'chk_emp_not_own_manager: nobody can manage themselves';
  END IF;
END$$ DELIMITER ;

DELIMITER $$ CREATE TRIGGER trg_emp_not_own_manager_upd
BEFORE UPDATE ON employees
FOR EACH ROW
BEGIN
  IF NEW.manager_id IS NOT NULL AND NEW.manager_id = NEW.employee_id THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'chk_emp_not_own_manager: nobody can manage themselves';
  END IF;
END$$ DELIMITER ;
