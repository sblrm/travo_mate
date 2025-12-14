-- Add custom_field2 to transactions table
-- Used to store destination_id for easier booking creation

ALTER TABLE public.transactions 
  ADD COLUMN IF NOT EXISTS custom_field2 TEXT;

-- Add comment to clarify usage
COMMENT ON COLUMN public.transactions.custom_field2 IS 'Stores destination_id from payment metadata for booking creation';

-- Add index for faster queries
CREATE INDEX IF NOT EXISTS idx_transactions_custom_field2 ON public.transactions(custom_field2);
