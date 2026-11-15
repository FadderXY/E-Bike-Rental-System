-- ============================================================
-- Smart Bike Rental App - GIU Software Engineering - Milestone 2
-- 03_seed_data.sql
-- Sample rows to prove the relationships work.
-- Run AFTER 01 and 02, on an empty database (IDs rely on SERIAL starting at 1).
-- All names, emails, coordinates and hashes are made up.
-- ============================================================

-- pricing_plans (1 row)
INSERT INTO pricing_plans
    (name, unlock_fee, per_minute_rate, reduced_per_minute_rate, restricted_zone_penalty, card_activation_fee, is_active)
VALUES
    ('Standard', 5.00, 1.50, 0.75, 20.00, 5.00, TRUE);

-- users: 1 company, 2 admin, 3-5 riders
-- (user 5 is 12 years old and not yet verified: the youngest allowed age, US-004)
INSERT INTO users
    (full_name, email, password_hash, date_of_birth, device_serial, role, id_document_type, age_verified, wallet_balance)
VALUES
    ('GIU Bikes Company', 'company@example.com', 'hash_demo_1', '1990-01-01', 'SN-0001', 'company', 'national_id',       TRUE,  0.00),
    ('Admin Support',     'admin@example.com',   'hash_demo_2', '1992-05-12', 'SN-0002', 'admin',   'national_id',       TRUE,  0.00),
    ('Rider A',           'rider.a@example.com', 'hash_demo_3', '2004-03-20', 'SN-0003', 'rider',   'national_id',       TRUE,  0.00),
    ('Rider B',           'rider.b@example.com', 'hash_demo_4', '2005-07-08', 'SN-0004', 'rider',   'passport',          TRUE,  52.50),
    ('Rider C',           'rider.c@example.com', 'hash_demo_5', '2014-01-10', 'SN-0005', 'rider',   'birth_certificate', FALSE, 0.00);

-- cards
INSERT INTO cards (user_id, card_type, last_four, is_verified) VALUES
    (4, 'credit', '4242', TRUE),
    (3, 'debit',  '1111', FALSE);

-- zones: 2 green areas, 1 red restricted area
INSERT INTO zones (name, zone_type, center_latitude, center_longitude, radius_m) VALUES
    ('New Cairo Green Zone',      'green', 30.0200, 31.4900, 2500),
    ('Monorail Green Zone',       'green', 30.0400, 31.5300, 2500),
    ('Suez Road Restricted Zone', 'red',   30.0600, 31.5000,  300);

-- stations (blue areas inside green zones)
INSERT INTO stations (name, latitude, longitude, capacity, zone_id) VALUES
    ('Campus Gate Station', 30.0205, 31.4905, 10, 1),
    ('Library Station',     30.0215, 31.4920,  8, 1),
    ('Monorail Station',    30.0410, 31.5310, 12, 2);

-- bikes (bike 4 is being ridden, so it has no station)
INSERT INTO bikes (bike_code, qr_code, status, battery_minutes, latitude, longitude, station_id) VALUES
    ('BK-001', 'QR-BK-001', 'available',  120, 30.0215, 31.4920, 2),
    ('BK-002', 'QR-BK-002', 'charging',     0, 30.0410, 31.5310, 3),
    ('BK-003', 'QR-BK-003', 'available',   80, 30.0205, 31.4905, 1),
    ('BK-004', 'QR-BK-004', 'in_use',      90, 30.0230, 31.4950, NULL),
    ('BK-005', 'QR-BK-005', 'charging',    10, 30.0205, 31.4905, 1),
    ('BK-006', 'QR-BK-006', 'available',  150, 30.0215, 31.4920, 2);

-- rentals
-- 1: 7 min 21 s -> billed 8 min  -> 5 + 8 x 1.50 = 17.00
-- 2: 20 min 10 s -> billed 20 min; battery died after 10 min -> 5 + 10 x 1.50 + 10 x 0.75 = 27.50
-- 3: 12 min 30 s -> billed 13 min + 20.00 red-zone penalty -> 5 + 13 x 1.50 + 20 = 44.50
-- 4: still active (end_time, end_station_id and total_cost are NULL)
INSERT INTO rentals
    (user_id, bike_id, pricing_plan_id, start_station_id, end_station_id, start_time, end_time,
     unlock_method, unlock_distance_m, battery_depleted_at, total_cost)
VALUES
    (3, 1, 1, 1, 2,    '2026-11-10 09:00:00', '2026-11-10 09:07:21', 'qr_code', 4.50, NULL,                  17.00),
    (4, 2, 1, 1, 3,    '2026-11-12 10:00:00', '2026-11-12 10:20:10', 'bike_id', 8.00, '2026-11-12 10:10:00', 27.50),
    (3, 3, 1, 3, 1,    '2026-11-14 18:00:00', '2026-11-14 18:12:30', 'qr_code', 6.00, NULL,                  44.50),
    (4, 4, 1, 2, NULL, '2026-11-15 12:00:00', NULL,                  'qr_code', 3.20, NULL,                  NULL);

-- payments
-- payment 3 is 'partial': Rider A only had 30.00 left, so 14.50 is still owed (US-015)
INSERT INTO payments (user_id, rental_id, card_id, payment_type, source, amount, status) VALUES
    (3, NULL, NULL, 'topup',             'online', 47.00, 'success'),
    (3, 1,    NULL, 'rental',            'wallet', 17.00, 'success'),
    (3, 3,    NULL, 'rental',            'wallet', 30.00, 'partial'),
    (4, NULL, 1,    'activation_fee',    'card',    5.00, 'success'),
    (4, NULL, 1,    'activation_refund', 'card',    5.00, 'success'),
    (4, NULL, NULL, 'topup',             'gift',   80.00, 'success'),
    (4, 2,    NULL, 'rental',            'wallet', 27.50, 'success');

-- zone_violations: Rider A stayed 5 min 30 s in the red zone during rental 3
INSERT INTO zone_violations (rental_id, zone_id, entered_at, left_at, penalty_applied) VALUES
    (3, 3, '2026-11-14 18:04:00', '2026-11-14 18:09:30', TRUE);

-- reports
INSERT INTO reports (rental_id, handled_by, category, description, status) VALUES
    (2, NULL, 'bike_issue', 'Battery ran out in the middle of the trip.',           'submitted'),
    (3, 2,    'ride_issue', 'Warning for the restricted zone appeared very late.',  'in_review');
