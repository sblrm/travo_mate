/**
 * Error Sanitization Utilities
 * 
 * Prevents sensitive information from being exposed in error messages
 * to the client-side or in production environments.
 */

/**
 * Sanitize error for client display
 * Removes stack traces, sensitive fields, and internal details
 */
export function sanitizeError(error: any): { message: string; code?: string } {
  if (!error) {
    return { message: 'An unexpected error occurred' };
  }

  // If it's already a simple string, return it
  if (typeof error === 'string') {
    return { message: error };
  }

  // Extract safe error information
  const safeError: { message: string; code?: string } = {
    message: error.message || error.msg || 'An error occurred',
  };

  // Include error code if available (non-sensitive)
  if (error.code && typeof error.code === 'string') {
    safeError.code = error.code;
  }

  return safeError;
}

/**
 * Check if we're in production mode
 */
export function isProduction(): boolean {
  return import.meta.env.PROD || import.meta.env.MODE === 'production';
}

/**
 * Conditionally log errors (only in development)
 */
export function logError(context: string, error: any): void {
  if (!isProduction()) {
    console.error(`[${context}]`, error);
  }
}

/**
 * Create user-friendly error messages
 */
export function getUserFriendlyError(error: any): string {
  // Network errors
  if (error.message?.includes('Failed to fetch') || error.message?.includes('Network')) {
    return 'Koneksi jaringan bermasalah. Silakan coba lagi.';
  }

  // Authentication errors
  if (error.code === 'auth/invalid-email' || error.message?.includes('Invalid login')) {
    return 'Email atau password salah.';
  }

  if (error.code === 'auth/user-not-found') {
    return 'Akun tidak ditemukan.';
  }

  if (error.code === 'auth/wrong-password') {
    return 'Password salah.';
  }

  if (error.code === 'auth/email-already-in-use') {
    return 'Email sudah terdaftar.';
  }

  // Database errors
  if (error.message?.includes('unique constraint') || error.code === '23505') {
    return 'Data sudah ada. Silakan gunakan data yang berbeda.';
  }

  if (error.message?.includes('foreign key constraint') || error.code === '23503') {
    return 'Data terkait tidak valid.';
  }

  if (error.message?.includes('not found') || error.code === 'PGRST116') {
    return 'Data tidak ditemukan.';
  }

  // Payment errors
  if (error.message?.includes('payment') || error.message?.includes('transaction')) {
    return 'Pembayaran gagal. Silakan coba lagi atau hubungi support.';
  }

  // Permission errors
  if (error.message?.includes('permission') || error.message?.includes('unauthorized') || error.code === 'PGRST301') {
    return 'Anda tidak memiliki akses untuk melakukan aksi ini.';
  }

  // Timeout errors
  if (error.message?.includes('timeout') || error.code === 'ETIMEDOUT') {
    return 'Permintaan memakan waktu terlalu lama. Silakan coba lagi.';
  }

  // Rate limit errors
  if (error.status === 429 || error.message?.includes('rate limit')) {
    return 'Terlalu banyak percobaan. Silakan tunggu beberapa saat.';
  }

  // Default fallback
  return isProduction() 
    ? 'Terjadi kesalahan. Silakan coba lagi.'
    : error.message || 'Unknown error';
}

/**
 * Wrap async functions with error sanitization
 */
export function withErrorSanitization<T extends (...args: any[]) => Promise<any>>(
  fn: T,
  context: string
): T {
  return (async (...args: Parameters<T>) => {
    try {
      return await fn(...args);
    } catch (error) {
      logError(context, error);
      throw sanitizeError(error);
    }
  }) as T;
}
