-- ============================================================
-- Bike-Sharing Data Warehouse — Dimensional model (star schema)
-- Target: PostgreSQL (Supabase).  Schema: dwh
-- Source (OLTP): the Django `core_*` tables in schema public
-- ============================================================

CREATE SCHEMA IF NOT EXISTS dwh;

-- ----------------------------------------------------------------
-- Dimensions
-- ----------------------------------------------------------------

-- Date dimension: one row per calendar day, "smart" key in YYYYMMDD form
CREATE TABLE dwh.dim_date (
    date_key        integer      PRIMARY KEY,        -- e.g. 20260219
    full_date       date         NOT NULL,
    day_num         integer      NOT NULL,
    month_num       integer      NOT NULL,
    month_name      varchar(20)  NOT NULL,
    quarter_num     integer      NOT NULL,
    year_num        integer      NOT NULL,
    weekday_num     integer      NOT NULL,
    weekday_name    varchar(20)  NOT NULL,
    is_weekend      boolean      NOT NULL
);

CREATE TABLE dwh.dim_user (
    user_key   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id    integer,                              -- natural key from core_user
    name       varchar(100) NOT NULL,
    surname    varchar(100) NOT NULL,
    email      varchar(100) NOT NULL
);

CREATE TABLE dwh.dim_bike (
    bike_key    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    bike_id     integer,                             -- natural key from core_bike
    bike_type   varchar(20)  NOT NULL,
    model       varchar(120) NOT NULL,
    bike_status varchar(20)  NOT NULL
);

CREATE TABLE dwh.dim_station (
    station_key integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    station_id  integer,                             -- natural key from core_station
    zone        smallint     NOT NULL,
    address     varchar(255) NOT NULL
);

CREATE TABLE dwh.dim_subscription_plan (
    subscription_plan_key integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    subscription_plan_id  integer,                   -- natural key from core_subscriptionplan
    name        varchar(100) NOT NULL,
    cost        numeric(8,2) NOT NULL,
    duration    integer      NOT NULL,
    is_active   boolean      NOT NULL
);

CREATE TABLE dwh.dim_payment_method (
    payment_method_key integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    method_name        varchar(100) NOT NULL
);

CREATE TABLE dwh.dim_payment_status (
    payment_status_key integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status_name        varchar(100) NOT NULL
);

-- ----------------------------------------------------------------
-- Facts
-- ----------------------------------------------------------------

-- Grain: one row per completed ride
CREATE TABLE dwh.fact_ride (
    ride_fact_key          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ride_id                integer,                  -- degenerate / natural key
    start_date_key         integer  NOT NULL REFERENCES dwh.dim_date(date_key),
    end_date_key           integer  NOT NULL REFERENCES dwh.dim_date(date_key),
    user_key               integer  NOT NULL REFERENCES dwh.dim_user(user_key),
    bike_key               integer  NOT NULL REFERENCES dwh.dim_bike(bike_key),
    start_station_key      integer  NOT NULL REFERENCES dwh.dim_station(station_key),
    end_station_key        integer  NOT NULL REFERENCES dwh.dim_station(station_key),
    subscription_plan_key  integer           REFERENCES dwh.dim_subscription_plan(subscription_plan_key),
    start_time             timestamp NOT NULL,
    end_time               timestamp NOT NULL,
    distance               numeric(10,2) NOT NULL,   -- measure (km)
    battery_level_start    integer  NOT NULL,        -- measure
    battery_level_end      integer  NOT NULL,        -- measure
    ride_duration_minutes  integer  NOT NULL         -- measure
);

-- Grain: one row per payment
CREATE TABLE dwh.fact_payment (
    payment_fact_key       integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payment_id             integer,
    payment_date_key       integer  NOT NULL REFERENCES dwh.dim_date(date_key),
    user_key               integer  NOT NULL REFERENCES dwh.dim_user(user_key),
    payment_method_key     integer  NOT NULL REFERENCES dwh.dim_payment_method(payment_method_key),
    payment_status_key     integer  NOT NULL REFERENCES dwh.dim_payment_status(payment_status_key),
    subscription_plan_key  integer           REFERENCES dwh.dim_subscription_plan(subscription_plan_key),
    amount                 numeric(20,2) NOT NULL    -- measure
);

-- Helpful indexes on the foreign keys used most in analytical joins
CREATE INDEX ix_fact_ride_start_date    ON dwh.fact_ride(start_date_key);
CREATE INDEX ix_fact_ride_start_station ON dwh.fact_ride(start_station_key);
CREATE INDEX ix_fact_ride_bike          ON dwh.fact_ride(bike_key);
CREATE INDEX ix_fact_payment_date       ON dwh.fact_payment(payment_date_key);
CREATE INDEX ix_fact_payment_plan       ON dwh.fact_payment(subscription_plan_key);
