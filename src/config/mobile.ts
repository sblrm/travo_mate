// Mobile configuration for Capacitor
// These values are bundled into the app, so use public keys only

export const MOBILE_CONFIG = {
  supabase: {
    url: import.meta.env.VITE_SUPABASE_URL || '',
    anonKey: import.meta.env.VITE_SUPABASE_ANON_KEY || '',
  },
  gemini: {
    apiKey: import.meta.env.VITE_GEMINI_API_KEY || '',
  },
  midtrans: {
    clientKey: import.meta.env.VITE_MIDTRANS_CLIENT_KEY || '',
    environment: import.meta.env.VITE_MIDTRANS_ENVIRONMENT || 'sandbox',
  },
  isMobile: false, // Will be set by Capacitor detection
};

// Auto-detect if running in Capacitor
if (typeof window !== 'undefined' && (window as any).Capacitor) {
  MOBILE_CONFIG.isMobile = true;
}
