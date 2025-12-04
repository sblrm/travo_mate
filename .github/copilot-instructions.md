# TravoMate - AI Coding Agent Instructions

## Project Overview
TravoMate is a React + TypeScript SPA for exploring Indonesian cultural heritage sites with AI-powered trip planning, dynamic route optimization, and payment processing. Stack: Vite, Supabase (PostgreSQL + PostGIS), Tailwind + shadcn/ui, Gemini AI, Midtrans payments.

## Architecture & Data Flow

### Core Services
- **Backend**: Supabase (auth, PostgreSQL w/ PostGIS extension for geospatial queries)
- **State Management**: React Context (`AuthContext`, `MapContext`, `DestinationsContext`) + `@tanstack/react-query`
- **Routing**: React Router v6 with nested routes (`/admin`, `/profile/*`, `/wishlist`)
- **API Proxies**: Serverless functions in `/api` (Gemini AI, Midtrans payments, OpenRouteService) to hide API keys

### Key Database Tables
- `destinations` - Cultural sites with PostGIS `geography` column for spatial queries
- `profiles` - User data with `role` enum (`user`, `admin`, `superadmin`) for RBAC
- `bookings`, `transactions`, `reviews` - Payment and engagement tracking
- `wishlists`, `wishlist_items` - User-created trip collections with sharing
- `trip_data`, `prediction_logs` - ML training data & inference logs

### Authentication Flow
1. Supabase Auth handles login/register/OAuth (Google)
2. `handle_new_user_profile()` trigger auto-creates profile on signup
3. Guest mode available (stored in localStorage, bypasses auth)
4. Admin access: Check `profiles.role` via `is_admin()` RPC
5. RLS policies enforce row-level security on all tables

## Development Commands

```powershell
# Prefer Bun over npm (faster installs/builds)
bun install           # Install dependencies
bun run dev           # Start dev server (localhost:8080)
bun run build         # Production build
bun run lint          # ESLint check

# Database testing
bun run test:connection     # Verify Supabase connection
bun run test:destinations   # Test destination queries

# Setup helpers
bun run setup:verify        # PowerShell: Run verify-supabase.ps1
bun run setup:check         # Node: Check env vars and connections
bun run import:destinations # Bulk import from CSV/JSON
```

## Critical Conventions

### File Structure Patterns
- **Pages**: `src/pages/[PageName].tsx` - Route components, compose services
- **Services**: `src/services/*.ts` - Business logic (e.g., `routePlanner.ts`, `adminService.ts`)
- **Context**: `src/contexts/*Context.tsx` - Global state (wrap in `App.tsx`)
- **Components**: `src/components/[feature]/` - Organized by feature (map, planner, admin, wishlist)
- **API Routes**: `api/*.ts` - Vercel serverless functions (VercelRequest/VercelResponse types)

### Environment Variables
**Required in `.env.local`:**
```bash
VITE_SUPABASE_URL=            # Supabase project URL
VITE_SUPABASE_ANON_KEY=       # Public anon key
VITE_GEMINI_API_KEY=          # For client-side AI features (optional)
VITE_MIDTRANS_CLIENT_KEY=     # Midtrans Snap popup (client-safe)
VITE_MIDTRANS_ENVIRONMENT=sandbox  # 'sandbox' or 'production'

# Server-side only (Vercel env vars, NEVER prefix with VITE_)
GEMINI_API_KEY=               # Used by /api/gemini
MIDTRANS_SERVER_KEY=          # Used by /api/midtrans
MIDTRANS_MERCHANT_ID=         # Midtrans merchant
SUPABASE_SERVICE_ROLE_KEY=    # For /api/midtrans webhook (bypasses RLS)
APP_URL=                      # Payment redirect base URL
OPENROUTE_API_KEY=            # Optional: Enhanced route calculations
```

### Route Planning Algorithm
**Implementation**: A* pathfinding in `src/services/routePlanner.ts`
- **Modes**: `fastest`, `cheapest`, `balanced` (user-selectable)
- **Cost Functions**: 
  - Distance + duration from OpenRouteService API (1-hour cache)
  - Dynamic pricing factors: time-of-day, day-of-week, traffic, fuel, tolls (`dynamicPricing.ts`)
- **Fallback**: Haversine formula if API fails
- **Integration**: Called from `PlannerPage.tsx` → displays route on Leaflet map

### Admin Dashboard Patterns
**Location**: `src/pages/admin/`, protected by `isAdmin()` check
- **CRUD**: `adminService.ts` - `createDestination()`, `updateDestination()`, `deleteDestination()`
- **Image Upload**: Direct to Supabase Storage (`culture-uploads` bucket) with RLS policies
- **Search/Filter**: Client-side on `AdminDashboard` (real-time, no API calls)
- **Pagination**: Configurable items per page (5-100), smart ellipsis for pages > 7
- **Validation**: Zod schemas in forms (`react-hook-form` + `@hookform/resolvers`)

### Payment Flow (Midtrans)
1. **Checkout**: User selects destination → `/checkout/:id` → Creates booking in DB (status: `pending`)
2. **Payment Init**: `paymentService.ts` calls `/api/midtrans` → Returns `snap_token`
3. **Snap Popup**: Client loads Midtrans Snap with `VITE_MIDTRANS_CLIENT_KEY`
4. **Webhook**: `/api/midtrans` handles notifications → Updates transaction + booking status
5. **Redirect**: User returns to `/payment/finish?order_id=...&status=...`
6. **Critical**: Webhook needs `SUPABASE_SERVICE_ROLE_KEY` to bypass RLS when auto-confirming bookings

### Internationalization (i18n)
- **Library**: `react-i18next` with `i18next-browser-languagedetector`
- **Config**: `src/i18n/config.ts` - Default: `id` (Indonesian), fallback: `id`
- **Translations**: `src/locales/{id,en,zh,ja,ko}.json`
- **Usage**: `const { t } = useTranslation(); t('key.path')`
- **Language Switcher**: `LanguageSwitcher.tsx` in header, saves to localStorage

### Component Library (shadcn/ui)
- **Source**: `src/components/ui/` - Radix UI primitives + Tailwind
- **Theme**: CSS variables in `src/index.css` (light/dark mode via `next-themes`)
- **Dark Mode**: `ThemeProvider` in `App.tsx`, toggle via `ThemeToggle.tsx`
- **Customization**: Modify `tailwind.config.ts` theme.extend for colors/animations

## Common Pitfalls & Solutions

### Supabase PostGIS Queries
**Problem**: `location` column is geography type, requires `ST_` functions
**Solution**: Use `ST_DWithin`, `ST_Distance`, `ST_SetSRID`, `ST_MakePoint` for spatial queries
**Example**:
```typescript
const { data } = await supabase.rpc('destinations_within_radius', {
  lat: -7.797068, lng: 110.370529, radius_km: 50
});
```

### RLS Policy Debugging
**Problem**: Query returns empty even when data exists
**Solution**: Check policies in Supabase Dashboard → Authentication → Policies. Common fix: Add `anon` role or adjust `USING` clause
**Test**: Use service_role key temporarily to bypass RLS (NEVER in production)

### API Route CORS Errors
**Problem**: `fetch('/api/gemini')` blocked by CORS in production
**Solution**: `vercel.json` sets `Access-Control-Allow-Origin` for `/api/*`. Ensure `APP_URL` matches deployed domain
**Dev**: Use `localhost:8080` in `APP_URL` for local testing

### Midtrans Webhook Not Firing
**Problem**: Payments succeed but bookings stay `pending`
**Checklist**:
1. Verify `SUPABASE_SERVICE_ROLE_KEY` in Vercel env vars
2. Check webhook URL in Midtrans dashboard: `https://your-domain.vercel.app/api/midtrans`
3. Test with Midtrans simulator: https://simulator.sandbox.midtrans.com/
4. Check Vercel function logs for errors

### ML Pipeline (TensorFlow.js)
**Training**: Run `ml_pipeline/train_model.py` → Exports to `public/tfjs_model/`
**Inference**: `src/services/mlPrediction.ts` loads model, predicts trip costs
**Hybrid**: Falls back to rule-based (`dynamicPricing.ts`) if model unavailable
**Data Collection**: Auto-logs trips in `trip_data` table via `mlDataCollection.ts`

## Testing & Debugging

### Quick Checks
```powershell
# Test Supabase connection
bun run test:connection

# Verify environment setup
bun run setup:check

# Check admin role assignment
# In Supabase SQL Editor:
SELECT id, email, role FROM auth.users 
JOIN public.profiles ON auth.users.id = public.profiles.id;
```

### Common Errors
- **"PostGIS not enabled"**: Dashboard → Database → Extensions → Enable `postgis`
- **"RLS policy violation"**: Check table policies or use service_role key
- **"Missing API key"**: Ensure `.env.local` vars match docs, restart dev server

## Security Guidelines
- **Never** commit `.env.local` or expose `SUPABASE_SERVICE_ROLE_KEY`
- **Always** use `VITE_` prefix for client-safe env vars
- **Sanitize** errors in production (see `src/utils/errorSanitization.ts`)
- **Mask** sensitive data (emails, phones) with `src/utils/dataMasking.ts`
- **Validate** inputs with Zod schemas before DB operations
- **RLS**: Every table must have policies (no public read/write by default)

## Key Files to Review
- `docs/QUICK_START.md` - Setup walkthrough
- `docs/ARCHITECTURE_DIAGRAM.md` - Visual system architecture
- `docs/ALGORITHMS.md` - A* implementation details
- `docs/ADMIN_DASHBOARD.md` - Admin feature documentation
- `docs/MIDTRANS_INTEGRATION.md` - Payment flow
- `supabase/complete-setup.sql` - Full schema + RLS policies
- `src/App.tsx` - Route definitions and context providers
- `src/lib/supabase.ts` - Database types and helper functions

## When Adding Features
1. **Database**: Add migration in `supabase/migrations/`, update RLS policies
2. **Types**: Regenerate types with `supabase gen types typescript` or update `src/lib/database.types.ts`
3. **Service**: Create service file in `src/services/` for business logic
4. **Page/Component**: Build UI in `src/pages/` or `src/components/`
5. **Route**: Add to `App.tsx` Routes, protect with auth if needed
6. **i18n**: Update all locale files in `src/locales/`
7. **Test**: Use `bun run test:*` commands to verify
