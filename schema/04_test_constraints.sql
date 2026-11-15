-- ============================================================
-- Smart Bike Rental App - GIU Software Engineering - Milestone 2
-- 04_test_constraints.sql  (optional)
-- "Try to break the schema on purpose" (brief, Step 6.4).
-- Run each statement ONE AT A TIME (select it, then press F5).
-- EVERY statement below must FAIL with an error. If one succeeds, a rule is missing.
-- ============================================================

-- 1. Duplicate email (UNIQUE)
INSERT INTO users (full_name, email, password_hash, date_of_birth, device_serial)
VALUES ('Dup Email', 'rider.a@example.com', 'x', '2000-01-01', 'SN-9001');

-- 2. Second account on the same device (US-002, UNIQUE device_serial)
INSERT INTO users (full_name, email, password_hash, date_of_birth, device_serial)
VALUES ('Dup Device', 'new@example.com', 'x', '2000-01-01', 'SN-0003');

-- 3. Rider younger than 12 (US-004, trigger)
INSERT INTO users (full_name, email, password_hash, date_of_birth, device_serial)
VALUES ('Too Young', 'kid@example.com', 'x', '2020-01-01', 'SN-9002');

-- 4. Invalid role (CHECK)
INSERT INTO users (full_name, email, password_hash, date_of_birth, device_serial, role)
VALUES ('Bad Role', 'role@example.com', 'x', '2000-01-01', 'SN-9003', 'superuser');

-- 5. Rental with a user that does not exist (FOREIGN KEY)
INSERT INTO rentals (user_id, bike_id, pricing_plan_id, start_station_id, unlock_method, unlock_distance_m)
VALUES (999, 6, 1, 2, 'qr_code', 5);

-- 6. Unlocking from more than 10 metres away (US-011, CHECK)
INSERT INTO rentals (user_id, bike_id, pricing_plan_id, start_station_id, unlock_method, unlock_distance_m)
VALUES (5, 6, 1, 2, 'qr_code', 25);

-- 7. Rider 4 already has an active rental (partial UNIQUE index)
INSERT INTO rentals (user_id, bike_id, pricing_plan_id, start_station_id, unlock_method, unlock_distance_m)
VALUES (4, 6, 1, 2, 'qr_code', 5);

-- 8. Bike 4 is already in an active rental (partial UNIQUE index)
INSERT INTO rentals (user_id, bike_id, pricing_plan_id, start_station_id, unlock_method, unlock_distance_m)
VALUES (5, 4, 1, 2, 'qr_code', 5);

-- 9. Bike marked available with only 10 minutes of battery (US-018, CHECK)
UPDATE bikes SET status = 'available' WHERE bike_id = 5;

-- 10. Invalid payment status (CHECK)
INSERT INTO payments (user_id, payment_type, source, amount, status)
VALUES (3, 'topup', 'online', 10, 'maybe');

-- 11. Negative wallet balance (CHECK)
UPDATE users SET wallet_balance = -5 WHERE user_id = 3;

-- 12. Deleting a user who has rentals (ON DELETE RESTRICT)
DELETE FROM users WHERE user_id = 3;
