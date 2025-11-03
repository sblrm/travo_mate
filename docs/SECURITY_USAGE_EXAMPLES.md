# 🔒 Security Utilities - Usage Examples

## Quick Reference

### 1. Data Masking

```typescript
import { 
  maskEmail, 
  maskPhoneNumber, 
  maskString 
} from '@/utils/dataMasking';

// Email masking
const email = "john.doe@example.com";
const masked = maskEmail(email);  // → "j***e@e***e.com"

// Phone masking
const phone = "+6281234567890";
const maskedPhone = maskPhoneNumber(phone);  // → "+62812****7890"

// Generic string masking
const token = "secrettoken123";
const maskedToken = maskString(token, 2);  // → "se***23"
```

### 2. Error Sanitization

```typescript
import { 
  getUserFriendlyError, 
  sanitizeError,
  logError 
} from '@/utils/errorSanitization';

// Display user-friendly errors
try {
  await supabase.from('bookings').insert(data);
} catch (error) {
  // Automatically translates technical errors to Indonesian
  const friendlyMessage = getUserFriendlyError(error);
  toast.error(friendlyMessage);  // Shows: "Terjadi kesalahan. Silakan coba lagi."
  
  // Log full error in development only
  logError('BookingCreation', error);
}

// Sanitize errors before sending to API
catch (error) {
  const safeError = sanitizeError(error);
  // safeError doesn't contain stack traces or sensitive fields
  reportToMonitoring(safeError);
}
```

### 3. Masked Supabase Queries

```typescript
import { 
  getUserBookingsWithMasking,
  maskBookingData,
  maskTransactionData 
} from '@/utils/supabaseHelpers';

// Get bookings with auto-masked emails and phones
const bookings = await getUserBookingsWithMasking(userId, true);

// Manually mask booking data
const booking = await supabase.from('bookings').select('*').eq('id', bookingId).single();
const maskedBooking = maskBookingData(booking.data);

// Mask transaction data before display
const transaction = await getTransaction(orderId);
const maskedTx = maskTransactionData(transaction);
```

---

## Real-World Examples

### Example 1: Booking List Component

```typescript
// Before (Insecure ❌)
export function MyBookings() {
  const { user } = useAuth();
  const [bookings, setBookings] = useState([]);

  useEffect(() => {
    const fetchBookings = async () => {
      const { data } = await supabase
        .from('bookings')
        .select('*')
        .eq('user_id', user.id);
      
      setBookings(data);  // Exposes full email & phone!
    };
    fetchBookings();
  }, [user]);

  return (
    <div>
      {bookings.map(booking => (
        <div key={booking.id}>
          <p>Email: {booking.booking_email}</p>  {/* ❌ Exposed */}
          <p>Phone: {booking.booking_phone}</p>  {/* ❌ Exposed */}
        </div>
      ))}
    </div>
  );
}

// After (Secure ✅)
import { getUserBookingsWithMasking } from '@/utils/supabaseHelpers';
import { isAdmin } from '@/services/adminService';

export function MyBookings() {
  const { user } = useAuth();
  const [bookings, setBookings] = useState([]);
  const [isAdminUser, setIsAdminUser] = useState(false);

  useEffect(() => {
    const fetchBookings = async () => {
      const adminStatus = await isAdmin();
      setIsAdminUser(adminStatus);
      
      // Auto-masks for non-admin, unmasked for admin
      const data = await getUserBookingsWithMasking(user.id, !adminStatus);
      setBookings(data);
    };
    fetchBookings();
  }, [user]);

  return (
    <div>
      {bookings.map(booking => (
        <div key={booking.id}>
          <p>Email: {booking.booking_email}</p>  {/* ✅ Masked: j***e@e***e.com */}
          <p>Phone: {booking.booking_phone}</p>  {/* ✅ Masked: +62812****7890 */}
        </div>
      ))}
    </div>
  );
}
```

### Example 2: Error Handling in Forms

```typescript
// Before (Insecure ❌)
async function handleSubmit(formData) {
  try {
    await createBooking(formData);
    toast.success('Booking created!');
  } catch (error) {
    // Exposes database errors to user!
    toast.error(error.message);  // ❌ Shows: "duplicate key value violates unique constraint..."
    console.error(error);  // ❌ Logs full stack trace
  }
}

// After (Secure ✅)
import { getUserFriendlyError, logError } from '@/utils/errorSanitization';

async function handleSubmit(formData) {
  try {
    await createBooking(formData);
    toast.success('Booking created!');
  } catch (error) {
    // Shows user-friendly message
    const friendlyMsg = getUserFriendlyError(error);
    toast.error(friendlyMsg);  // ✅ Shows: "Data sudah ada. Silakan gunakan data yang berbeda."
    
    // Logs only in development
    logError('BookingForm', error);  // ✅ Only logs in dev mode
  }
}
```

### Example 3: Admin Dashboard with Conditional Masking

```typescript
import { maskEmail, maskPhoneNumber, shouldMaskEmail } from '@/utils/dataMasking';
import { useAuth } from '@/contexts/AuthContext';

export function AdminBookingsList() {
  const { user } = useAuth();
  const [bookings, setBookings] = useState([]);
  const [userRole, setUserRole] = useState('user');

  useEffect(() => {
    // Determine if current user is admin
    const checkRole = async () => {
      const { data } = await supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .single();
      
      setUserRole(data?.role || 'user');
    };
    checkRole();
  }, [user]);

  const shouldMask = shouldMaskEmail(userRole);

  return (
    <table>
      <tbody>
        {bookings.map(booking => (
          <tr key={booking.id}>
            <td>
              {shouldMask 
                ? maskEmail(booking.booking_email)
                : booking.booking_email}
            </td>
            <td>
              {shouldMask 
                ? maskPhoneNumber(booking.booking_phone)
                : booking.booking_phone}
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
```

### Example 4: API Response Sanitization

```typescript
// In your API route (e.g., api/booking.ts)
import { VercelRequest, VercelResponse } from '@vercel/node';

export default async function handler(req: VercelRequest, res: VercelResponse) {
  try {
    const result = await createBooking(req.body);
    
    // Remove sensitive fields before sending response
    const safeResult = {
      id: result.id,
      booking_code: result.booking_code,
      status: result.status,
      // Don't send: user_id, internal_notes, etc.
    };
    
    return res.status(200).json(safeResult);
    
  } catch (error: any) {
    // Sanitize error before sending
    const safeError = {
      message: process.env.NODE_ENV === 'production' 
        ? 'An error occurred' 
        : error.message,
      code: error.code  // Safe to expose
    };
    
    // Don't include: error.stack, error.details, error.hint
    return res.status(500).json(safeError);
  }
}
```

---

## Integration with Existing Features

### With i18next Translation

```typescript
import { useTranslation } from 'react-i18next';
import { getUserFriendlyError } from '@/utils/errorSanitization';

function BookingComponent() {
  const { t } = useTranslation();
  
  const handleError = (error: any) => {
    // Get Indonesian error message
    const friendlyMsg = getUserFriendlyError(error);
    
    // Combine with translations if needed
    toast.error(t('errors.booking') + ': ' + friendlyMsg);
  };
}
```

### With Admin Dashboard

```typescript
// src/pages/admin/AdminDashboard.tsx
import { maskEmail, maskPhoneNumber } from '@/utils/dataMasking';
import { isAdmin } from '@/services/adminService';

export default function AdminDashboard() {
  const [isAdminUser, setIsAdminUser] = useState(false);
  
  useEffect(() => {
    const checkAdmin = async () => {
      const status = await isAdmin();
      setIsAdminUser(status);
    };
    checkAdmin();
  }, []);
  
  // Admin sees unmasked data, others see masked
  const displayEmail = (email: string) => {
    return isAdminUser ? email : maskEmail(email);
  };
}
```

---

## Testing Your Implementation

### Unit Tests (with Vitest)

```typescript
import { describe, it, expect } from 'vitest';
import { maskEmail, maskPhoneNumber } from '@/utils/dataMasking';

describe('Data Masking', () => {
  it('should mask email correctly', () => {
    expect(maskEmail('john.doe@example.com')).toBe('j***e@e***e.com');
  });
  
  it('should mask phone correctly', () => {
    expect(maskPhoneNumber('+6281234567890')).toBe('+62812****7890');
  });
  
  it('should handle short emails', () => {
    expect(maskEmail('a@b.com')).toBe('*@b.com');
  });
});
```

### Manual Testing Checklist

- [ ] Display user profile - email should be masked
- [ ] Display booking list - phones should be masked
- [ ] Admin login - should see unmasked data
- [ ] Trigger form error - should show Indonesian message
- [ ] Check browser console - no stack traces in production
- [ ] Check API responses - no sensitive data exposed
- [ ] Test CORS - unauthorized origin should fail

---

## Performance Considerations

### ✅ Good Practices

```typescript
// Mask once when data is fetched
const bookings = await getUserBookingsWithMasking(userId);  // Masked once
setBookings(bookings);

// Display without re-masking
{bookings.map(b => <div>{b.booking_email}</div>)}
```

### ❌ Avoid

```typescript
// Don't mask on every render
{bookings.map(b => (
  <div>{maskEmail(b.booking_email)}</div>  // ❌ Masks repeatedly
))}
```

---

## Security Checklist

Before deploying to production:

- [ ] All user emails are masked in non-admin views
- [ ] All phone numbers are masked
- [ ] Error messages don't contain stack traces
- [ ] API responses don't expose internal IDs
- [ ] CORS is restricted to trusted origins
- [ ] Security headers are configured in vercel.json
- [ ] Environment variables don't have VITE_ prefix for secrets
- [ ] Console.log statements are removed or wrapped with NODE_ENV check

---

**Need help?** Check `docs/SECURITY_FIXES_2025-11-03.md` for full documentation.
