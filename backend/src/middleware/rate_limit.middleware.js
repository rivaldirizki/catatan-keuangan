// In-memory sliding window rate limiter middleware
const requestCounts = new Map();

/**
 * Creates an in-memory rate limiter middleware.
 * @param {Object} options
 * @param {number} options.windowMs - Time window in milliseconds (default: 15 min)
 * @param {number} options.max - Max requests per IP in the window (default: 15)
 * @param {string} options.message - Error message returned on 429
 */
export function rateLimiter({ windowMs = 15 * 60 * 1000, max = 15, message = 'Terlalu banyak permintaan. Silakan coba lagi beberapa saat lagi.' } = {}) {
  return (req, res, next) => {
    // Skip rate limiting in test environment
    if (process.env.NODE_ENV === 'test' || process.argv.some(a => a.includes('tests') || a.includes('--test'))) {
      return next();
    }

    const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress || 'unknown';
    const key = `${req.baseUrl || ''}${req.path}_${ip}`;
    const now = Date.now();

    const record = requestCounts.get(key) || { count: 0, resetTime: now + windowMs };

    if (now > record.resetTime) {
      record.count = 1;
      record.resetTime = now + windowMs;
    } else {
      record.count += 1;
    }

    requestCounts.set(key, record);

    if (record.count > max) {
      const retryAfter = Math.ceil((record.resetTime - now) / 1000);
      res.setHeader('Retry-After', retryAfter);
      return res.status(429).json({
        error: message,
        retry_after_seconds: retryAfter
      });
    }

    next();
  };
}
