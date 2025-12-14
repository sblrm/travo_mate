import { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.travomate.app',
  appName: 'TravoMate',
  webDir: 'dist',
  server: {
    androidScheme: 'https',
    iosScheme: 'https',
    // For development, you can use your local IP
    // url: 'http://192.168.1.100:8080',
    // cleartext: true
  },
  plugins: {
    SplashScreen: {
      launchShowDuration: 2000,
      backgroundColor: '#3B82F6',
      androidSplashResourceName: 'splash',
      androidScaleType: 'CENTER_CROP',
      showSpinner: false,
      androidSpinnerStyle: 'large',
      iosSpinnerStyle: 'small',
      spinnerColor: '#ffffff',
      splashFullScreen: true,
      splashImmersive: true,
    },
    PushNotifications: {
      presentationOptions: ['badge', 'sound', 'alert'],
    },
    Geolocation: {
      // Request permissions automatically
    },
    StatusBar: {
      style: 'light',
      backgroundColor: '#3B82F6',
    },
  },
};

export default config;
