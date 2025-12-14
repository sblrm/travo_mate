import { createRoot } from 'react-dom/client'
import App from './App.tsx'
import './index.css'
import './i18n/config'

// Request permissions for mobile app
const requestMobilePermissions = async () => {
  // Check if running in Capacitor
  if (typeof window !== 'undefined' && (window as any).Capacitor) {
    try {
      // Request location permissions
      const { Geolocation } = await import('@capacitor/geolocation');
      await Geolocation.requestPermissions();
      console.log('✓ Location permissions granted');
    } catch (error) {
      console.warn('Location permissions:', error);
    }
  }
};

// Request permissions before rendering
requestMobilePermissions();

createRoot(document.getElementById("root")!).render(<App />);
