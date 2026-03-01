-- Delete all customer and invoice data
DELETE FROM invoices;
DELETE FROM customers;
-- Optionally reset auto-increment counters
DELETE FROM sqlite_sequence WHERE name IN ('customers', 'invoices');