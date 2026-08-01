-- ============================================================
-- Mobile read performance: server-side search + aggregation
-- Run once in Supabase SQL Editor. Safe to re-run.
-- Adds read-only views, indexes and one function.
-- Does NOT modify any existing table used by the desktop app.
-- ============================================================

-- ------------------------------------------------------------
-- 1) Trigram support so ILIKE '%term%' uses an index instead of
--    scanning every row on every keystroke.
-- ------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_products_search_trgm
    ON products USING GIN (
        lower(
            COALESCE(name, '') || ' ' ||
            COALESCE(barcode, '') || ' ' ||
            COALESCE(note, '') || ' ' ||
            COALESCE(brand, '') || ' ' ||
            COALESCE(category, '') || ' ' ||
            COALESCE(supplier, '')
        ) gin_trgm_ops
    );

CREATE INDEX IF NOT EXISTS idx_customers_search_trgm
    ON customers USING GIN (
        lower(
            COALESCE(name, '') || ' ' ||
            COALESCE(phone, '') || ' ' ||
            COALESCE(regexp_replace(COALESCE(phone, ''), '\D', '', 'g'), '') || ' ' ||
            COALESCE(address, '') || ' ' ||
            COALESCE(email, '')
        ) gin_trgm_ops
    );

-- ------------------------------------------------------------
-- 2) Products view: one searchable text column + low-stock flag,
--    so both filters run on the server.
-- ------------------------------------------------------------
DROP VIEW IF EXISTS mobile_products;
CREATE VIEW mobile_products
WITH (security_invoker = true) AS
SELECT
    p.id,
    p.name,
    p.barcode,
    p.quantity,
    p.price,
    p.cost_price,
    p.note,
    p.brand,
    p.category,
    p.supplier,
    p.supplier_id,
    p.min_stock,
    p.image_url,
    p.last_updated,
    (p.quantity <= COALESCE(p.min_stock, 5)) AS is_low_stock,
    lower(
        COALESCE(p.name, '') || ' ' ||
        COALESCE(p.barcode, '') || ' ' ||
        COALESCE(p.note, '') || ' ' ||
        COALESCE(p.brand, '') || ' ' ||
        COALESCE(p.category, '') || ' ' ||
        COALESCE(p.supplier, '')
    ) AS search_text
FROM products p;

-- ------------------------------------------------------------
-- 3) Customer balances aggregated in Postgres.
--    Replaces downloading every invoice + payment to the phone.
-- ------------------------------------------------------------
DROP VIEW IF EXISTS mobile_customer_balances;
CREATE VIEW mobile_customer_balances
WITH (security_invoker = true) AS
SELECT
    c.id,
    c.name,
    c.phone,
    c.email,
    c.address,
    c.created_date,
    COALESCE(c.balance_adjustment, 0) AS balance_adjustment,
    COALESCE(i.total, 0)
        - COALESCE(p.total, 0)
        + COALESCE(c.balance_adjustment, 0) AS balance,
    lower(
        COALESCE(c.name, '') || ' ' ||
        COALESCE(c.phone, '') || ' ' ||
        COALESCE(regexp_replace(COALESCE(c.phone, ''), '\D', '', 'g'), '') || ' ' ||
        COALESCE(c.address, '') || ' ' ||
        COALESCE(c.email, '')
    ) AS search_text
FROM customers c
LEFT JOIN (
    SELECT customer_id, SUM(final_amount) AS total
    FROM invoices
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
) i ON i.customer_id = c.id
LEFT JOIN (
    SELECT customer_id, SUM(amount) AS total
    FROM customer_payments
    GROUP BY customer_id
) p ON p.customer_id = c.id;

-- ------------------------------------------------------------
-- 4) Opening balance for a statement, computed server-side.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION mobile_customer_balance_before(
    p_customer_id BIGINT,
    p_before DATE
)
RETURNS DOUBLE PRECISION
LANGUAGE sql
STABLE
SECURITY INVOKER
AS $$
    SELECT
        COALESCE((
            SELECT SUM(final_amount) FROM invoices
            WHERE customer_id = p_customer_id
              AND COALESCE(sale_date, created_date)::date < p_before
        ), 0)
        - COALESCE((
            SELECT SUM(amount) FROM customer_payments
            WHERE customer_id = p_customer_id
              AND payment_date::date < p_before
        ), 0)
        + COALESCE((
            SELECT balance_adjustment FROM customers
            WHERE id = p_customer_id
              AND COALESCE(created_date, '2000-01-01'::timestamptz)::date < p_before
        ), 0);
$$;

-- ------------------------------------------------------------
-- 5) Expose to the app roles.
-- ------------------------------------------------------------
GRANT SELECT ON mobile_products TO anon, authenticated;
GRANT SELECT ON mobile_customer_balances TO anon, authenticated;
GRANT EXECUTE ON FUNCTION mobile_customer_balance_before(BIGINT, DATE)
    TO anon, authenticated;

NOTIFY pgrst, 'reload schema';

SELECT 'Mobile performance objects created' AS status;
