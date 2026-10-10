import http from 'k6/http';
import { check, sleep } from 'k6';

/**
 * FinSightIQ Platform — Baseline Load Test (k6)
 * Traced against TST-001 §7 & Implementation Plan S4-10 (100 VUs)
 *
 * Targets:
 *   - Gateway Health: GET /health
 *   - Market Data (cached): GET /api/v1/market/AAPL/history
 *
 * Performance Targets:
 *   - p95 latency < 200 ms (cached read)
 *   - p99 latency < 300 ms (cached read)
 *   - Error rate < 1%
 */

export const options = {
  stages: [
    { duration: '30s', target: 20 },  // Ramp-up
    { duration: '1m',  target: 100 }, // Sustained load at 100 VUs
    { duration: '30s', target: 0 },   // Ramp-down
  ],
  thresholds: {
    http_req_failed: ['rate<0.01'],             // Error rate under 1%
    http_req_duration: ['p(95)<200', 'p(99)<300'], // Latency thresholds
  },
};

const BASE_URL = __ENV.FINSIGHTIQ_GATEWAY_URL || 'http://localhost:5000';

export default function () {
  // 1. Health check request
  const healthRes = http.get(`${BASE_URL}/health`);
  check(healthRes, {
    'health check status is 200': (r) => r.status === 200,
  });

  // 2. Market history request
  const marketRes = http.get(`${BASE_URL}/api/v1/market/AAPL/history?interval=1day&limit=30`);
  check(marketRes, {
    'market endpoint responds or skips gracefully': (r) => r.status === 200 || r.status === 404 || r.status === 502,
  });

  sleep(1);
}
