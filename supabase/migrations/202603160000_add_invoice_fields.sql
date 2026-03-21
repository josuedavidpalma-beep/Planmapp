-- Migration for adding Intelligent Receipt Splitter parameters
-- Adding subtotal, tax_amount, tip_amount to expenses table

ALTER TABLE "public"."expenses"
ADD COLUMN IF NOT EXISTS "subtotal" numeric,
ADD COLUMN IF NOT EXISTS "tax_amount" numeric,
ADD COLUMN IF NOT EXISTS "tip_amount" numeric;

-- End of migration
