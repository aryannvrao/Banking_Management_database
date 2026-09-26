-- 1. Create and switch to your project database
CREATE DATABASE IF NOT EXISTS fincore_db;
USE fincore_db;

-- 2. Clean slate drops if re-running
DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS transfers;
DROP TABLE IF EXISTS cards;
DROP TABLE IF EXISTS beneficiaries;
DROP TABLE IF EXISTS loan_payments;
DROP TABLE IF EXISTS loans;
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS accounts;
DROP TABLE IF EXISTS employees;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS branches;

-- 3. Parent Tables
CREATE TABLE branches (
    branch_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    city VARCHAR(50) NOT NULL,
    ifsc_code VARCHAR(11) NOT NULL UNIQUE
);

CREATE TABLE customers (
    customer_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    dob DATE NOT NULL,
    phone VARCHAR(15) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    address TEXT NOT NULL
);

-- 4. Employee Hierarchy (Self-referencing)
CREATE TABLE employees (
    employee_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    branch_id INT NOT NULL,
    designation VARCHAR(50) NOT NULL,
    manager_id INT NULL,
    FOREIGN KEY (branch_id) REFERENCES branches(branch_id) ON DELETE RESTRICT,
    FOREIGN KEY (manager_id) REFERENCES employees(employee_id) ON DELETE SET NULL
);

-- 5. Core Banking Entities
CREATE TABLE accounts (
    account_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT NOT NULL,
    branch_id INT NOT NULL,
    account_type ENUM('savings', 'current', 'fixed_deposit') NOT NULL,
    balance DECIMAL(15, 2) NOT NULL DEFAULT 0.00 CHECK (balance >= 0.00),
    opened_on DATE NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE,
    FOREIGN KEY (branch_id) REFERENCES branches(branch_id) ON DELETE RESTRICT
);

CREATE TABLE transactions (
    txn_id INT PRIMARY KEY AUTO_INCREMENT,
    account_id INT NOT NULL,
    txn_type ENUM('deposit', 'withdrawal', 'transfer') NOT NULL,
    amount DECIMAL(15, 2) NOT NULL CHECK (amount > 0.00),
    txn_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (account_id) REFERENCES accounts(account_id) ON DELETE CASCADE
);

CREATE TABLE transfers (
    transfer_id INT PRIMARY KEY AUTO_INCREMENT,
    source_account_id INT NOT NULL,
    destination_account_id INT NOT NULL,
    amount DECIMAL(15, 2) NOT NULL CHECK (amount > 0.00),
    transfer_mode ENUM('NEFT', 'RTGS', 'IMPS', 'INTERNAL') NOT NULL DEFAULT 'INTERNAL',
    status ENUM('completed', 'failed', 'pending') NOT NULL DEFAULT 'completed',
    transfer_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (source_account_id) REFERENCES accounts(account_id) ON DELETE RESTRICT,
    FOREIGN KEY (destination_account_id) REFERENCES accounts(account_id) ON DELETE RESTRICT,
    CHECK (source_account_id <> destination_account_id)
);

CREATE TABLE loans (
    loan_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT NOT NULL,
    branch_id INT NOT NULL,
    loan_type VARCHAR(50) NOT NULL,
    principal DECIMAL(15, 2) NOT NULL CHECK (principal > 0.00),
    interest_rate DECIMAL(5, 2) NOT NULL CHECK (interest_rate >= 0.00),
    status ENUM('active', 'closed', 'defaulted') NOT NULL DEFAULT 'active',
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE,
    FOREIGN KEY (branch_id) REFERENCES branches(branch_id) ON DELETE RESTRICT
);

CREATE TABLE loan_payments (
    payment_id INT PRIMARY KEY AUTO_INCREMENT,
    loan_id INT NOT NULL,
    due_date DATE NOT NULL,
    paid_date DATE NULL,
    amount DECIMAL(15, 2) NOT NULL CHECK (amount > 0.00),
    FOREIGN KEY (loan_id) REFERENCES loans(loan_id) ON DELETE CASCADE
);

CREATE TABLE beneficiaries (
    beneficiary_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT NOT NULL,
    name VARCHAR(100) NOT NULL,
    account_no VARCHAR(20) NOT NULL,
    ifsc_code VARCHAR(11) NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE CASCADE
);

CREATE TABLE cards (
    card_id INT PRIMARY KEY AUTO_INCREMENT,
    account_id INT NOT NULL,
    card_type ENUM('debit', 'credit') NOT NULL,
    expiry_date DATE NOT NULL,
    status ENUM('active', 'blocked', 'expired') NOT NULL DEFAULT 'active',
    FOREIGN KEY (account_id) REFERENCES accounts(account_id) ON DELETE CASCADE
);

CREATE TABLE audit_logs (
    log_id INT PRIMARY KEY AUTO_INCREMENT,
    table_name VARCHAR(50) NOT NULL,
    action_type ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    record_id INT NOT NULL,
    performed_by_employee INT NULL,
    action_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    details TEXT NOT NULL,
    FOREIGN KEY (performed_by_employee) REFERENCES employees(employee_id) ON DELETE SET NULL
);