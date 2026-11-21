-- Database Schema for Personal & Family Finance Tracker
-- MySQL 5.7+ / 8.0+

CREATE DATABASE IF NOT EXISTS finance_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE finance_db;

-- 1. Families Table
CREATE TABLE IF NOT EXISTS families (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  invite_code VARCHAR(16) NOT NULL UNIQUE,
  created_by INT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 2. Companies Table
CREATE TABLE IF NOT EXISTS companies (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  invite_code VARCHAR(16) NOT NULL UNIQUE,
  created_by INT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 3. Users Table
CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(150) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role ENUM('user', 'admin') DEFAULT 'user',
  family_id INT NULL,
  company_id INT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (family_id) REFERENCES families(id) ON DELETE SET NULL,
  FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 4. Projects Table (Under Company)
CREATE TABLE IF NOT EXISTS projects (
  id INT AUTO_INCREMENT PRIMARY KEY,
  company_id INT NOT NULL,
  created_by INT NOT NULL,
  name VARCHAR(150) NOT NULL,
  description TEXT NULL,
  target_budget BIGINT NOT NULL DEFAULT 0,
  current_income BIGINT NOT NULL DEFAULT 0,
  current_expense BIGINT NOT NULL DEFAULT 0,
  status ENUM('active', 'completed', 'on_hold') DEFAULT 'active',
  start_date DATE NULL,
  end_date DATE NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE,
  FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 5. Wallets Table
CREATE TABLE IF NOT EXISTS wallets (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  family_id INT NULL,
  company_id INT NULL,
  name VARCHAR(100) NOT NULL,
  balance BIGINT NOT NULL DEFAULT 0,
  scope ENUM('personal', 'family', 'company') DEFAULT 'personal',
  is_active TINYINT(1) DEFAULT 1,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (family_id) REFERENCES families(id) ON DELETE SET NULL,
  FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 6. Categories Table
CREATE TABLE IF NOT EXISTS categories (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NULL,
  name VARCHAR(100) NOT NULL,
  type ENUM('income', 'expense') NOT NULL,
  color VARCHAR(20) DEFAULT '#10B981',
  icon VARCHAR(50) DEFAULT 'tag',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- 7. Savings (Goals / Vault) Table
CREATE TABLE IF NOT EXISTS savings (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  family_id INT NULL,
  goal_name VARCHAR(150) NOT NULL,
  target_amount BIGINT NOT NULL,
  current_amount BIGINT NOT NULL DEFAULT 0,
  target_date DATE NULL,
  scope ENUM('personal', 'family') DEFAULT 'personal',
  status ENUM('active', 'completed') DEFAULT 'active',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (family_id) REFERENCES families(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 8. Debts (Hutang & Piutang) Table
CREATE TABLE IF NOT EXISTS debts (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  family_id INT NULL,
  type ENUM('payable', 'receivable') NOT NULL,
  person_name VARCHAR(150) NOT NULL,
  total_amount BIGINT NOT NULL,
  remaining_amount BIGINT NOT NULL,
  due_date DATE NOT NULL,
  status ENUM('unpaid', 'partially_paid', 'paid', 'overdue') DEFAULT 'unpaid',
  scope ENUM('personal', 'family') DEFAULT 'personal',
  notes TEXT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (family_id) REFERENCES families(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 9. Transactions Table
CREATE TABLE IF NOT EXISTS transactions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  family_id INT NULL,
  company_id INT NULL,
  project_id INT NULL,
  wallet_id INT NOT NULL,
  category_id INT NULL,
  type ENUM('income', 'expense', 'transfer', 'saving_deposit', 'saving_withdrawal', 'debt_payment') NOT NULL,
  amount BIGINT NOT NULL,
  transaction_date DATE NOT NULL,
  notes TEXT NULL,
  destination_wallet_id INT NULL,
  destination_saving_id INT NULL,
  debt_id INT NULL,
  scope ENUM('personal', 'family', 'company') DEFAULT 'personal',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (family_id) REFERENCES families(id) ON DELETE SET NULL,
  FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE SET NULL,
  FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE SET NULL,
  FOREIGN KEY (wallet_id) REFERENCES wallets(id) ON DELETE CASCADE,
  FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL,
  FOREIGN KEY (destination_wallet_id) REFERENCES wallets(id) ON DELETE SET NULL,
  FOREIGN KEY (destination_saving_id) REFERENCES savings(id) ON DELETE SET NULL,
  FOREIGN KEY (debt_id) REFERENCES debts(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- Seed Admin User (admin@gmail.com / alvian14)
INSERT INTO users (id, name, email, password_hash, role, family_id)
VALUES (1, 'Admin Finance', 'admin@gmail.com', 'a1b2c3d4e5f67890:51bfa9b7929491be078f2da9091ab9351c8c19546d6b738e383b86f9e26d5d8792ea6f3fd4f9f88a1216cf1199b216f2781d6c87e2b337c6756565cd95b76e1e', 'admin', NULL)
ON DUPLICATE KEY UPDATE password_hash = VALUES(password_hash), role = 'admin';

-- Seed Default Wallet for Admin
INSERT INTO wallets (id, user_id, family_id, name, balance, scope, is_active)
VALUES (1, 1, NULL, 'Kas Utama Admin', 0, 'personal', 1)
ON DUPLICATE KEY UPDATE name = VALUES(name);

-- Seed Default Categories
INSERT INTO categories (id, user_id, name, type, color, icon) VALUES
(1, NULL, 'Gaji', 'income', '#10B981', 'briefcase'),
(2, NULL, 'Investasi & Usaha', 'income', '#059669', 'trending-up'),
(3, NULL, 'Makanan & Minuman', 'expense', '#EF4444', 'utensils'),
(4, NULL, 'Transportasi', 'expense', '#F59E0B', 'car'),
(5, NULL, 'Tagihan & Utilitas', 'expense', '#6366F1', 'receipt'),
(6, NULL, 'Belanja Kebutuhan', 'expense', '#EC4899', 'shopping-bag'),
(7, NULL, 'Kesehatan', 'expense', '#14B8A6', 'heart-pulse')
ON DUPLICATE KEY UPDATE name = VALUES(name);
