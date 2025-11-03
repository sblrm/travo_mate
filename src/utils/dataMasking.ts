/**
 * Data Masking Utilities
 * 
 * Provides functions to mask sensitive data (emails, phone numbers) 
 * for display purposes to prevent sensitive data exposure.
 */

/**
 * Mask email address
 * Example: john.doe@example.com -> j***e@e***e.com
 */
export function maskEmail(email: string): string {
  if (!email || typeof email !== 'string') return '';
  
  const [localPart, domain] = email.split('@');
  if (!localPart || !domain) return email;
  
  // Mask local part (keep first and last character)
  const maskedLocal = localPart.length > 2
    ? `${localPart[0]}${'*'.repeat(Math.min(localPart.length - 2, 3))}${localPart[localPart.length - 1]}`
    : '*'.repeat(localPart.length);
  
  // Mask domain (keep first character and TLD)
  const domainParts = domain.split('.');
  const maskedDomainName = domainParts[0].length > 1
    ? `${domainParts[0][0]}${'*'.repeat(Math.min(domainParts[0].length - 1, 3))}`
    : domainParts[0];
  
  const maskedDomain = [maskedDomainName, ...domainParts.slice(1)].join('.');
  
  return `${maskedLocal}@${maskedDomain}`;
}

/**
 * Mask phone number
 * Example: +6281234567890 -> +62812****7890
 * Example: 081234567890 -> 0812****7890
 */
export function maskPhoneNumber(phone: string): string {
  if (!phone || typeof phone !== 'string') return '';
  
  // Remove all non-digit characters except leading +
  const cleaned = phone.replace(/[^\d+]/g, '');
  
  if (cleaned.length < 8) return phone; // Too short to mask meaningfully
  
  // Keep country code + first 3-4 digits and last 4 digits
  const hasCountryCode = cleaned.startsWith('+');
  const keepStart = hasCountryCode ? 7 : 4; // +62812 or 0812
  const keepEnd = 4;
  
  if (cleaned.length <= keepStart + keepEnd) {
    // Short number, mask middle only
    const middle = Math.floor((cleaned.length - 2) / 2);
    return cleaned.slice(0, middle) + '****' + cleaned.slice(-Math.min(4, cleaned.length - middle));
  }
  
  const start = cleaned.slice(0, keepStart);
  const end = cleaned.slice(-keepEnd);
  const maskLength = Math.min(cleaned.length - keepStart - keepEnd, 4);
  
  return `${start}${'*'.repeat(maskLength)}${end}`;
}

/**
 * Mask credit card number (for future use)
 * Example: 4111111111111111 -> 4111 **** **** 1111
 */
export function maskCreditCard(cardNumber: string): string {
  if (!cardNumber || typeof cardNumber !== 'string') return '';
  
  const cleaned = cardNumber.replace(/\D/g, '');
  if (cleaned.length < 13) return cardNumber;
  
  const first4 = cleaned.slice(0, 4);
  const last4 = cleaned.slice(-4);
  
  return `${first4} **** **** ${last4}`;
}

/**
 * Mask generic string (keep first and last characters)
 * Example: "secrettoken123" -> "s***3"
 */
export function maskString(str: string, visibleChars: number = 1): string {
  if (!str || typeof str !== 'string') return '';
  if (str.length <= visibleChars * 2) return '*'.repeat(str.length);
  
  const start = str.slice(0, visibleChars);
  const end = str.slice(-visibleChars);
  const maskLength = Math.min(str.length - visibleChars * 2, 3);
  
  return `${start}${'*'.repeat(maskLength)}${end}`;
}

/**
 * Check if email should be masked
 * Admin users may see unmasked emails, others see masked
 */
export function shouldMaskEmail(userRole?: string): boolean {
  return userRole !== 'admin' && userRole !== 'superadmin';
}

/**
 * Mask object fields containing sensitive data
 */
export function maskSensitiveFields<T extends Record<string, any>>(
  obj: T,
  fieldsToMask: Array<keyof T>,
  maskFn: (value: any) => string = maskString
): T {
  const masked = { ...obj };
  
  fieldsToMask.forEach(field => {
    if (masked[field]) {
      masked[field] = maskFn(masked[field]);
    }
  });
  
  return masked;
}

/**
 * Remove sensitive fields from error responses
 */
export function sanitizeError(error: any): any {
  if (!error) return error;
  
  // Create a safe error object without sensitive data
  const safeError: any = {
    message: error.message || 'An error occurred',
    code: error.code,
    status: error.status || error.statusCode
  };
  
  // Remove stack traces in production
  if (process.env.NODE_ENV === 'production') {
    delete safeError.stack;
  }
  
  // Remove sensitive fields
  const sensitiveFields = [
    'password',
    'token',
    'apiKey',
    'secret',
    'auth',
    'credentials',
    'authorization',
    'cookie',
    'session'
  ];
  
  Object.keys(error).forEach(key => {
    const lowerKey = key.toLowerCase();
    if (!sensitiveFields.some(field => lowerKey.includes(field))) {
      if (key !== 'stack' || process.env.NODE_ENV !== 'production') {
        safeError[key] = error[key];
      }
    }
  });
  
  return safeError;
}

/**
 * Mask multiple emails in a string
 */
export function maskEmailsInText(text: string): string {
  const emailRegex = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/g;
  return text.replace(emailRegex, (email) => maskEmail(email));
}

/**
 * Mask multiple phone numbers in a string
 */
export function maskPhoneNumbersInText(text: string): string {
  // Match international and local phone numbers
  const phoneRegex = /(\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4,}/g;
  return text.replace(phoneRegex, (phone) => maskPhoneNumber(phone));
}
