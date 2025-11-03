/**
 * Supabase Query Helpers with Data Masking
 * 
 * Wrapper functions that automatically mask sensitive data
 * when fetching from Supabase tables.
 */

import { supabase } from '@/lib/supabase';
import { maskEmail, maskPhoneNumber } from './dataMasking';

/**
 * Get user bookings with masked personal data
 */
export async function getUserBookingsWithMasking(userId: string, maskData: boolean = true) {
  const { data, error } = await supabase
    .from('bookings')
    .select(`
      *,
      destinations!destination_id (
        id,
        name,
        city,
        province,
        image,
        price
      ),
      transactions!transaction_id (
        order_id,
        payment_type,
        transaction_status
      )
    `)
    .eq('user_id', userId)
    .in('status', ['pending_payment', 'paid', 'confirmed'])
    .order('visit_date', { ascending: true });

  if (error) throw error;

  // Mask sensitive data if requested
  if (maskData && data) {
    return data.map(booking => ({
      ...booking,
      booking_email: booking.booking_email ? maskEmail(booking.booking_email) : undefined,
      booking_phone: booking.booking_phone ? maskPhoneNumber(booking.booking_phone) : undefined,
    }));
  }

  return data || [];
}

/**
 * Get user profile with masked email for non-admin views
 */
export async function getUserProfileWithMasking(userId: string, isAdmin: boolean = false) {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .single();

  if (error) throw error;
  if (!data) return null;

  // Mask email for non-admin users
  if (!isAdmin && data.email) {
    return {
      ...data,
      email: maskEmail(data.email),
    };
  }

  return data;
}

/**
 * Mask booking data before displaying in public contexts
 */
export function maskBookingData(booking: any) {
  return {
    ...booking,
    booking_email: booking.booking_email ? maskEmail(booking.booking_email) : undefined,
    booking_phone: booking.booking_phone ? maskPhoneNumber(booking.booking_phone) : undefined,
    // Keep only last 4 digits of booking code
    booking_code: booking.booking_code ? '***' + booking.booking_code.slice(-4) : undefined,
  };
}

/**
 * Mask transaction data
 */
export function maskTransactionData(transaction: any) {
  return {
    ...transaction,
    // Mask order ID (keep last 4 characters)
    order_id: transaction.order_id ? '***' + transaction.order_id.slice(-4) : undefined,
    // Remove sensitive payment details
    midtrans_response: undefined,
    customer_details: transaction.customer_details ? {
      ...transaction.customer_details,
      email: maskEmail(transaction.customer_details.email),
      phone: maskPhoneNumber(transaction.customer_details.phone),
    } : undefined,
  };
}
