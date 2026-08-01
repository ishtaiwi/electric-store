-- ============================================================
-- Product images: column + Supabase Storage bucket
-- Run once in: Supabase Dashboard → SQL Editor
-- Safe to re-run.
-- ============================================================

ALTER TABLE products ADD COLUMN IF NOT EXISTS image_url TEXT;

-- Public bucket for product photos
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'product-images',
  'product-images',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Storage policies (anon key used by desktop + mobile apps)
DROP POLICY IF EXISTS "product_images_select" ON storage.objects;
DROP POLICY IF EXISTS "product_images_insert" ON storage.objects;
DROP POLICY IF EXISTS "product_images_update" ON storage.objects;
DROP POLICY IF EXISTS "product_images_delete" ON storage.objects;

CREATE POLICY "product_images_select"
ON storage.objects FOR SELECT
TO anon, authenticated
USING (bucket_id = 'product-images');

CREATE POLICY "product_images_insert"
ON storage.objects FOR INSERT
TO anon, authenticated
WITH CHECK (bucket_id = 'product-images');

CREATE POLICY "product_images_update"
ON storage.objects FOR UPDATE
TO anon, authenticated
USING (bucket_id = 'product-images')
WITH CHECK (bucket_id = 'product-images');

CREATE POLICY "product_images_delete"
ON storage.objects FOR DELETE
TO anon, authenticated
USING (bucket_id = 'product-images');

-- Refresh mobile view to include image_url
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

GRANT SELECT ON mobile_products TO anon, authenticated;
