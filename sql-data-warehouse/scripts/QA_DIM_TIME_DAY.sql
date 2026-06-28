-- ============================================================
-- DIM_TIME_DAY
-- Date dimension 
-- ============================================================

CREATE SCHEMA IF NOT EXISTS bl_dm;

DROP TABLE IF EXISTS bl_dm.dim_time_day;

CREATE TABLE bl_dm.dim_time_day (
    date_surr_id     BIGINT      NOT NULL,
    date_src_id      VARCHAR(20) NOT NULL,
    date_dt          DATE        NOT NULL,
    day_no           SMALLINT    NOT NULL,
    month_no         SMALLINT    NOT NULL,
    year_no          SMALLINT    NOT NULL,
    day_of_week_no   SMALLINT    NOT NULL,
    is_weekend_flg   CHAR(1)     NOT NULL,
    CONSTRAINT pk_dim_time_day PRIMARY KEY (date_surr_id)
);

CREATE UNIQUE INDEX ux_dim_time_day_date_dt
    ON bl_dm.dim_time_day (date_dt);

-- ============================================================
-- Populate DIM_TIME_DAY
-- ============================================================

DO $$
DECLARE
    v_start_date DATE := DATE '2018-01-01';
    v_end_date   DATE := DATE '2035-12-31';
BEGIN
    INSERT INTO bl_dm.dim_time_day (
        date_surr_id,
        date_src_id,
        date_dt,
        day_no,
        month_no,
        year_no,
        day_of_week_no,
        is_weekend_flg
    )
    SELECT
        TO_CHAR(gs.dt, 'YYYYMMDD')::BIGINT                      AS date_surr_id,
        TO_CHAR(gs.dt, 'YYYY-MM-DD')                            AS date_src_id,
        gs.dt                                                   AS date_dt,
        EXTRACT(DAY   FROM gs.dt)::SMALLINT                     AS day_no,
        EXTRACT(MONTH FROM gs.dt)::SMALLINT                     AS month_no,
        EXTRACT(YEAR  FROM gs.dt)::SMALLINT                     AS year_no,
        EXTRACT(ISODOW FROM gs.dt)::SMALLINT                    AS day_of_week_no,
        CASE
            WHEN EXTRACT(ISODOW FROM gs.dt) IN (6, 7)
                THEN 'Y'
            ELSE 'N'
        END                                                     AS is_weekend_flg
    FROM (
        SELECT GENERATE_SERIES(
                   v_start_date,
                   v_end_date,
                   INTERVAL '1 day'
               )::DATE AS dt
    ) gs;
END $$;

-- ============================================================
-- QA CHECKS FOR BL_DM.DIM_TIME_DAY 
-- Run AFTER population
-- Expected: anomaly queries return 0 rows
-- ============================================================

-- ------------------------------------------------------------
-- CHECK 0: Basic sanity - table is accessible
-- ------------------------------------------------------------
SELECT
    COUNT(*) AS row_cnt
FROM bl_dm.dim_time_day;

-- ------------------------------------------------------------
-- CHECK 1: Date range sanity (min/max dates)
-- Expect: min_dt = start_date, max_dt = end_date
-- ------------------------------------------------------------
SELECT
    MIN(date_dt) AS min_dt,
    MAX(date_dt) AS max_dt,
    COUNT(*)     AS days_cnt
FROM bl_dm.dim_time_day;

-- ------------------------------------------------------------
-- CHECK 2: No NULLs in mandatory columns
-- Expect: 0 rows
-- ------------------------------------------------------------
SELECT
    date_surr_id,
    date_src_id,
    date_dt,
    day_no,
    month_no,
    year_no,
    day_of_week_no,
    is_weekend_flg
FROM bl_dm.dim_time_day
WHERE date_surr_id   IS NULL
   OR date_src_id    IS NULL
   OR date_dt        IS NULL
   OR day_no         IS NULL
   OR month_no       IS NULL
   OR year_no        IS NULL
   OR day_of_week_no IS NULL
   OR is_weekend_flg IS NULL;

-- ------------------------------------------------------------
-- CHECK 3: Surrogate key uniqueness
-- Expect: 0 rows
-- ------------------------------------------------------------
SELECT
    date_surr_id,
    COUNT(*) AS dup_cnt
FROM bl_dm.dim_time_day
GROUP BY date_surr_id
HAVING COUNT(*) > 1;

-- ------------------------------------------------------------
-- CHECK 4: date_dt uniqueness (no duplicate days)
-- Expect: 0 rows
-- ------------------------------------------------------------
SELECT
    date_dt,
    COUNT(*) AS dup_cnt
FROM bl_dm.dim_time_day
GROUP BY date_dt
HAVING COUNT(*) > 1;

-- ------------------------------------------------------------
-- CHECK 5: Surrogate key matches date_dt (YYYYMMDD)
-- Expect: 0 rows
-- ------------------------------------------------------------
SELECT
    date_surr_id,
    date_dt
FROM bl_dm.dim_time_day
WHERE date_surr_id <> TO_CHAR(date_dt, 'YYYYMMDD')::BIGINT;

-- ------------------------------------------------------------
-- CHECK 6: date_src_id matches date_dt (YYYY-MM-DD)
-- Expect: 0 rows
-- ------------------------------------------------------------
SELECT
    date_src_id,
    date_dt
FROM bl_dm.dim_time_day
WHERE date_src_id <> TO_CHAR(date_dt, 'YYYY-MM-DD');

-- ------------------------------------------------------------
-- CHECK 7: day_no / month_no / year_no consistency with date_dt
-- Expect: 0 rows
-- ------------------------------------------------------------
SELECT
    date_dt,
    day_no,
    month_no,
    year_no
FROM bl_dm.dim_time_day
WHERE day_no   <> EXTRACT(DAY   FROM date_dt)::SMALLINT
   OR month_no <> EXTRACT(MONTH FROM date_dt)::SMALLINT
   OR year_no  <> EXTRACT(YEAR  FROM date_dt)::SMALLINT;

-- ------------------------------------------------------------
-- CHECK 8: day_of_week_no range (ISO: 1..7, Mon..Sun)
-- Expect: 0 rows
-- ------------------------------------------------------------
SELECT
    date_dt,
    day_of_week_no
FROM bl_dm.dim_time_day
WHERE day_of_week_no NOT BETWEEN 1 AND 7;

-- ------------------------------------------------------------
-- CHECK 9: is_weekend_flg only 'Y' or 'N'
-- Expect: 0 rows
-- ------------------------------------------------------------
SELECT
    date_dt,
    is_weekend_flg
FROM bl_dm.dim_time_day
WHERE is_weekend_flg NOT IN ('Y', 'N');

-- ------------------------------------------------------------
-- CHECK 10: Weekend flag logic (Sat/Sun => Y, else N)
-- Expect: 0 rows
-- ------------------------------------------------------------
SELECT
    date_dt,
    day_of_week_no,
    is_weekend_flg
FROM bl_dm.dim_time_day
WHERE (day_of_week_no IN (6, 7) AND is_weekend_flg <> 'Y')
   OR (day_of_week_no NOT IN (6, 7) AND is_weekend_flg <> 'N');
