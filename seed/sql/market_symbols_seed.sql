-- ==============================================================================
-- FinSightIQ — Demo Data Seed: Market Data Service (marketdb)
-- ==============================================================================
-- Seeds the 30 representative market symbols defined across sectors.
-- Safe & Idempotent: ON CONFLICT (symbol) DO NOTHING
-- ==============================================================================

INSERT INTO symbols (symbol, name, sector, exchange, is_active)
VALUES
  -- Technology
  ('AAPL',  'Apple Inc.',                     'Technology',             'NASDAQ', true),
  ('MSFT',  'Microsoft Corporation',          'Technology',             'NASDAQ', true),
  ('NVDA',  'NVIDIA Corporation',             'Technology',             'NASDAQ', true),
  ('AVGO',  'Broadcom Inc.',                  'Technology',             'NASDAQ', true),
  ('ORCL',  'Oracle Corporation',             'Technology',             'NYSE',   true),
  ('CRM',   'Salesforce, Inc.',               'Technology',             'NYSE',   true),
  ('AMD',   'Advanced Micro Devices, Inc.',   'Technology',             'NASDAQ', true),
  -- Communication Services
  ('GOOGL', 'Alphabet Inc. (Class A)',        'Communication Services', 'NASDAQ', true),
  ('META',  'Meta Platforms, Inc.',           'Communication Services', 'NASDAQ', true),
  ('NFLX',  'Netflix, Inc.',                  'Communication Services', 'NASDAQ', true),
  -- Consumer Discretionary
  ('AMZN',  'Amazon.com, Inc.',               'Consumer Discretionary', 'NASDAQ', true),
  ('TSLA',  'Tesla, Inc.',                    'Consumer Discretionary', 'NASDAQ', true),
  ('HD',    'The Home Depot, Inc.',           'Consumer Discretionary', 'NYSE',   true),
  ('MCD',   'McDonald''s Corporation',        'Consumer Discretionary', 'NYSE',   true),
  -- Financials
  ('JPM',   'JPMorgan Chase & Co.',           'Financials',             'NYSE',   true),
  ('V',     'Visa Inc.',                      'Financials',             'NYSE',   true),
  ('MA',    'Mastercard Incorporated',        'Financials',             'NYSE',   true),
  ('BAC',   'Bank of America Corporation',    'Financials',             'NYSE',   true),
  ('MS',    'Morgan Stanley',                 'Financials',             'NYSE',   true),
  -- Healthcare
  ('LLY',   'Eli Lilly and Company',          'Healthcare',             'NYSE',   true),
  ('JNJ',   'Johnson & Johnson',              'Healthcare',             'NYSE',   true),
  ('UNH',   'UnitedHealth Group Incorporated','Healthcare',             'NYSE',   true),
  ('ABBV',  'AbbVie Inc.',                    'Healthcare',             'NYSE',   true),
  -- Consumer Staples
  ('WMT',   'Walmart Inc.',                   'Consumer Staples',       'NYSE',   true),
  ('PG',    'The Procter & Gamble Company',   'Consumer Staples',       'NYSE',   true),
  ('COST',  'Costco Wholesale Corporation',   'Consumer Staples',       'NASDAQ', true),
  -- Energy
  ('XOM',   'Exxon Mobil Corporation',        'Energy',                 'NYSE',   true),
  ('CVX',   'Chevron Corporation',            'Energy',                 'NYSE',   true),
  -- Industrials
  ('CAT',   'Caterpillar Inc.',               'Industrials',            'NYSE',   true),
  ('GE',    'GE Aerospace',                   'Industrials',            'NYSE',   true)
ON CONFLICT (symbol) DO NOTHING;
