-- =========================================================================
-- SQL Manual Migration: Laporan Keuangan Perusahaan
-- (Catatan Arus Kas, Outstanding Project, & Rincian Penanaman Modal/Hutang)
-- Database: MySQL / MariaDB (Aman dijalankan berulang kali)
-- =========================================================================

-- 1. Tambah kolom tagihan, potongan fee/pajak, netto, & status pelunasan pada tabel `projects`
ALTER TABLE `projects`
  ADD COLUMN IF NOT EXISTS `invoice_number` VARCHAR(50) NULL AFTER `created_by`,
  ADD COLUMN IF NOT EXISTS `billing_amount` BIGINT NOT NULL DEFAULT 0 AFTER `target_budget`,
  ADD COLUMN IF NOT EXISTS `fee_management_percent` DECIMAL(5,2) NOT NULL DEFAULT 0 AFTER `billing_amount`,
  ADD COLUMN IF NOT EXISTS `fee_management` BIGINT NOT NULL DEFAULT 0 AFTER `fee_management_percent`,
  ADD COLUMN IF NOT EXISTS `ppn_percent` DECIMAL(5,2) NOT NULL DEFAULT 0 AFTER `fee_management`,
  ADD COLUMN IF NOT EXISTS `ppn_amount` BIGINT NOT NULL DEFAULT 0 AFTER `ppn_percent`,
  ADD COLUMN IF NOT EXISTS `pph_percent` DECIMAL(5,2) NOT NULL DEFAULT 0 AFTER `ppn_amount`,
  ADD COLUMN IF NOT EXISTS `pph_amount` BIGINT NOT NULL DEFAULT 0 AFTER `pph_percent`,
  ADD COLUMN IF NOT EXISTS `netto_amount` BIGINT NOT NULL DEFAULT 0 AFTER `pph_amount`,
  ADD COLUMN IF NOT EXISTS `payment_status` ENUM('unpaid', 'paid') NOT NULL DEFAULT 'unpaid' AFTER `netto_amount`;

-- 2. Tambah kolom nomor invoice pada tabel `transactions` untuk Catatan Arus Kas Perusahaan
ALTER TABLE `transactions`
  ADD COLUMN IF NOT EXISTS `invoice_number` VARCHAR(50) NULL AFTER `project_id`;

-- 3. Tambah kolom tanggal terbit invoice pada tabel `debts` untuk Rincian Penanaman Modal (Hutang)
ALTER TABLE `debts`
  ADD COLUMN IF NOT EXISTS `invoice_date` DATE NULL AFTER `installments_count`;
