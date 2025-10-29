// ========================================
// PRODUCTION SECURITY: Debug Mode Control
// ========================================
// Add this code to index.html after Supabase client initialization
// Location: Right after line ~1410 (after: const supabase = createClient(...))
//
// Purpose: Control debug logging in production to prevent sensitive data leakage
// Usage:
//   - Development: Set DEBUG_MODE = true
//   - Production: Set DEBUG_MODE = false
//   - Auto-detect: Set DEBUG_MODE = location.hostname === 'localhost'
// ========================================

// Set to false in production to disable all debug logging
const DEBUG_MODE = false; // TODO: Change to false before production deployment

// Wrapped console methods - only log if DEBUG_MODE is true
const debugConsole = {
  log: (...args) => {
    if (DEBUG_MODE) console.log(...args);
  },
  error: (...args) => {
    if (DEBUG_MODE) console.error(...args);
  },
  warn: (...args) => {
    if (DEBUG_MODE) console.warn(...args);
  },
  info: (...args) => {
    if (DEBUG_MODE) console.info(...args);
  },
  debug: (...args) => {
    if (DEBUG_MODE) console.debug(...args);
  },
  table: (...args) => {
    if (DEBUG_MODE) console.table(...args);
  },

  // Production errors - always logged for monitoring
  // Use this for critical errors that need to be tracked
  production: (...args) => {
    console.error('[PRODUCTION ERROR]', new Date().toISOString(), ...args);

    // TODO: Integrate with error tracking service
    // Example with Sentry:
    // if (typeof Sentry !== 'undefined') {
    //   Sentry.captureException(args[0]);
    // }
  }
};

// SECURITY: In production, override console to prevent accidental logging
if (!DEBUG_MODE) {
  // Save references to original console methods
  const originalLog = console.log;
  const originalDebug = console.debug;
  const originalInfo = console.info;
  const originalWarn = console.warn;

  // Override console methods to be silent
  console.log = () => {};
  console.debug = () => {};
  console.info = () => {};
  console.warn = () => {};
  // Keep console.error for critical errors

  // Restore console for debugging if needed (in browser console, run: restoreConsole())
  window.restoreConsole = () => {
    console.log = originalLog;
    console.debug = originalDebug;
    console.info = originalInfo;
    console.warn = originalWarn;
    console.log('%c[DEBUG] Console restored for troubleshooting', 'color: orange; font-weight: bold');
  };

  // Log that debug mode is disabled
  console.error('[PRODUCTION MODE] Debug logging disabled. Run restoreConsole() to enable temporarily.');
}

// ========================================
// USAGE EXAMPLES
// ========================================

// Development/Debug logging (only shows if DEBUG_MODE = true)
// debugConsole.log('User logged in:', userId);
// debugConsole.error('Failed to fetch data:', error);
// debugConsole.table(matches);

// Production error logging (always logged, even in production)
// try {
//   // critical operation
// } catch (error) {
//   debugConsole.production('Critical error in loadMatches:', error);
// }

// ========================================
// RECOMMENDED REPLACEMENTS
// ========================================
// Replace these console.log patterns manually or with find & replace:
//
// BEFORE: console.log('Debug info', data);
// AFTER:  debugConsole.log('Debug info', data);
//
// BEFORE: console.error('Database error:', error);
// AFTER:  debugConsole.production('Database error:', error);  // If critical
// AFTER:  debugConsole.error('Database error:', error);       // If debug only
//
// ========================================
