# TravoMate AI Coding Agent Instructions

## Project Overview
**TravoMate** is a modern cultural heritage travel planner for Indonesia built with React + TypeScript + Vite, featuring AI-powered trip planning (Gemini), real-time routing (OpenRouteService), payment processing (Midtrans), and ML cost predictions (TensorFlow.js). The app supports guest mode, multi-language (5 languages), admin dashboard, and booking/refund system.

## Tech Stack & Architecture

### Frontend
- **React 18** with TypeScript (strict mode)
- **Vite** for build tooling (NOT Create React App)
- **React Router v6** for navigation
- **shadcn/ui** + **Radix UI** for components (DO NOT install MUI/Ant Design)
- **Tailwind CSS** for styling (utility-first approach)
- **i18next** for internationalization (5 languages: id, en, zh, ja, ko)

### Backend & Services
- **Supabase** (PostgreSQL + PostGIS + Storage + Auth + RLS)
- **Serverless Functions** in `api/` for Vercel deployment
- **OpenRouteService API** for real-time routing with 1-hour cache
- **Midtrans** payment gateway with webhook handlers
- **Gemini AI** for chat-based trip planning (server-side proxy)

### Key Services Location
All service files live in `src/services/`:
- `routePlanner.ts` - A* algorithm for optimal route finding
- `dynamicPricing.ts` - Rule-based pricing with time/traffic multipliers
- `openRouteService.ts` - ORS API integration with Haversine fallback
- `mlPrediction.ts` - TensorFlow.js browser-side inference
- `adminService.ts` - Admin CRUD operations with RLS checks
- `paymentService.ts` - Midtrans integration
- `wishlistService.ts` - Wishlist management with social sharing

## Critical Development Workflows

### Running the App
```powershell
# Install dependencies (prefer Bun for speed)
bun install  # or: npm install

# Development server
bun run dev  # Opens on http://localhost:8080

# Build for production
bun run build  # Output: dist/

# Preview production build
bun run preview
```

### Database Operations
```powershell
# Test Supabase connection
bun run test:connection

# Verify destinations data
bun run test:destinations

# Check setup completeness
bun run setup:check

# Import destinations from JSON/CSV
bun run import:destinations scripts/destinations-template.json
```

### Admin Dashboard Access
1. Run migration: `supabase/migrations/add_admin_role.sql`
2. Manually set admin role in Supabase SQL Editor:
   ```sql
   UPDATE public.profiles SET role = 'admin' WHERE id = (SELECT id FROM auth.users WHERE email = 'admin@example.com');
   ```
3. Access at `/admin` route (auto-protected by RLS + client-side checks)

## Project-Specific Conventions

### File Structure Patterns
- **Pages:** `src/pages/` - Route components (e.g., `HomePage.tsx`, `PlannerPage.tsx`)
- **Components:** `src/components/` - Reusable UI components (shadcn/ui based)
- **Contexts:** `src/contexts/` - Global state (Auth, Map, Destinations, Theme)
- **Services:** `src/services/` - Business logic and API integrations
- **Hooks:** `src/hooks/` - Custom React hooks
- **Locales:** `src/locales/` - Translation files (id.json, en.json, etc.)
- **API Routes:** `api/` - Vercel serverless functions (gemini.ts, midtrans.ts)

### Authentication & Authorization
**Auth Modes:**
- Guest mode: `user.id = 'guest'`, stored in localStorage, NO database writes
- Authenticated: Supabase auth with JWT, profile in `profiles` table
- Admin: `profiles.role IN ('admin', 'superadmin')` checked via `isAdmin()` function

**RLS Policies Pattern:**
```sql
-- Public read for destinations
CREATE POLICY "Destinations are viewable by everyone" ON destinations FOR SELECT USING (true);

-- Admin-only write operations
CREATE POLICY "Admin can insert destinations" ON destinations FOR INSERT USING (public.is_admin());

-- User-owned data
CREATE POLICY "Users can view own bookings" ON bookings FOR SELECT USING (auth.uid() = user_id);
```

**Always check both:**
1. Client-side: `const { isAuthenticated, isGuest } = useAuth();`
2. Server-side: RLS policies enforce at database level

### Routing & Data Flow
**Route Planning Pipeline:**
```
User Location → PlannerPage → routePlanner.ts (A* algorithm)
                     ↓
             openRouteService.ts (API + cache) + dynamicPricing.ts
                     ↓
             PlannedRouteCard.tsx (display with cost breakdown)
```

**Data Sources Priority:**
1. Real-time ORS API (dataSource: 'ors')
2. In-memory cache (1-hour TTL)
3. Haversine formula fallback (dataSource: 'fallback')

### Environment Variables Pattern
```bash
# Client-side (VITE_ prefix, embedded in bundle)
VITE_SUPABASE_URL=https://xxx.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGc...
VITE_MIDTRANS_CLIENT_KEY=SB-Mid-client-xxx
VITE_MIDTRANS_ENVIRONMENT=sandbox
VITE_ORS_API_KEY=xxx

# Server-side ONLY (NO VITE_ prefix)
GEMINI_API_KEY=xxx           # Used in api/gemini.ts
MIDTRANS_SERVER_KEY=xxx      # Used in api/midtrans.ts
SUPABASE_SERVICE_ROLE_KEY=xxx  # For webhook bypass RLS
APP_URL=https://travo-mate.vercel.app  # Payment redirect base
```

**NEVER add VITE_ prefix to sensitive server keys!**

## Integration Points & External Dependencies

### Supabase Integration
- **Schema:** See `supabase/complete-setup.sql` for full schema
- **PostGIS:** Required for geographical queries (`location geography(Point, 4326)`)
- **Storage:** `destination-images` bucket with public read policy
- **Auth:** OAuth providers (Google) configured in Supabase Dashboard
- **RLS:** All tables have row-level security enabled

**Key Tables:**
- `destinations` - Cultural heritage sites (public read, admin write)
- `bookings` - User reservations with status workflow
- `profiles` - User metadata with `role` column for admin
- `wishlists` - User collections with social sharing via `share_token`
- `trip_data` + `prediction_logs` - ML training data

### OpenRouteService API
- **Free Tier:** 2,000 requests/day, 40 req/min
- **Endpoints:** Matrix API (batch), Directions API (detailed routes)
- **Cache Strategy:** In-memory Map with 1-hour TTL, auto-cleanup every 5 mins
- **Fallback:** Haversine great-circle distance when API fails
- **Docs:** `docs/EXTERNAL_APIS.md`

### Midtrans Payment Gateway
- **Sandbox Mode:** Testing with fake credit cards
- **Snap Integration:** Popup payment UI via `window.snap.pay()`
- **Webhook:** `api/midtrans.ts` handles notification callbacks
- **Transaction Flow:** Create snap token → User pays → Webhook updates booking status
- **Docs:** `docs/MIDTRANS_INTEGRATION.md`

### Gemini AI Integration
- **Proxy:** `api/gemini.ts` (server-side API key, rate-limited per IP)
- **Model:** `gemini-2.5-flash` for trip planning chat
- **Context:** Destinations data injected into prompts
- **Rate Limit:** 20 requests/IP/minute (in-memory, per serverless instance)

## Common Patterns & Anti-Patterns

### ✅ DO:
```typescript
// Use shadcn/ui components
import { Button } from "@/components/ui/button";
import { useToast } from "@/hooks/use-toast";

// Use i18next for translations
import { useTranslation } from 'react-i18next';
const { t } = useTranslation();
<h1>{t('home.hero.title')}</h1>

// Check admin status
const isUserAdmin = await isAdmin();
if (!isUserAdmin) navigate('/');

// Handle both guest and authenticated users
if (isGuest) {
  toast.error(t('auth.guestRestriction'));
  return;
}

// Use hybridPrediction for ML + fallback
const estimate = await getHybridPrediction(routeData, conditions);
```

### ❌ DON'T:
```typescript
// Don't install new UI libraries (we use shadcn/ui)
import { Button } from '@mui/material'; // ❌

// Don't hardcode strings (use i18next)
<h1>Welcome to TravoMate</h1> // ❌

// Don't expose server keys in client
const serverKey = import.meta.env.VITE_MIDTRANS_SERVER_KEY; // ❌

// Don't assume authentication (always check)
const userId = user.id; // ❌ (could be null or 'guest')

// Don't bypass RLS with service_role key on client
const { data } = await supabase.auth.admin.listUsers(); // ❌
```

## Admin Dashboard Specifics
- **Route Protection:** Automatic redirect in `useEffect` via `isAdmin()` check
- **CRUD Operations:** All mutations via `adminService.ts` with RLS enforcement
- **Search/Filter/Pagination:** Client-side filtering (no API calls), see `docs/ADMIN_SEARCH_FILTER_PAGINATION.md`
- **Image Upload:** Direct to Supabase Storage `destination-images` bucket
- **Form Validation:** Zod schemas with real-time error display
- **Statistics:** Count queries for total destinations/reviews/bookings

## ML Pipeline
- **Training:** Python script `ml_pipeline/train_model.py` (Random Forest → TensorFlow.js export)
- **Inference:** Browser-side TensorFlow.js via `mlPrediction.ts`
- **Data Collection:** Automatic via `mlDataCollection.ts` on every route plan
- **Hybrid Logic:** `hybridPrediction.ts` uses ML if confidence > 0.7, else rule-based
- **Models Location:** `public/models/` (model.json, weights, metadata.json)
- **Docs:** `docs/ML_PIPELINE.md`

## Guest Mode Implementation
**Key Principle:** Guest users see full UI but cannot perform database writes.

```typescript
// Check in components
const { isGuest } = useAuth();

// Block actions
const handleBooking = () => {
  if (isGuest) {
    toast.error('Please login to book tickets');
    return;
  }
  // ... proceed
};
```

**Guest user object:**
```typescript
{
  id: 'guest',
  name: 'Guest User',
  email: 'guest@travomate.com',
  isGuest: true
}
```

**LocalStorage flag:** `guestMode: 'true'`  
**RLS Protection:** All policies check `auth.uid()` which fails for guest  
**Docs:** `docs/GUEST_MODE.md`

## Booking & Refund System
**Booking States:**
- `pending_payment` → `paid` → `confirmed` → `used`
- Alternative: `paid` → `refund_requested` → `refunded`
- Cancellation: `paid` → `cancelled`

**Refund Rules:**
- ≥7 days before visit: 100% refund
- 3-6 days before: 50% refund
- <3 days before: 25% refund
- Check via `checkRefundEligibility(bookingId)` (RPC or manual fallback)

**Docs:** `docs/BOOKING_REFUND_SYSTEM.md`

## Testing & Debugging

### Common Issues
**"API key not found"** in ORS:
- Check `VITE_ORS_API_KEY` in `.env.local`
- Verify API key is valid at openrouteservice.org

**Admin access denied:**
- Run `add_admin_role.sql` migration first
- Manually set `role = 'admin'` in profiles table
- Clear browser cache and re-login

**Payment webhook not working:**
- Ensure `SUPABASE_SERVICE_ROLE_KEY` set in Vercel
- Check webhook URL in Midtrans dashboard matches `api/midtrans.ts`
- Verify `APP_URL` environment variable for redirects

**Translation missing:**
- Add key to all 5 locale files (id.json, en.json, zh.json, ja.json, ko.json)
- Follow nested structure: `{ "section": { "subsection": "value" } }`

**CORS errors after security update:**
- Verify `APP_URL` matches production domain in Vercel env vars
- Check `allowedOrigins` array in `api/midtrans.ts` and `api/gemini.ts`
- Clear browser cache and retry

### Useful Commands
```powershell
# Check all errors
npm run lint

# View Supabase logs
# (Go to Supabase Dashboard > Logs)

# Test ML pipeline
# python ml_pipeline/train_model.py

# Clear ORS cache (restart dev server)
# (Cache is in-memory only)
```

## Security Best Practices

### Data Protection
**Always mask sensitive data:**
```typescript
import { maskEmail, maskPhoneNumber } from '@/utils/dataMasking';
import { getUserFriendlyError } from '@/utils/errorSanitization';

// Mask in display
<p>Email: {maskEmail(user.email)}</p>

// Handle errors securely
try {
  await operation();
} catch (error) {
  toast.error(getUserFriendlyError(error));  // User-friendly Indonesian message
  logError('Context', error);  // Only logs in development
}
```

**Use masked queries:**
```typescript
import { getUserBookingsWithMasking } from '@/utils/supabaseHelpers';

// Auto-masks emails/phones for non-admin users
const bookings = await getUserBookingsWithMasking(userId, !isAdmin);
```

### Error Handling
- **Production:** Generic error messages only (no stack traces)
- **Development:** Full error details for debugging
- **Never expose:** Database structure, API keys, internal IDs, stack traces

### Security Headers
All configured in `vercel.json`:
- ✅ X-Frame-Options: DENY (prevents clickjacking)
- ✅ X-Content-Type-Options: nosniff (prevents MIME sniffing)
- ✅ X-XSS-Protection: enabled
- ✅ Content-Security-Policy: restricts resource loading
- ✅ CORS: restricted to trusted origins only

**Docs:** `docs/SECURITY_FIXES_2025-11-03.md`, `docs/SECURITY_USAGE_EXAMPLES.md`

## Documentation References
- **Setup:** `docs/QUICK_START.md`, `docs/SUPABASE_SETUP.md`
- **Admin:** `docs/ADMIN_DASHBOARD.md`, `docs/ADMIN_TESTING_GUIDE.md`
- **APIs:** `docs/EXTERNAL_APIS.md`, `docs/MIDTRANS_INTEGRATION.md`
- **ML:** `docs/ML_PIPELINE.md`, `docs/ML_IMPLEMENTATION_SUMMARY.md`
- **Features:** `docs/GUEST_MODE.md`, `docs/MULTI_LANGUAGE.md`, `docs/BOOKING_REFUND_SYSTEM.md`
- **Deployment:** `docs/DEPLOY_VERCEL.md`

## Key Design Decisions

### Why Bun over npm?
Faster installation (2-3x speedup) but npm still supported. Use `bun install && bun run dev`.

### Why OpenRouteService instead of Google Maps?
Free tier: 2,000 req/day vs 200 req/day. Easy upgrade path if needed. Good Indonesia coverage.

### Why in-memory cache over Redis?
Simplicity for MVP. 70% hit rate in testing. Lost on restart is acceptable. Production upgrade path documented.

### Why TensorFlow.js over server-side ML?
Browser-side inference = no ML server costs. Model is small (< 1MB). Fallback to rule-based ensures reliability.

### Why shadcn/ui?
Copy-paste components (no package bloat), full Tailwind control, excellent TypeScript support, Radix UI accessibility.

### Why guest mode instead of forced login?
Lower friction for exploration. Convert to signup only when needed (booking, planning). Guest banner prompts registration.

---

**Built by:** Sabilillah Ramaniya Widodo (sblrm) & Ryan Hanif Dwihandoyo (Rayen142)  
**Last Updated:** October 31, 2025  
**Version:** 2.0
