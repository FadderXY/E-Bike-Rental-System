-- ============================================================
-- Smart Bike Rental App - GIU Software Engineering - Milestone 2
-- 01_create_tables.sql
-- Creates all 10 tables, in dependency order (referenced tables first).
-- Run on an EMPTY database named smart_bike_rental.
-- Run order: 01 -> 02 -> 03 (-> 04 optional tests)
-- ============================================================

-- ------------------------------------------------------------
-- 1. users  (riders, admins and the company)
-- Stories: US-001, US-002, US-003, US-004, US-014
-- ------------------------------------------------------------
CREATE TABLE users (
    user_id           SERIAL PRIMARY KEY,
    full_name         VARCHAR(100)  NOT NULL,
    email             VARCHAR(255)  NOT NULL UNIQUE,
    password_hash     VARCHAR(255)  NOT NULL,
    date_of_birth     DATE          NOT NULL,
    -- UNIQUE enforces one account per device (US-002)
    device_serial     VARCHAR(100)  NOT NULL UNIQUE,
    role              VARCHAR(20)   NOT NULL DEFAULT 'rider'
                      CHECK (role IN ('rider', 'admin', 'company')),
    -- document used for age verification (US-003); NULL until submitted
    id_document_type  VARCHAR(30)
                      CHECK (id_document_type IN
                             ('birth_certificate', 'national_id', 'drivers_license', 'passport')),
    age_verified      BOOLEAN       NOT NULL DEFAULT FALSE,
    -- wallet balance in EGP (US-009, US-014)
    wallet_balance    NUMERIC(10,2) NOT NULL DEFAULT 0 CHECK (wallet_balance >= 0),
    created_at        TIMESTAMP     NOT NULL DEFAULT NOW(),
    -- a verified user must have said which document was used
    CHECK (NOT age_verified OR id_document_type IS NOT NULL)
);

-- ------------------------------------------------------------
-- 2. pricing_plans  (fees and rates set by the company)
-- Stories: US-008, US-010, US-012, US-013, US-014, US-019
-- ------------------------------------------------------------
CREATE TABLE pricing_plans (
    pricing_plan_id          SERIAL PRIMARY KEY,
    name                     VARCHAR(50)  NOT NULL UNIQUE,
    unlock_fee               NUMERIC(8,2) NOT NULL CHECK (unlock_fee >= 0),
    per_minute_rate          NUMERIC(8,2) NOT NULL CHECK (per_minute_rate >= 0),
    -- lower rate once the battery reaches zero (US-019)
    reduced_per_minute_rate  NUMERIC(8,2) NOT NULL CHECK (reduced_per_minute_rate >= 0),
    -- penalty for staying more than 3 minutes in a restricted zone (US-008)
    restricted_zone_penalty  NUMERIC(8,2) NOT NULL CHECK (restricted_zone_penalty >= 0),
    -- temporary card verification fee, 5 EGP (US-010)
    card_activation_fee      NUMERIC(8,2) NOT NULL CHECK (card_activation_fee >= 0),
    is_active                BOOLEAN      NOT NULL DEFAULT TRUE,
    CHECK (reduced_per_minute_rate <= per_minute_rate)
);

-- ------------------------------------------------------------
-- 3. zones  (green areas and red restricted areas)
-- Stories: US-007, US-008
-- ------------------------------------------------------------
CREATE TABLE zones (
    zone_id           SERIAL PRIMARY KEY,
    name              VARCHAR(100)     NOT NULL UNIQUE,
    zone_type         VARCHAR(10)      NOT NULL CHECK (zone_type IN ('green', 'red')),
    center_latitude   DOUBLE PRECISION NOT NULL CHECK (center_latitude  BETWEEN -90  AND 90),
    center_longitude  DOUBLE PRECISION NOT NULL CHECK (center_longitude BETWEEN -180 AND 180),
    radius_m          INT              NOT NULL CHECK (radius_m > 0)
);

-- ------------------------------------------------------------
-- 4. stations  (blue areas: docking / charging stations inside a green zone)
-- Stories: US-006, US-007, US-016, US-023
-- ------------------------------------------------------------
CREATE TABLE stations (
    station_id  SERIAL PRIMARY KEY,
    name        VARCHAR(100)     NOT NULL UNIQUE,
    latitude    DOUBLE PRECISION NOT NULL CHECK (latitude  BETWEEN -90  AND 90),
    longitude   DOUBLE PRECISION NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    capacity    INT              NOT NULL CHECK (capacity > 0),
    -- ON DELETE RESTRICT: a zone cannot be deleted while stations still belong to it
    zone_id     INT              NOT NULL
                REFERENCES zones(zone_id) ON DELETE RESTRICT
);

-- ------------------------------------------------------------
-- 5. bikes
-- Stories: US-011, US-016, US-017, US-018, US-022, US-025
-- ------------------------------------------------------------
CREATE TABLE bikes (
    bike_id           SERIAL PRIMARY KEY,
    bike_code         VARCHAR(30)  NOT NULL UNIQUE,   -- ID shown on the bike (US-011)
    qr_code           VARCHAR(100) NOT NULL UNIQUE,   -- value of the QR code on the bike (US-011)
    status            VARCHAR(20)  NOT NULL DEFAULT 'available'
                      CHECK (status IN ('available', 'charging', 'in_use', 'unavailable')),
    -- remaining battery time in minutes (US-017)
    battery_minutes   INT          NOT NULL CHECK (battery_minutes >= 0),
    latitude          DOUBLE PRECISION NOT NULL CHECK (latitude  BETWEEN -90  AND 90),
    longitude         DOUBLE PRECISION NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    last_updated_at   TIMESTAMP    NOT NULL DEFAULT NOW(),   -- refreshed every 5 s (US-022)
    -- NULL while the bike is being ridden.
    -- ON DELETE RESTRICT: a station cannot be deleted while bikes are docked there
    station_id        INT REFERENCES stations(station_id) ON DELETE RESTRICT,
    -- US-018: a bike with less than 15 minutes of battery cannot be available
    CHECK (status <> 'available' OR battery_minutes >= 15),
    -- a bike is outside any station exactly when it is being ridden
    CHECK ((status = 'in_use') = (station_id IS NULL))
);

-- ------------------------------------------------------------
-- 6. cards  (linked credit / debit cards)
-- Stories: US-009, US-010
-- ------------------------------------------------------------
CREATE TABLE cards (
    card_id      SERIAL PRIMARY KEY,
    -- ON DELETE RESTRICT: keep card history; a user with cards cannot be deleted
    user_id      INT         NOT NULL
                 REFERENCES users(user_id) ON DELETE RESTRICT,
    card_type    VARCHAR(10) NOT NULL CHECK (card_type IN ('credit', 'debit')),
    last_four    CHAR(4)     NOT NULL CHECK (last_four ~ '^[0-9]{4}$'),  -- never store the full number
    is_verified  BOOLEAN     NOT NULL DEFAULT FALSE,   -- set after the activation fee succeeds
    created_at   TIMESTAMP   NOT NULL DEFAULT NOW()
);

-- ------------------------------------------------------------
-- 7. rentals  (one row per trip - resolves the users <-> bikes many-to-many)
-- Stories: US-011, US-012, US-013, US-019, US-023
-- ------------------------------------------------------------
CREATE TABLE rentals (
    rental_id            SERIAL PRIMARY KEY,
    -- ON DELETE RESTRICT on all FKs below: rental history must never disappear
    user_id              INT NOT NULL REFERENCES users(user_id)                  ON DELETE RESTRICT,
    bike_id              INT NOT NULL REFERENCES bikes(bike_id)                  ON DELETE RESTRICT,
    pricing_plan_id      INT NOT NULL REFERENCES pricing_plans(pricing_plan_id)  ON DELETE RESTRICT,
    start_station_id     INT NOT NULL REFERENCES stations(station_id)            ON DELETE RESTRICT,
    end_station_id       INT          REFERENCES stations(station_id)            ON DELETE RESTRICT,
    start_time           TIMESTAMP    NOT NULL DEFAULT NOW(),
    end_time             TIMESTAMP,                          -- NULL while the trip is active
    unlock_method        VARCHAR(10)  NOT NULL CHECK (unlock_method IN ('bike_id', 'qr_code')),
    -- US-011: the rider must be within 10 metres of the bike to unlock it
    unlock_distance_m    NUMERIC(5,2) NOT NULL CHECK (unlock_distance_m >= 0 AND unlock_distance_m <= 10),
    battery_depleted_at  TIMESTAMP,                          -- moment the battery hit zero (US-019)
    total_cost           NUMERIC(10,2) CHECK (total_cost >= 0),  -- calculated when the bike is locked
    CHECK (end_time IS NULL OR end_time >= start_time),
    CHECK ((end_time IS NULL) = (end_station_id IS NULL)),
    CHECK (end_time IS NOT NULL OR total_cost IS NULL),
    CHECK (battery_depleted_at IS NULL OR battery_depleted_at >= start_time)
);

-- ------------------------------------------------------------
-- 8. payments  (every money movement)
-- Stories: US-009, US-010, US-012, US-015
-- ------------------------------------------------------------
CREATE TABLE payments (
    payment_id    SERIAL PRIMARY KEY,
    -- ON DELETE RESTRICT on all FKs below: financial records must be kept
    user_id       INT NOT NULL REFERENCES users(user_id)     ON DELETE RESTRICT,
    rental_id     INT          REFERENCES rentals(rental_id) ON DELETE RESTRICT,  -- NULL for top-ups and card fees
    card_id       INT          REFERENCES cards(card_id)     ON DELETE RESTRICT,  -- NULL if no card was used
    payment_type  VARCHAR(20)  NOT NULL
                  CHECK (payment_type IN ('rental', 'topup', 'activation_fee', 'activation_refund')),
    -- where the money came from (US-009), including gifted credit
    source        VARCHAR(20)  NOT NULL
                  CHECK (source IN ('card', 'wallet', 'online', 'instapay', 'telda', 'gift')),
    amount        NUMERIC(10,2) NOT NULL CHECK (amount > 0),
    -- 'partial' = not enough funds, the available amount was taken (US-015)
    status        VARCHAR(10)  NOT NULL CHECK (status IN ('success', 'partial', 'failed')),
    paid_at       TIMESTAMP    NOT NULL DEFAULT NOW(),
    CHECK (payment_type <> 'rental' OR rental_id IS NOT NULL)
);

-- ------------------------------------------------------------
-- 9. zone_violations  (a rider entering a red zone - resolves rentals <-> zones many-to-many)
-- Stories: US-008
-- ------------------------------------------------------------
CREATE TABLE zone_violations (
    violation_id     SERIAL PRIMARY KEY,
    -- ON DELETE CASCADE: a violation has no meaning without its rental
    rental_id        INT NOT NULL REFERENCES rentals(rental_id) ON DELETE CASCADE,
    -- ON DELETE RESTRICT: a red zone cannot be deleted while violations refer to it
    zone_id          INT NOT NULL REFERENCES zones(zone_id)     ON DELETE RESTRICT,
    entered_at       TIMESTAMP NOT NULL DEFAULT NOW(),
    left_at          TIMESTAMP,                                  -- NULL while still inside the zone
    penalty_applied  BOOLEAN   NOT NULL DEFAULT FALSE,           -- TRUE after 3 minutes inside (US-008)
    CHECK (left_at IS NULL OR left_at >= entered_at)
);

-- ------------------------------------------------------------
-- 10. reports  (problem reports sent to technical support)
-- Stories: US-020, US-021
-- ------------------------------------------------------------
CREATE TABLE reports (
    report_id     SERIAL PRIMARY KEY,
    -- ON DELETE RESTRICT: keep reports as evidence even if someone tries to delete the rental
    rental_id     INT NOT NULL REFERENCES rentals(rental_id) ON DELETE RESTRICT,
    -- admin handling the report. ON DELETE SET NULL: report survives if the admin account is removed
    handled_by    INT REFERENCES users(user_id) ON DELETE SET NULL,
    category      VARCHAR(20) NOT NULL
                  CHECK (category IN ('bike_issue', 'ride_issue', 'safety', 'other')),
    description   TEXT        NOT NULL,
    -- a new report is submitted to technical support immediately (US-021)
    status        VARCHAR(20) NOT NULL DEFAULT 'submitted'
                  CHECK (status IN ('submitted', 'in_review', 'resolved')),
    submitted_at  TIMESTAMP   NOT NULL DEFAULT NOW()
);
