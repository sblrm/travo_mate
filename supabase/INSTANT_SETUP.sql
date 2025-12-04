-- ============================================================================
-- TRAVOMATE - INSTANT DATABASE SETUP (ALL-IN-ONE)
-- ============================================================================
-- 🚀 Setup lengkap database TravoMate dalam 1 kali eksekusi
-- 
-- CARA PAKAI:
-- 1. Buat project baru di Supabase
-- 2. Copy SEMUA isi file ini
-- 3. Paste ke Supabase SQL Editor
-- 4. Klik RUN (Ctrl+Enter)
-- 5. Tunggu ~30 detik hingga selesai
-- 
-- File ini menggabungkan:
-- ✅ Complete setup (tables dasar)
-- ✅ Admin role system
-- ✅ Reviews & ratings
-- ✅ Transactions (Midtrans)
-- ✅ Wishlists & sharing
-- ✅ ML pipeline schema
-- ✅ Storage policies
-- ✅ All migrations penting
-- ============================================================================

-- ============================================================================
-- STEP 1: Enable Extensions
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- STEP 2: Create Custom Types
-- ============================================================================

CREATE TYPE hours_type AS (
    open text,
    close text
);

-- ============================================================================
-- STEP 3: Create Main Tables
-- ============================================================================

-- Destinations table with PostGIS support
CREATE TABLE IF NOT EXISTS public.destinations (
    id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    name text NOT NULL,
    city text NOT NULL,
    province text NOT NULL,
    type text NOT NULL,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    hours hours_type NOT NULL,
    duration integer NOT NULL,
    description text NOT NULL,
    image text NOT NULL,
    price numeric(10,2) NOT NULL,
    rating numeric(2,1) NOT NULL,
    transportation text[] NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    location geography(Point, 4326) GENERATED ALWAYS AS (st_makepoint(longitude, latitude)::geography) STORED
);

-- Plans table for trip planning
CREATE TABLE IF NOT EXISTS public.plans (
    id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    name text NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Plan destinations (many-to-many relationship)
CREATE TABLE IF NOT EXISTS public.plan_destinations (
    id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    plan_id bigint REFERENCES public.plans(id) ON DELETE CASCADE NOT NULL,
    destination_id bigint REFERENCES public.destinations(id) ON DELETE CASCADE NOT NULL,
    visit_date date NOT NULL,
    visit_order integer NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(plan_id, destination_id)
);

-- User profiles with role system
CREATE TABLE IF NOT EXISTS public.profiles (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username text UNIQUE NOT NULL,
    full_name text,
    avatar_url text,
    phone_number text,
    role text NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin', 'superadmin')),
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Tickets table for bookings
CREATE TABLE IF NOT EXISTS public.tickets (
    id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    destination_id bigint REFERENCES public.destinations(id) ON DELETE CASCADE NOT NULL,
    quantity integer NOT NULL CHECK (quantity > 0),
    total_price numeric(10,2) NOT NULL CHECK (total_price >= 0),
    visit_date date NOT NULL,
    booking_name text NOT NULL,
    booking_email text NOT NULL,
    booking_phone text NOT NULL,
    booking_code text UNIQUE,
    status text NOT NULL DEFAULT 'confirmed' CHECK (status IN ('confirmed', 'pending', 'cancelled')),
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Bookings table
CREATE TABLE IF NOT EXISTS public.bookings (
    id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    destination_id bigint REFERENCES public.destinations(id) ON DELETE CASCADE NOT NULL,
    booking_date date NOT NULL,
    booking_code text UNIQUE,
    quantity integer DEFAULT 1,
    total_price numeric(10,2),
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'cancelled')),
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Purchases table
CREATE TABLE IF NOT EXISTS public.purchases (
    id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    ticket_id bigint REFERENCES public.tickets(id) ON DELETE CASCADE NOT NULL,
    amount numeric(10,2) NOT NULL CHECK (amount >= 0),
    payment_method text NOT NULL,
    payment_status text NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'completed', 'failed')),
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Refunds table
CREATE TABLE IF NOT EXISTS public.refunds (
    id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    ticket_id bigint REFERENCES public.tickets(id) ON DELETE CASCADE NOT NULL,
    reason text NOT NULL,
    refund_amount numeric(10,2),
    admin_notes text,
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    requested_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    processed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Reviews table
CREATE TABLE IF NOT EXISTS public.reviews (
    id bigint PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    destination_id bigint REFERENCES public.destinations(id) ON DELETE CASCADE NOT NULL,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    rating integer NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment text,
    photos text[],
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(destination_id, user_id)
);

-- Transactions table (Midtrans payment tracking)
CREATE TABLE IF NOT EXISTS public.transactions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    order_id varchar(255) UNIQUE NOT NULL,
    booking_type varchar(50) NOT NULL,
    transaction_status varchar(50) NOT NULL DEFAULT 'pending',
    payment_type varchar(50),
    fraud_status varchar(50),
    gross_amount decimal(12, 2) NOT NULL,
    currency varchar(3) DEFAULT 'IDR',
    customer_name varchar(255),
    customer_email varchar(255),
    customer_phone varchar(50),
    snap_token text,
    redirect_url text,
    booking_id bigint,
    item_details jsonb,
    midtrans_response jsonb,
    transaction_time timestamp with time zone,
    settlement_time timestamp with time zone,
    expiry_time timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);

-- Wishlists table
CREATE TABLE IF NOT EXISTS public.wishlists (
    id bigserial PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name varchar(255) NOT NULL DEFAULT 'My Wishlist',
    description text,
    is_public boolean DEFAULT false,
    share_token varchar(32) UNIQUE,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Wishlist items table
CREATE TABLE IF NOT EXISTS public.wishlist_items (
    id bigserial PRIMARY KEY,
    wishlist_id bigint NOT NULL REFERENCES public.wishlists(id) ON DELETE CASCADE,
    destination_id bigint NOT NULL REFERENCES public.destinations(id) ON DELETE CASCADE,
    notes text,
    priority integer DEFAULT 0,
    added_at timestamptz DEFAULT now(),
    UNIQUE(wishlist_id, destination_id)
);

-- ML Pipeline: Trip data table
CREATE TABLE IF NOT EXISTS public.trip_data (
    id bigserial PRIMARY KEY,
    user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    origin_lat double precision NOT NULL,
    origin_lng double precision NOT NULL,
    destination_ids bigint[] NOT NULL,
    num_destinations integer NOT NULL,
    total_distance double precision,
    total_duration integer,
    optimization_mode text CHECK (optimization_mode IN ('fastest', 'cheapest', 'balanced')),
    transport_mode text,
    departure_time timestamptz,
    predicted_cost numeric(12,2),
    actual_cost numeric(12,2),
    weather_condition text,
    traffic_level text,
    day_of_week integer,
    is_weekend boolean,
    is_holiday boolean,
    fuel_price numeric(8,2),
    created_at timestamptz DEFAULT now(),
    completed_at timestamptz
);

-- ML Pipeline: Model metrics table
CREATE TABLE IF NOT EXISTS public.model_metrics (
    id bigserial PRIMARY KEY,
    model_version text NOT NULL,
    algorithm text NOT NULL,
    training_samples integer NOT NULL,
    mae double precision,
    rmse double precision,
    r2_score double precision,
    mape double precision,
    hyperparameters jsonb,
    feature_importance jsonb,
    is_production boolean DEFAULT false,
    trained_at timestamptz DEFAULT now(),
    deployed_at timestamptz
);

-- ML Pipeline: Prediction logs table
CREATE TABLE IF NOT EXISTS public.prediction_logs (
    id bigserial PRIMARY KEY,
    trip_data_id bigint REFERENCES public.trip_data(id) ON DELETE SET NULL,
    model_version text NOT NULL,
    predicted_cost numeric(12,2) NOT NULL,
    actual_cost numeric(12,2),
    prediction_error numeric(12,2),
    features jsonb,
    created_at timestamptz DEFAULT now()
);

-- ============================================================================
-- STEP 4: Enable Row Level Security
-- ============================================================================

ALTER TABLE public.destinations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.plan_destinations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.refunds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wishlists ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wishlist_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trip_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.model_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prediction_logs ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- STEP 5: Create RLS Policies
-- ============================================================================

-- Destinations policies
DROP POLICY IF EXISTS "Destinations are viewable by everyone" ON public.destinations;
CREATE POLICY "Destinations are viewable by everyone"
ON public.destinations FOR SELECT
TO authenticated, anon
USING (true);

DROP POLICY IF EXISTS "Admin can insert destinations" ON public.destinations;
CREATE POLICY "Admin can insert destinations"
ON public.destinations FOR INSERT
TO authenticated
WITH CHECK (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin')));

DROP POLICY IF EXISTS "Admin can update destinations" ON public.destinations;
CREATE POLICY "Admin can update destinations"
ON public.destinations FOR UPDATE
TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin')))
WITH CHECK (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin')));

DROP POLICY IF EXISTS "Admin can delete destinations" ON public.destinations;
CREATE POLICY "Admin can delete destinations"
ON public.destinations FOR DELETE
TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin')));

-- Plans policies
DROP POLICY IF EXISTS "Plans are viewable by owner only" ON public.plans;
CREATE POLICY "Plans are viewable by owner only"
ON public.plans FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Plans can be inserted by authenticated users" ON public.plans;
CREATE POLICY "Plans can be inserted by authenticated users"
ON public.plans FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Plan destinations policies
DROP POLICY IF EXISTS "Plan destinations are viewable by plan owner only" ON public.plan_destinations;
CREATE POLICY "Plan destinations are viewable by plan owner only"
ON public.plan_destinations FOR SELECT
TO authenticated
USING (EXISTS (SELECT 1 FROM public.plans WHERE id = plan_destinations.plan_id AND user_id = auth.uid()));

-- Profiles policies
DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON public.profiles;
CREATE POLICY "Profiles are viewable by everyone"
ON public.profiles FOR SELECT
TO authenticated, anon
USING (true);

DROP POLICY IF EXISTS "Profiles can only be updated by owner" ON public.profiles;
CREATE POLICY "Profiles can only be updated by owner"
ON public.profiles FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Profiles can be inserted by owner" ON public.profiles;
CREATE POLICY "Profiles can be inserted by owner"
ON public.profiles FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = id);

-- Tickets policies
DROP POLICY IF EXISTS "Users can view their own tickets" ON public.tickets;
CREATE POLICY "Users can view their own tickets"
ON public.tickets FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own tickets" ON public.tickets;
CREATE POLICY "Users can insert their own tickets"
ON public.tickets FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own tickets" ON public.tickets;
CREATE POLICY "Users can update their own tickets"
ON public.tickets FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Bookings policies
DROP POLICY IF EXISTS "Users can view their own bookings" ON public.bookings;
CREATE POLICY "Users can view their own bookings"
ON public.bookings FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own bookings" ON public.bookings;
CREATE POLICY "Users can insert their own bookings"
ON public.bookings FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own bookings" ON public.bookings;
CREATE POLICY "Users can update their own bookings"
ON public.bookings FOR UPDATE
TO authenticated
USING (auth.uid() = user_id);

-- Purchases policies
DROP POLICY IF EXISTS "Users can view their own purchases" ON public.purchases;
CREATE POLICY "Users can view their own purchases"
ON public.purchases FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Refunds policies
DROP POLICY IF EXISTS "Users can view their own refunds" ON public.refunds;
CREATE POLICY "Users can view their own refunds"
ON public.refunds FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert their own refunds" ON public.refunds;
CREATE POLICY "Users can insert their own refunds"
ON public.refunds FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Admin can update refunds" ON public.refunds;
CREATE POLICY "Admin can update refunds"
ON public.refunds FOR UPDATE
TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('admin', 'superadmin')));

-- Reviews policies
DROP POLICY IF EXISTS "Reviews are viewable by everyone" ON public.reviews;
CREATE POLICY "Reviews are viewable by everyone"
ON public.reviews FOR SELECT
TO authenticated, anon
USING (true);

DROP POLICY IF EXISTS "Users can insert their own reviews" ON public.reviews;
CREATE POLICY "Users can insert their own reviews"
ON public.reviews FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update their own reviews" ON public.reviews;
CREATE POLICY "Users can update their own reviews"
ON public.reviews FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete their own reviews" ON public.reviews;
CREATE POLICY "Users can delete their own reviews"
ON public.reviews FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- Transactions policies
DROP POLICY IF EXISTS "Users can view own transactions" ON public.transactions;
CREATE POLICY "Users can view own transactions"
ON public.transactions FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can insert own transactions" ON public.transactions;
CREATE POLICY "Users can insert own transactions"
ON public.transactions FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Service role can update transactions" ON public.transactions;
CREATE POLICY "Service role can update transactions"
ON public.transactions FOR UPDATE
USING (true);

-- Wishlists policies
DROP POLICY IF EXISTS "Users can view own wishlists" ON public.wishlists;
CREATE POLICY "Users can view own wishlists"
ON public.wishlists FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Anyone can view public wishlists" ON public.wishlists;
CREATE POLICY "Anyone can view public wishlists"
ON public.wishlists FOR SELECT
TO public
USING (is_public = true OR share_token IS NOT NULL);

DROP POLICY IF EXISTS "Users can create own wishlists" ON public.wishlists;
CREATE POLICY "Users can create own wishlists"
ON public.wishlists FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own wishlists" ON public.wishlists;
CREATE POLICY "Users can update own wishlists"
ON public.wishlists FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own wishlists" ON public.wishlists;
CREATE POLICY "Users can delete own wishlists"
ON public.wishlists FOR DELETE
TO authenticated
USING (auth.uid() = user_id);

-- Wishlist items policies
DROP POLICY IF EXISTS "Users can view items from own wishlists" ON public.wishlist_items;
CREATE POLICY "Users can view items from own wishlists"
ON public.wishlist_items FOR SELECT
TO authenticated
USING (EXISTS (SELECT 1 FROM public.wishlists WHERE id = wishlist_items.wishlist_id AND user_id = auth.uid()));

DROP POLICY IF EXISTS "Anyone can view items from public wishlists" ON public.wishlist_items;
CREATE POLICY "Anyone can view items from public wishlists"
ON public.wishlist_items FOR SELECT
TO public
USING (EXISTS (SELECT 1 FROM public.wishlists WHERE id = wishlist_items.wishlist_id AND (is_public = true OR share_token IS NOT NULL)));

DROP POLICY IF EXISTS "Users can insert items to own wishlists" ON public.wishlist_items;
CREATE POLICY "Users can insert items to own wishlists"
ON public.wishlist_items FOR INSERT
TO authenticated
WITH CHECK (EXISTS (SELECT 1 FROM public.wishlists WHERE id = wishlist_items.wishlist_id AND user_id = auth.uid()));

DROP POLICY IF EXISTS "Users can delete items from own wishlists" ON public.wishlist_items;
CREATE POLICY "Users can delete items from own wishlists"
ON public.wishlist_items FOR DELETE
TO authenticated
USING (EXISTS (SELECT 1 FROM public.wishlists WHERE id = wishlist_items.wishlist_id AND user_id = auth.uid()));

-- ML Pipeline policies
DROP POLICY IF EXISTS "Users can view own trip data" ON public.trip_data;
CREATE POLICY "Users can view own trip data"
ON public.trip_data FOR SELECT
TO authenticated
USING (auth.uid() = user_id OR user_id IS NULL);

DROP POLICY IF EXISTS "Users can insert own trip data" ON public.trip_data;
CREATE POLICY "Users can insert own trip data"
ON public.trip_data FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

DROP POLICY IF EXISTS "Users can update own trip data" ON public.trip_data;
CREATE POLICY "Users can update own trip data"
ON public.trip_data FOR UPDATE
TO authenticated
USING (auth.uid() = user_id OR user_id IS NULL);

DROP POLICY IF EXISTS "Anyone can view model metrics" ON public.model_metrics;
CREATE POLICY "Anyone can view model metrics"
ON public.model_metrics FOR SELECT
TO authenticated, anon
USING (true);

DROP POLICY IF EXISTS "Users can view own prediction logs" ON public.prediction_logs;
CREATE POLICY "Users can view own prediction logs"
ON public.prediction_logs FOR SELECT
TO authenticated
USING (EXISTS (SELECT 1 FROM public.trip_data WHERE id = prediction_logs.trip_data_id AND (user_id = auth.uid() OR user_id IS NULL)));

DROP POLICY IF EXISTS "System can insert prediction logs" ON public.prediction_logs;
CREATE POLICY "System can insert prediction logs"
ON public.prediction_logs FOR INSERT
TO authenticated
WITH CHECK (true);

-- ============================================================================
-- STEP 6: Create Functions and Triggers
-- ============================================================================

-- Function to handle updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    new.updated_at = timezone('utc'::text, now());
    RETURN new;
END;
$$ LANGUAGE plpgsql;

-- Add updated_at triggers
CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.destinations FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.plans FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.plan_destinations FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.tickets FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.purchases FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.refunds FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.reviews FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.transactions FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
CREATE TRIGGER handle_updated_at BEFORE UPDATE ON public.wishlists FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Function to auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user_profile()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, username, full_name)
    VALUES (
        new.id,
        COALESCE(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
        COALESCE(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name')
    );
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user_profile();

-- Function for upsert profile
CREATE OR REPLACE FUNCTION public.upsert_profile(
    user_id uuid,
    new_username text,
    new_full_name text DEFAULT NULL,
    new_avatar_url text DEFAULT NULL,
    new_phone_number text DEFAULT NULL
)
RETURNS void AS $$
BEGIN
    INSERT INTO public.profiles (id, username, full_name, avatar_url, phone_number)
    VALUES (user_id, new_username, new_full_name, new_avatar_url, new_phone_number)
    ON CONFLICT (id)
    DO UPDATE SET
        username = EXCLUDED.username,
        full_name = COALESCE(EXCLUDED.full_name, profiles.full_name),
        avatar_url = COALESCE(EXCLUDED.avatar_url, profiles.avatar_url),
        phone_number = COALESCE(EXCLUDED.phone_number, profiles.phone_number),
        updated_at = timezone('utc'::text, now());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check admin status
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM public.profiles 
    WHERE id = auth.uid() 
    AND role IN ('admin', 'superadmin')
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to generate wishlist share token
CREATE OR REPLACE FUNCTION public.generate_share_token()
RETURNS varchar(32) AS $$
BEGIN
  RETURN encode(gen_random_bytes(16), 'hex');
END;
$$ LANGUAGE plpgsql;

-- Function to generate booking code
CREATE OR REPLACE FUNCTION public.generate_booking_code()
RETURNS text AS $$
DECLARE
    code text;
    exists_check boolean;
BEGIN
    LOOP
        -- Generate random 8-character alphanumeric code
        code := upper(substring(md5(random()::text || clock_timestamp()::text) from 1 for 8));
        
        -- Check if code already exists
        SELECT EXISTS(SELECT 1 FROM public.bookings WHERE booking_code = code) INTO exists_check;
        
        -- Exit loop if code is unique
        EXIT WHEN NOT exists_check;
    END LOOP;
    
    RETURN code;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- STEP 7: Create Views
-- ============================================================================

-- View for destination ratings summary
CREATE OR REPLACE VIEW public.destination_ratings AS
SELECT 
    d.id as destination_id,
    COALESCE(AVG(r.rating), 0) as average_rating,
    COUNT(r.id) as review_count,
    COUNT(CASE WHEN r.rating = 5 THEN 1 END) as five_star_count,
    COUNT(CASE WHEN r.rating = 4 THEN 1 END) as four_star_count,
    COUNT(CASE WHEN r.rating = 3 THEN 1 END) as three_star_count,
    COUNT(CASE WHEN r.rating = 2 THEN 1 END) as two_star_count,
    COUNT(CASE WHEN r.rating = 1 THEN 1 END) as one_star_count
FROM public.destinations d
LEFT JOIN public.reviews r ON d.id = r.destination_id
GROUP BY d.id;

-- View for ML training data
CREATE OR REPLACE VIEW public.ml_training_data AS
SELECT 
    td.id,
    td.num_destinations,
    td.total_distance,
    td.total_duration,
    td.optimization_mode,
    td.transport_mode,
    EXTRACT(HOUR FROM td.departure_time) as departure_hour,
    td.day_of_week,
    td.is_weekend::int as is_weekend,
    td.is_holiday::int as is_holiday,
    td.traffic_level,
    td.weather_condition,
    td.fuel_price,
    td.predicted_cost,
    td.actual_cost,
    td.created_at
FROM public.trip_data td
WHERE td.actual_cost IS NOT NULL
AND td.completed_at IS NOT NULL;

-- ============================================================================
-- STEP 8: Create Indexes for Performance
-- ============================================================================

CREATE INDEX IF NOT EXISTS destinations_location_idx ON public.destinations USING gist(location);
CREATE INDEX IF NOT EXISTS destinations_province_idx ON public.destinations(province);
CREATE INDEX IF NOT EXISTS destinations_type_idx ON public.destinations(type);
CREATE INDEX IF NOT EXISTS plans_user_id_idx ON public.plans(user_id);
CREATE INDEX IF NOT EXISTS plan_destinations_plan_id_idx ON public.plan_destinations(plan_id);
CREATE INDEX IF NOT EXISTS plan_destinations_destination_id_idx ON public.plan_destinations(destination_id);
CREATE INDEX IF NOT EXISTS profiles_role_idx ON public.profiles(role);
CREATE INDEX IF NOT EXISTS tickets_user_id_idx ON public.tickets(user_id);
CREATE INDEX IF NOT EXISTS tickets_destination_id_idx ON public.tickets(destination_id);
CREATE INDEX IF NOT EXISTS tickets_booking_code_idx ON public.tickets(booking_code);
CREATE INDEX IF NOT EXISTS bookings_user_id_idx ON public.bookings(user_id);
CREATE INDEX IF NOT EXISTS bookings_booking_code_idx ON public.bookings(booking_code);
CREATE INDEX IF NOT EXISTS purchases_user_id_idx ON public.purchases(user_id);
CREATE INDEX IF NOT EXISTS refunds_user_id_idx ON public.refunds(user_id);
CREATE INDEX IF NOT EXISTS refunds_status_idx ON public.refunds(status);
CREATE INDEX IF NOT EXISTS reviews_destination_id_idx ON public.reviews(destination_id);
CREATE INDEX IF NOT EXISTS reviews_user_id_idx ON public.reviews(user_id);
CREATE INDEX IF NOT EXISTS reviews_rating_idx ON public.reviews(rating);
CREATE INDEX IF NOT EXISTS reviews_created_at_idx ON public.reviews(created_at DESC);
CREATE INDEX IF NOT EXISTS transactions_user_id_idx ON public.transactions(user_id);
CREATE INDEX IF NOT EXISTS transactions_order_id_idx ON public.transactions(order_id);
CREATE INDEX IF NOT EXISTS transactions_status_idx ON public.transactions(transaction_status);
CREATE INDEX IF NOT EXISTS transactions_created_at_idx ON public.transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS wishlists_user_id_idx ON public.wishlists(user_id);
CREATE INDEX IF NOT EXISTS wishlists_share_token_idx ON public.wishlists(share_token);
CREATE INDEX IF NOT EXISTS wishlist_items_wishlist_id_idx ON public.wishlist_items(wishlist_id);
CREATE INDEX IF NOT EXISTS wishlist_items_destination_id_idx ON public.wishlist_items(destination_id);
CREATE INDEX IF NOT EXISTS trip_data_user_id_idx ON public.trip_data(user_id);
CREATE INDEX IF NOT EXISTS trip_data_created_at_idx ON public.trip_data(created_at DESC);
CREATE INDEX IF NOT EXISTS prediction_logs_trip_data_id_idx ON public.prediction_logs(trip_data_id);

-- ============================================================================
-- STEP 9: Grant Permissions
-- ============================================================================

GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated;

-- ============================================================================
-- SETUP SELESAI! 🎉
-- ============================================================================
-- 
-- LANGKAH SELANJUTNYA:
-- 
-- 1. Setup Storage Bucket:
--    - Dashboard → Storage → Create bucket: "culture-uploads"
--    - Set Public: ON
--    - Allowed MIME types: image/*
-- 
-- 2. Insert Data Destinasi:
--    - Jalankan file: supabase/seed-data.sql
--    - Atau import dari CSV/JSON
-- 
-- 3. Set Admin User (ganti email):
--    UPDATE public.profiles 
--    SET role = 'admin'
--    WHERE id = (
--      SELECT id FROM auth.users WHERE email = 'your-email@example.com'
--    );
-- 
-- 4. Setup Environment Variables (.env.local):
--    VITE_SUPABASE_URL=your_project_url
--    VITE_SUPABASE_ANON_KEY=your_anon_key
--    VITE_GEMINI_API_KEY=your_gemini_key
--    VITE_MIDTRANS_CLIENT_KEY=your_midtrans_client_key
-- 
-- 5. Test Connection:
--    bun run test:connection
-- 
-- ============================================================================
