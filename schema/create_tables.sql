CREATE DATABASE IF NOT EXISTS fincore;
USE fincore;

-- Drop dependent tables first
DROP TABLE IF EXISTS cards;
DROP TABLE IF EXISTS beneficiaries;
DROP TABLE IF EXISTS loan_payments;
DROP TABLE IF EXISTS loans;
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS accounts;
DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS branches;

-- 1. branches (Independent)
CREATE TABLE branches (
    branch_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    city VARCHAR(50) NOT NULL,
    ifsc_code CHAR(11) NOT NULL,
    CONSTRAINT uq_branches_ifsc UNIQUE (ifsc_code)
);

-- 2. customers (Independent)
CREATE TABLE customers (
    customer_id INT PRIMARY KEY AUTO_INCREMENT,
    full_name VARCHAR(100) NOT NULL,
    dob DATE NOT NULL,
    phone VARCHAR(15) NOT NULL,
    email VARCHAR(100) NOT NULL,
    address VARCHAR(255) NOT NULL,
    CONSTRAINT uq_customers_phone UNIQUE (phone),
    CONSTRAINT uq_customers_email UNIQUE (email)
);

-- 3. employees (Manager hierarchy)
CREATE TABLE employees (
    employee_id INT PRIMARY KEY AUTO_INCREMENT,
    full_name VARCHAR(100) NOT NULL,
    branch_id INT NOT NULL,
    manager_id INT NULL,
    designation ENUM('Branch Manager', 'Assistant Manager', 'Loan Officer', 'Senior Teller', 'Customer Service Exec') NOT NULL,
    hire_date DATE NOT NULL,
    CONSTRAINT fk_emp_branch FOREIGN KEY (branch_id) REFERENCES branches(branch_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_emp_manager FOREIGN KEY (manager_id) REFERENCES employees(employee_id) ON DELETE SET NULL ON UPDATE CASCADE
);

-- 4. accounts (Core Operational Hub)
CREATE TABLE accounts (
    account_id INT PRIMARY KEY AUTO_INCREMENT,
    account_number VARCHAR(20) NOT NULL,
    customer_id INT NOT NULL,
    branch_id INT NOT NULL,
    account_type ENUM('savings', 'current', 'fixed_deposit') NOT NULL,
    balance DECIMAL(12, 2) NOT NULL DEFAULT 0.00,
    opened_on DATE NOT NULL,
    CONSTRAINT uq_accounts_number UNIQUE (account_number),
    CONSTRAINT fk_accounts_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_accounts_branch FOREIGN KEY (branch_id) REFERENCES branches(branch_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_accounts_balance CHECK (balance >= 0.00)
);

-- 5. transactions (Ledger with paired transfer_ref)
CREATE TABLE transactions (
    txn_id INT PRIMARY KEY AUTO_INCREMENT,
    account_id INT NOT NULL,
    txn_type ENUM('deposit', 'withdrawal', 'transfer_out', 'transfer_in') NOT NULL,
    amount DECIMAL(12, 2) NOT NULL,
    txn_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    transfer_ref CHAR(12) NULL,
    CONSTRAINT fk_txn_account FOREIGN KEY (account_id) REFERENCES accounts(account_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_txn_amount CHECK (amount > 0.00),
    CONSTRAINT chk_txn_transfer_pairing CHECK (
        (txn_type IN ('transfer_out', 'transfer_in') AND transfer_ref IS NOT NULL) OR
        (txn_type IN ('deposit', 'withdrawal') AND transfer_ref IS NULL)
    )
);

-- 6. loans (Lending)
CREATE TABLE loans (
    loan_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT NOT NULL,
    branch_id INT NOT NULL,
    loan_type ENUM('Home Loan', 'Vehicle Loan', 'Personal Loan', 'Education Loan', 'Business Loan') NOT NULL,
    principal DECIMAL(12, 2) NOT NULL,
    interest_rate DECIMAL(5, 2) NOT NULL,
    tenure_months INT NOT NULL,
    status ENUM('active', 'closed', 'defaulted') NOT NULL DEFAULT 'active',
    CONSTRAINT fk_loans_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_loans_branch FOREIGN KEY (branch_id) REFERENCES branches(branch_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_loans_principal CHECK (principal > 0.00),
    CONSTRAINT chk_loans_rate CHECK (interest_rate >= 0.00 AND interest_rate <= 100.00),
    CONSTRAINT chk_loans_tenure CHECK (tenure_months >= 1 AND tenure_months <= 360)
);

-- 7. loan_payments (EMI Instalments)
CREATE TABLE loan_payments (
    payment_id INT PRIMARY KEY AUTO_INCREMENT,
    loan_id INT NOT NULL,
    instalment_no INT NOT NULL,
    due_date DATE NOT NULL,
    paid_date DATE NULL,
    amount DECIMAL(12, 2) NOT NULL,
    CONSTRAINT uq_payment_instalment UNIQUE (loan_id, instalment_no),
    CONSTRAINT fk_payment_loan FOREIGN KEY (loan_id) REFERENCES loans(loan_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_payment_amount CHECK (amount > 0.00),
    CONSTRAINT chk_payment_dates CHECK (paid_date IS NULL OR paid_date >= due_date)
);

-- 8. beneficiaries (Payees)
CREATE TABLE beneficiaries (
    beneficiary_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    account_no VARCHAR(20) NOT NULL,
    ifsc_code CHAR(11) NOT NULL,
    added_on DATE NOT NULL,
    CONSTRAINT uq_beneficiary_per_customer UNIQUE (customer_id, account_no, ifsc_code),
    CONSTRAINT fk_ben_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE ON UPDATE CASCADE
);

-- 9. cards (Card credentials)
CREATE TABLE cards (
    card_id INT PRIMARY KEY AUTO_INCREMENT,
    account_id INT NOT NULL,
    card_type ENUM('debit', 'credit') NOT NULL,
    card_number CHAR(16) NOT NULL,
    expiry_date DATE NOT NULL,
    status ENUM('active', 'blocked', 'expired') NOT NULL DEFAULT 'active',
    issued_on DATE NOT NULL,
    CONSTRAINT uq_cards_number UNIQUE (card_number),
    CONSTRAINT fk_card_account FOREIGN KEY (account_id) REFERENCES accounts(account_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_cards_number CHECK (card_number REGEXP '^[0-9]{16}$')
);

-- Supporting indexes
CREATE INDEX idx_accounts_customer ON accounts(customer_id);
CREATE INDEX idx_transactions_account ON transactions(account_id);
CREATE INDEX idx_transactions_ref ON transactions(transfer_ref);
CREATE INDEX idx_loans_customer ON loans(customer_id);