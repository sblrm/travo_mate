# 🔒 Security Quick Reference

## 🎯 At a Glance

### Fixed Vulnerabilities
- ✅ **Information Disclosure** (HIGH) - Sanitized errors, removed stack traces
- ✅ **Sensitive Data Exposure** (HIGH) - Masked emails/phones automatically  
- ✅ **CORS Misconfiguration** (MEDIUM) - Restricted to trusted origins
- ✅ **Missing Security Headers** (LOW) - Added CSP, X-Frame-Options, etc.

---

## 🛡️ Security Features

### 1. Data Masking (Auto-applied)
```typescript
// Emails: john.doe@example.com → j***e@e***e.com
// Phones: +6281234567890 → +62812****7890
// Tokens: secrettoken123 → s***3
```

### 2. Error Sanitization
```typescript
// Production: "Terjadi kesalahan. Silakan coba lagi."
// Development: Full error details for debugging
// NEVER: Stack traces, API keys, database structure
```

### 3. CORS Protection
```typescript
// ✅ Allowed: https://travo-mate.vercel.app
// ✅ Allowed: http://localhost:8080 (dev only)
// ❌ Blocked: All other origins
```

### 4. Security Headers
```
X-Frame-Options: DENY
X-Content-Type-Options: nosniff
X-XSS-Protection: 1; mode=block
Content-Security-Policy: (strict)
```

---

## 🔧 Common Usage

### Display Masked Data
```tsx
import { maskEmail, maskPhoneNumber } from '@/utils/dataMasking';

<p>Email: {maskEmail(user.email)}</p>
<p>Phone: {maskPhoneNumber(booking.phone)}</p>
```

### Handle Errors Safely
```typescript
import { getUserFriendlyError, logError } from '@/utils/errorSanitization';

try {
  await operation();
} catch (error) {
  toast.error(getUserFriendlyError(error));  // Indonesian message
  logError('Context', error);  // Dev only
}
```

### Fetch Masked Data
```typescript
import { getUserBookingsWithMasking } from '@/utils/supabaseHelpers';

// Auto-masks for non-admin users
const bookings = await getUserBookingsWithMasking(userId, !isAdmin);
```

---

## ⚙️ Configuration

### Environment Variables
```bash
# Vercel Environment Variables
APP_URL=https://travo-mate.vercel.app  # For CORS
NODE_ENV=production                    # Enables security
```

### CORS Allowed Origins
Edit `api/midtrans.ts` and `api/gemini.ts`:
```typescript
const allowedOrigins = [
  'https://travo-mate.vercel.app',
  'https://your-custom-domain.com',  // Add your domain here
];
```

---

## 🧪 Testing

### Check Security Headers
```bash
curl -I https://travo-mate.vercel.app
```

### Test Data Masking
```typescript
// Browser console
import { maskEmail } from '@/utils/dataMasking';
maskEmail('test@example.com');  // → t***t@e***e.com
```

### Test CORS
```bash
# Should FAIL
curl -H "Origin: https://evil.com" https://travo-mate.vercel.app/api/midtrans

# Should SUCCEED  
curl -H "Origin: https://travo-mate.vercel.app" https://travo-mate.vercel.app/api/midtrans
```

---

## 📋 Pre-Deployment Checklist

- [ ] All secrets use correct env var naming (no VITE_ for server keys)
- [ ] CORS allowedOrigins includes production domain
- [ ] Security headers configured in vercel.json
- [ ] Data masking applied to user-facing components
- [ ] Error messages use getUserFriendlyError()
- [ ] Console.log wrapped with logError() or NODE_ENV check
- [ ] Test locally: `bun run dev`
- [ ] Build succeeds: `bun run build`
- [ ] Deploy to Vercel
- [ ] Run security scan to verify

---

## 🆘 Troubleshooting

| Issue | Solution |
|-------|----------|
| CORS errors | Check APP_URL in Vercel env vars |
| Data not masked | Verify `isAdmin()` function works |
| Errors still show stack traces | Check NODE_ENV=production |
| CSP violations | Add domain to vercel.json CSP |

---

## 📚 Full Documentation

- **Complete Guide:** `docs/SECURITY_FIXES_2025-11-03.md`
- **Code Examples:** `docs/SECURITY_USAGE_EXAMPLES.md`
- **AI Instructions:** `.github/copilot-instructions.md`

---

**Last Updated:** November 3, 2025  
**Status:** Production Ready ✅
