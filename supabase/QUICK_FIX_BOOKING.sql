-- QUICK FIX: Booking Not Created After Payment
-- Run this SQL in Supabase Dashboard → SQL Editor

-- Step 1: Add custom_field columns to store metadata
-- custom_field1 = visit_date (tanggal kunjungan)
-- custom_field2 = destination_id (ID destinasi)
-- custom_field3 = reserved for future use

ALTER TABLE public.transactions 
  ADD COLUMN IF NOT EXISTS custom_field1 TEXT;

ALTER TABLE public.transactions 
  ADD COLUMN IF NOT EXISTS custom_field2 TEXT;

ALTER TABLE public.transactions 
  ADD COLUMN IF NOT EXISTS custom_field3 TEXT;

COMMENT ON COLUMN public.transactions.custom_field1 IS 'Stores visit_date from payment metadata';
COMMENT ON COLUMN public.transactions.custom_field2 IS 'Stores destination_id from payment metadata for booking creation';
COMMENT ON COLUMN public.transactions.custom_field3 IS 'Reserved for future metadata';

-- Step 2: Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_transactions_custom_field1 ON public.transactions(custom_field1);
CREATE INDEX IF NOT EXISTS idx_transactions_custom_field2 ON public.transactions(custom_field2);
CREATE INDEX IF NOT EXISTS idx_transactions_custom_field3 ON public.transactions(custom_field3);

-- Step 3: Verify column was added
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'transactions' 
AND column_name LIKE 'custom_field%'
ORDER BY column_name;

-- Expected output: You should see custom_field1, custom_field2, custom_field3

-- Step 4: Check recent transactions (optional verification)
SELECT 
  order_id, 
  custom_field1 as visit_date, 
  custom_field2 as destination_id,
  transaction_status,
  created_at
FROM transactions
ORDER BY created_at DESC
LIMIT 5;

-- Done! ✅ Now rebuild and test the mobile app
