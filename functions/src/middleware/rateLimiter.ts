import { HttpsError } from "firebase-functions/v2/https";

interface RateLimitData {
  count: number;
  windowStart: number;
}

const rateLimits = new Map<string, RateLimitData>();

// Cleanup routine to prevent memory leaks (runs occasionally on invocations)
let lastCleanup = Date.now();
function cleanupRateLimits() {
  const now = Date.now();
  if (now - lastCleanup > 60 * 60 * 1000) { // Every hour
    for (const [key, data] of rateLimits.entries()) {
      if (now - data.windowStart > 60 * 60 * 1000) {
        rateLimits.delete(key);
      }
    }
    lastCleanup = now;
  }
}

export async function rateLimitCheck(
  ip: string,
  action: string,
  maxRequests: number = 5,
  windowMinutes: number = 15
): Promise<void> {
  cleanupRateLimits();
  
  const identifier = ip || "unknown";
  const key = `${action}_${identifier}`;
  const now = Date.now();
  
  let data = rateLimits.get(key);
  
  if (data) {
    if (now - data.windowStart > windowMinutes * 60 * 1000) {
      data = { count: 1, windowStart: now };
    } else {
      if (data.count >= maxRequests) {
        throw new HttpsError("resource-exhausted", `Too many requests for ${action}. Try again later.`);
      }
      data.count += 1;
    }
  } else {
    data = { count: 1, windowStart: now };
  }
  
  rateLimits.set(key, data);
}
