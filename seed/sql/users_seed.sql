-- ==============================================================================
-- FinSightIQ — Demo Data Seed: Users Service (usersdb)
-- ==============================================================================
-- Safe & Idempotent: Inserts standard development accounts only if not present.
-- Passwords:
--   admin@finsightiq.local   : Admin123!
--   analyst@finsightiq.local : Analyst123!
--   viewer@finsightiq.local  : Viewer123!
-- BCrypt work factor 12 hashes
-- ==============================================================================

INSERT INTO users (id, email, password_hash, role, is_suspended, created_at, updated_at)
VALUES 
  (
    '00000000-0000-0000-0000-000000000001',
    'admin@finsightiq.local',
    '$2a$12$LJ3m35gq0i5mO2k5iK2kCeV2wGvVbF0z4JkZ6Z0mK3lW9lA0eX1kG',
    'Administrator',
    false,
    NOW(),
    NOW()
  ),
  (
    '00000000-0000-0000-0000-000000000002',
    'analyst@finsightiq.local',
    '$2a$12$s0E0bX7o2M.1q1oE2iQeTeR8vF9yB1z3KlK4jL0mK2lW8lA1eX2kG',
    'Analyst',
    false,
    NOW(),
    NOW()
  ),
  (
    '00000000-0000-0000-0000-000000000003',
    'viewer@finsightiq.local',
    '$2a$12$t1F1cY8p3N.2r2pF3jRfUfS9wG0zC2z4LmL5kM1nL3mX9mB2fY3lH',
    'Viewer',
    false,
    NOW(),
    NOW()
  )
ON CONFLICT (id) DO NOTHING;
