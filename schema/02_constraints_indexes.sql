-- ============================================================
-- Smart Bike Rental App - GIU Software Engineering - Milestone 2
-- 02_constraints_indexes.sql
-- Extra rules that cannot be written as a simple column constraint,
-- plus indexes on foreign keys. Run AFTER 01_create_tables.sql.
-- ============================================================

-- ------------------------------------------------------------
-- US-004: minimum age of 12.
-- A CHECK cannot use today's date safely, so a trigger is used.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION enforce_min_age() RETURNS trigger AS $$
BEGIN
    IF NEW.date_of_birth > (CURRENT_DATE - INTERVAL '12 years') THEN
        RAISE EXCEPTION 'User must be at least 12 years old (US-004)';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_min_age
    BEFORE INSERT OR UPDATE OF date_of_birth ON users
    FOR EACH ROW EXECUTE FUNCTION enforce_min_age();

-- ------------------------------------------------------------
-- US-001 / US-002: a rider cannot hold two bikes at once, and a bike
-- cannot be in two active rentals. "Active" = end_time IS NULL.
-- ------------------------------------------------------------
CREATE UNIQUE INDEX uq_rentals_one_active_per_user
    ON rentals (user_id) WHERE end_time IS NULL;

CREATE UNIQUE INDEX uq_rentals_one_active_per_bike
    ON rentals (bike_id) WHERE end_time IS NULL;

-- ------------------------------------------------------------
-- Indexes on foreign keys (speed up joins and the 5-second availability scan, US-022)
-- ------------------------------------------------------------
CREATE INDEX idx_cards_user            ON cards (user_id);
CREATE INDEX idx_stations_zone         ON stations (zone_id);
CREATE INDEX idx_bikes_station_status  ON bikes (station_id, status);
CREATE INDEX idx_rentals_user          ON rentals (user_id);
CREATE INDEX idx_rentals_bike          ON rentals (bike_id);
CREATE INDEX idx_payments_user         ON payments (user_id);
CREATE INDEX idx_payments_rental       ON payments (rental_id);
CREATE INDEX idx_violations_rental     ON zone_violations (rental_id);
CREATE INDEX idx_reports_rental        ON reports (rental_id);
CREATE INDEX idx_reports_handled_by    ON reports (handled_by);
