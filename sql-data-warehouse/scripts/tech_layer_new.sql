-- =============================================================================
-- 1.  Technical layer (metadata)
-- =============================================================================

--Create the schema if it does not exist
CREATE SCHEMA IF NOT EXISTS tech;

-- Batch table (each ETL run is a new batch_id)
CREATE TABLE IF NOT EXISTS tech.etl_batch (
    batch_id       BIGSERIAL PRIMARY KEY,
    batch_name     TEXT NOT NULL DEFAULT 'default',
    status         TEXT NOT NULL CHECK (status IN ('RUNNING','SUCCESS','FAILED')),
    start_ts       TIMESTAMP NOT NULL DEFAULT clock_timestamp(),
    end_ts         TIMESTAMP NULL,
    error_message  TEXT NULL,
    file_name      TEXT NULL,
    file_hash      TEXT NULL
);


-- Step log table (a batch may contain many steps)
CREATE TABLE IF NOT EXISTS tech.etl_step_log (
    step_log_id    BIGSERIAL PRIMARY KEY,
    batch_id       BIGINT NOT NULL REFERENCES tech.etl_batch(batch_id),
    step_name      TEXT NOT NULL,
    status         TEXT NOT NULL CHECK (status IN ('RUNNING','SUCCESS','FAILED')),
    start_ts       TIMESTAMP NOT NULL DEFAULT clock_timestamp(),
    end_ts         TIMESTAMP NULL,
    duration_sec   NUMERIC(12,3) NULL,
    rows_affected  BIGINT NULL,
    error_message  TEXT NULL
);

CREATE INDEX IF NOT EXISTS ix_etl_step_log_batch ON tech.etl_step_log(batch_id);


-- Watermarks table (so the dashboard can see the date of the last load)
CREATE TABLE IF NOT EXISTS tech.etl_watermark (
    object_name     TEXT PRIMARY KEY,
    watermark_type  TEXT NOT NULL CHECK (watermark_type IN ('BATCH_ID','LAST_LOADED_DT','LAST_LOADED_ID')),
    watermark_value TEXT NOT NULL,
    updated_ts      TIMESTAMP NOT NULL DEFAULT clock_timestamp()
);

-- 4) test results
CREATE TABLE IF NOT EXISTS tech.etl_test_results (
    test_result_id   BIGSERIAL PRIMARY KEY,
    batch_id         BIGINT NOT NULL REFERENCES tech.etl_batch(batch_id),
    test_group       INT NOT NULL,
    test_name        TEXT NOT NULL,
    status           TEXT NOT NULL CHECK (status IN ('PASS','FAIL')),
    failed_rows_cnt  BIGINT NOT NULL DEFAULT 0,
    details          TEXT NULL,
    created_ts       TIMESTAMP NOT NULL DEFAULT clock_timestamp()
);


CREATE INDEX IF NOT EXISTS ix_test_results_batch ON tech.etl_test_results(batch_id);


-- 5) optional: test catalog (for cursor+execute)
CREATE TABLE IF NOT EXISTS tech.etl_tests_catalog (
    test_id      BIGSERIAL PRIMARY KEY,
    test_name    TEXT NOT NULL,
    test_group   INT NOT NULL,
    sql_text     TEXT NOT NULL,
    is_active    BOOLEAN NOT NULL DEFAULT TRUE
);

-- Add required technical columns in the B2C staging table
ALTER TABLE sa_b2c.src_b2c
  ADD COLUMN IF NOT EXISTS batch_id BIGINT,
  ADD COLUMN IF NOT EXISTS load_dttm TIMESTAMP,
  ADD COLUMN IF NOT EXISTS row_hash TEXT;

-- B2B 
ALTER TABLE sa_b2b.src_b2b
  ADD COLUMN IF NOT EXISTS batch_id BIGINT,
  ADD COLUMN IF NOT EXISTS load_dttm TIMESTAMP,
  ADD COLUMN IF NOT EXISTS row_hash TEXT;

UPDATE sa_b2c.src_b2c
SET batch_id = COALESCE(batch_id, 0),
    load_dttm = COALESCE(load_dttm, clock_timestamp());

UPDATE sa_b2b.src_b2b
SET batch_id = COALESCE(batch_id, 0),
    load_dttm = COALESCE(load_dttm, clock_timestamp());

-- манипуляции с watermark
-- 1) убрать старый PK (если есть)
ALTER TABLE tech.etl_watermark
  DROP CONSTRAINT IF EXISTS etl_watermark_pkey;

-- 2) добавить новый PK (object_name, watermark_type)
ALTER TABLE tech.etl_watermark
  ADD CONSTRAINT etl_watermark_pkey PRIMARY KEY (object_name, watermark_type);

-- 3) убрать UNIQUE
ALTER TABLE tech.etl_watermark
  DROP CONSTRAINT IF EXISTS uk_etl_watermark_obj_type;

ALTER TABLE tech.etl_watermark
  DROP CONSTRAINT IF EXISTS etl_watermark_watermark_type_check;

ALTER TABLE tech.etl_watermark
  ADD CONSTRAINT etl_watermark_watermark_type_check
  CHECK (
    watermark_type IN (
      'BATCH_ID',
      'LAST_LOADED_DT',
      'LAST_LOADED_ID',
      'LAST_SUCCESS_BATCH_ID',
      'LAST_SUCCESS_TS',
      'LAST_FAILED_BATCH_ID',
      'LAST_ERROR'
    )
  );


  -- и тестами
ALTER TABLE tech.etl_test_results
  DROP CONSTRAINT IF EXISTS etl_test_results_status_check;

ALTER TABLE tech.etl_test_results
  ADD CONSTRAINT etl_test_results_status_check
  CHECK (status IN ('PASS', 'FAIL', 'ERROR'));
  
-- =============================================================================
-- 2. Utility functions (management)
-- =============================================================================

-- Batch start function
CREATE OR REPLACE FUNCTION tech.start_batch(p_batch_name TEXT DEFAULT 'default')
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_batch_id BIGINT;
BEGIN
    INSERT INTO tech.etl_batch(batch_name, status, start_ts)
    VALUES (p_batch_name, 'RUNNING', clock_timestamp())
    RETURNING batch_id INTO v_batch_id;

    RAISE NOTICE '✅ Batch started. batch_id=% , batch_name=%', v_batch_id, p_batch_name;

    RETURN v_batch_id;
END;
$$;


-- The function inserts a row into tech.etl_step_log with status RUNNING and returns step_log_id
CREATE OR REPLACE FUNCTION tech.start_step(p_batch_id BIGINT, p_step_name TEXT)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_step_log_id BIGINT;
BEGIN
    INSERT INTO tech.etl_step_log(batch_id, step_name, status, start_ts)
    VALUES (p_batch_id, p_step_name, 'RUNNING', clock_timestamp())
    RETURNING step_log_id INTO v_step_log_id;

    RAISE NOTICE '➡️ Step started. batch_id=% step=% step_log_id=%', p_batch_id, p_step_name, v_step_log_id;

    RETURN v_step_log_id;
END;
$$;


-- Step finalization function
-- It closes the step: sets the status (SUCCESS/FAILED), time, rows processed, and error
CREATE OR REPLACE FUNCTION tech.finish_step(
    p_step_log_id BIGINT,
    p_status TEXT,
    p_rows_affected BIGINT DEFAULT NULL,
    p_error_message TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE tech.etl_step_log
    SET status = p_status,
        end_ts = clock_timestamp(),
        duration_sec = EXTRACT(EPOCH FROM (clock_timestamp() - start_ts)),
        rows_affected = p_rows_affected,
        error_message = p_error_message
    WHERE step_log_id = p_step_log_id;

    RAISE NOTICE '✅ Step finished. step_log_id=% status=% rows=%', p_step_log_id, p_status, COALESCE(p_rows_affected, -1);
END;
$$;


-- This block creates a new batch and one step

DO $$
DECLARE
  v_batch_id BIGINT;
  v_step_id  BIGINT;
BEGIN
  v_batch_id := tech.start_batch('demo_steps');
  v_step_id  := tech.start_step(v_batch_id, 'step_1_example');

  -- Simulate execution (no operation performed)

  PERFORM tech.finish_step(v_step_id, 'SUCCESS', 123, NULL);
END $$;



-- Function to finalize the batch
CREATE OR REPLACE FUNCTION tech.finish_batch(
    p_batch_id BIGINT,
    p_status TEXT,
    p_error_message TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE tech.etl_batch
    SET status = p_status,
        end_ts = clock_timestamp(),
        error_message = p_error_message
    WHERE batch_id = p_batch_id;

    RAISE NOTICE '🏁 Batch finished. batch_id=% status=%', p_batch_id, p_status;
END;
$$;

DO $$
DECLARE
  v_batch_id BIGINT;
  v_step_id  BIGINT;
BEGIN
  v_batch_id := tech.start_batch('demo_finish_batch');

  v_step_id := tech.start_step(v_batch_id, 'example_step');
  PERFORM tech.finish_step(v_step_id, 'SUCCESS', 10, NULL);

  PERFORM tech.finish_batch(v_batch_id, 'SUCCESS', NULL);
END $$;


-- =============================================================================
-- 3. Business logic (loading SA -> CL) — WRK delta
-- =============================================================================

-- Procedure for automatic data loading from B2C sources
CREATE OR REPLACE PROCEDURE sa_b2c.load_sa_and_cl(p_batch_id BIGINT)
LANGUAGE plpgsql
AS $$
BEGIN
  -- Ensure the staging schema and table exist
  CREATE SCHEMA IF NOT EXISTS bl_cl;
  CREATE TABLE IF NOT EXISTS bl_cl.wrk_b2c (LIKE sa_b2c.src_b2c INCLUDING ALL);

  -- 0) Create a temporary table with hashes for the current load
  DROP TABLE IF EXISTS temp_ext_b2c_h;
  CREATE TEMP TABLE temp_ext_b2c_h AS
  SELECT DISTINCT
    e.*,
    md5(
      coalesce(e.order_id,'')||'|'||
      coalesce(e.order_date,'')||'|'||
      coalesce(e.gross_sales_amount,'')||'|'||
      coalesce(e.discount_amount,'')||'|'||
      coalesce(e.net_sales_amount,'')||'|'||
      coalesce(e.cost_amount,'')||'|'||
      coalesce(e.quantity,'')||'|'||
      coalesce(e.customer_id,'')||'|'||
      coalesce(e.customer_name,'')||'|'||
      coalesce(e.customer_email,'')||'|'||
      coalesce(e.device_type,'')||'|'||
      coalesce(e.payment_method,'')||'|'||
      coalesce(e.country_id,'')||'|'||
      coalesce(e.country,'')||'|'||
      coalesce(e.city_id,'')||'|'||
      coalesce(e.city,'')||'|'||
      coalesce(e.idea_id,'')||'|'||
      coalesce(e.idea_title,'')||'|'||
      coalesce(e.category_id,'')||'|'||
      coalesce(e.category,'')||'|'||
      coalesce(e.subcategory_id,'')||'|'||
      coalesce(e.subcategory,'')||'|'||
      coalesce(e.industry_domain_id,'')||'|'||
      coalesce(e.industry_domain,'')||'|'||
      coalesce(e.idea_version,'')||'|'||
      coalesce(e.author_id,'')||'|'||
      coalesce(e.author_name,'')
    ) AS new_row_hash
  FROM sa_b2c.ext_b2c e;

  CREATE INDEX ON temp_ext_b2c_h(source_system, order_line_id);

  -- 1) UPDATE: Update modified records in the main SA storage
  UPDATE sa_b2c.src_b2c s
  SET
      order_id            = h.order_id,
      order_date          = h.order_date,
      gross_sales_amount  = h.gross_sales_amount,
      discount_amount     = h.discount_amount,
      net_sales_amount    = h.net_sales_amount,
      cost_amount         = h.cost_amount,
      quantity            = h.quantity,
      customer_id         = h.customer_id,
      customer_name       = h.customer_name,
      customer_email      = h.customer_email,
      device_type         = h.device_type,
      payment_method      = h.payment_method,
      country_id          = h.country_id,
      country             = h.country,
      city_id             = h.city_id,
      city                = h.city,
      idea_id             = h.idea_id,
      idea_title          = h.idea_title,
      category_id         = h.category_id,
      category            = h.category,
      subcategory_id      = h.subcategory_id,
      subcategory         = h.subcategory,
      industry_domain_id  = h.industry_domain_id,
      industry_domain     = h.industry_domain,
      idea_version        = h.idea_version,
      author_id           = h.author_id,
      author_name         = h.author_name,
      batch_id            = p_batch_id,
      load_dttm           = clock_timestamp(),
      row_hash            = h.new_row_hash
  FROM temp_ext_b2c_h h
  WHERE s.source_system = h.source_system
    AND s.order_line_id = h.order_line_id
    AND s.row_hash IS DISTINCT FROM h.new_row_hash;

  -- 2) INSERT: add new records from SA
  INSERT INTO sa_b2c.src_b2c (
      source_system, order_id, order_line_id, order_date,
      gross_sales_amount, discount_amount, net_sales_amount, cost_amount, quantity,
      customer_id, customer_name, customer_email, device_type, payment_method,
      country_id, country, city_id, city, idea_id, idea_title,
      category_id, category, subcategory_id, subcategory,
      industry_domain_id, industry_domain, idea_version, author_id, author_name,
      batch_id, load_dttm, row_hash
  )
  SELECT
      h.source_system, h.order_id, h.order_line_id, h.order_date,
      h.gross_sales_amount, h.discount_amount, h.net_sales_amount, h.cost_amount, h.quantity,
      h.customer_id, h.customer_name, h.customer_email, h.device_type, h.payment_method,
      h.country_id, h.country, h.city_id, h.city, h.idea_id, h.idea_title,
      h.category_id, h.category, h.subcategory_id, h.subcategory,
      h.industry_domain_id, h.industry_domain, h.idea_version, h.author_id, h.author_name,
      p_batch_id, clock_timestamp(), h.new_row_hash
  FROM temp_ext_b2c_h h
  WHERE NOT EXISTS (
      SELECT 1 FROM sa_b2c.src_b2c s
      WHERE s.source_system = h.source_system AND s.order_line_id = h.order_line_id
  );


  INSERT INTO bl_cl.wrk_b2c
  SELECT DISTINCT *
  FROM sa_b2c.src_b2c
  WHERE batch_id = p_batch_id;

END;
$$;

-- Procedure for loading data from sources for B2B.

CREATE OR REPLACE PROCEDURE sa_b2b.load_sa_and_cl(p_batch_id BIGINT)
LANGUAGE plpgsql
AS $$
BEGIN
  CREATE SCHEMA IF NOT EXISTS bl_cl;
  CREATE TABLE IF NOT EXISTS bl_cl.wrk_b2b (LIKE sa_b2b.src_b2b INCLUDING ALL);

  DROP TABLE IF EXISTS temp_ext_b2b_h;
  CREATE TEMP TABLE temp_ext_b2b_h AS
  SELECT DISTINCT
    e.*,
    md5(
      coalesce(e.order_id,'')||'|'||
      coalesce(e.order_date,'')||'|'||
      coalesce(e.gross_sales_amount,'')||'|'||
      coalesce(e.discount_amount,'')||'|'||
      coalesce(e.net_sales_amount,'')||'|'||
      coalesce(e.cost_amount,'')||'|'||
      coalesce(e.support_cost_amount,'')||'|'||
      coalesce(e.quantity,'')||'|'||
      coalesce(e.customer_id,'')||'|'||
      coalesce(e.company_name,'')||'|'||
      coalesce(e.company_industry,'')||'|'||
      coalesce(e.tax_id,'')||'|'||
      coalesce(e.country_id,'')||'|'||
      coalesce(e.country,'')||'|'||
      coalesce(e.idea_id,'')||'|'||
      coalesce(e.idea_title,'')||'|'||
      coalesce(e.category_id,'')||'|'||
      coalesce(e.category,'')||'|'||
      coalesce(e.subcategory_id,'')||'|'||
      coalesce(e.subcategory,'')||'|'||
      coalesce(e.industry_domain_id,'')||'|'||
      coalesce(e.industry_domain,'')||'|'||
      coalesce(e.idea_version,'')||'|'||
      coalesce(e.author_id,'')||'|'||
      coalesce(e.author_name,'')||'|'||
      coalesce(e.license_type,'')||'|'||
      coalesce(e.seats,'')||'|'||
      coalesce(e.contract_id,'')||'|'||
      coalesce(e.contract_start_date,'')||'|'||
      coalesce(e.contract_end_date,'')||'|'||
      coalesce(e.purchase_type,'')||'|'||
      coalesce(e.account_manager_id,'')||'|'||
      coalesce(e.account_manager_name,'')
    ) AS new_row_hash
  FROM sa_b2b.ext_b2b e;

  CREATE INDEX ON temp_ext_b2b_h(source_system, order_line_id);

  -- 1) UPDATE
  UPDATE sa_b2b.src_b2b s
  SET
      order_id              = h.order_id,
      order_date            = h.order_date,
      gross_sales_amount    = h.gross_sales_amount,
      discount_amount       = h.discount_amount,
      net_sales_amount      = h.net_sales_amount,
      cost_amount           = h.cost_amount,
      support_cost_amount   = h.support_cost_amount,
      quantity              = h.quantity,
      customer_id           = h.customer_id,
      company_name          = h.company_name,
      company_industry      = h.company_industry,
      tax_id                = h.tax_id,
      country_id            = h.country_id,
      country               = h.country,
      idea_id               = h.idea_id,
      idea_title            = h.idea_title,
      category_id           = h.category_id,
      category              = h.category,
      subcategory_id        = h.subcategory_id,
      subcategory           = h.subcategory,
      industry_domain_id    = h.industry_domain_id,
      industry_domain       = h.industry_domain,
      idea_version          = h.idea_version,
      author_id             = h.author_id,
      author_name           = h.author_name,
      license_type          = h.license_type,
      seats                 = h.seats,
      contract_id           = h.contract_id,
      contract_start_date   = h.contract_start_date,
      contract_end_date     = h.contract_end_date,
      purchase_type         = h.purchase_type,
      account_manager_id    = h.account_manager_id,
      account_manager_name  = h.account_manager_name,
      batch_id              = p_batch_id,
      load_dttm             = clock_timestamp(),
      row_hash              = h.new_row_hash
  FROM temp_ext_b2b_h h
  WHERE s.source_system = h.source_system
    AND s.order_line_id = h.order_line_id
    AND s.row_hash IS DISTINCT FROM h.new_row_hash;

  -- 2) INSERT
  INSERT INTO sa_b2b.src_b2b (
      source_system, order_id, order_line_id, order_date,
      gross_sales_amount, discount_amount, net_sales_amount, cost_amount, 
      support_cost_amount, quantity, customer_id, company_name, company_industry,
      tax_id, country_id, country, idea_id, idea_title,
      category_id, category, subcategory_id, subcategory,
      industry_domain_id, industry_domain, idea_version, author_id, author_name,
      license_type, seats, contract_id, contract_start_date, contract_end_date,
      purchase_type, account_manager_id, account_manager_name,
      batch_id, load_dttm, row_hash
  )
  SELECT
      h.source_system, h.order_id, h.order_line_id, h.order_date,
      h.gross_sales_amount, h.discount_amount, h.net_sales_amount, h.cost_amount, 
      h.support_cost_amount, h.quantity, h.customer_id, h.company_name, h.company_industry,
      h.tax_id, h.country_id, h.country, h.idea_id, h.idea_title,
      h.category_id, h.category, h.subcategory_id, h.subcategory,
      h.industry_domain_id, h.industry_domain, h.idea_version, h.author_id, h.author_name,
      h.license_type, h.seats, h.contract_id, h.contract_start_date, h.contract_end_date,
      h.purchase_type, h.account_manager_id, h.account_manager_name,
      p_batch_id, clock_timestamp(), h.new_row_hash
  FROM temp_ext_b2b_h h
  WHERE NOT EXISTS (
      SELECT 1 FROM sa_b2b.src_b2b s
      WHERE s.source_system = h.source_system AND s.order_line_id = h.order_line_id
  );

  
  INSERT INTO bl_cl.wrk_b2b
  SELECT DISTINCT *
  FROM sa_b2b.src_b2b
  WHERE batch_id = p_batch_id;

END;
$$;



--The function returns the number of rows (rows_affected) from the most recent execution of the procedure.
CREATE OR REPLACE FUNCTION tech.get_last_rows_from_blcl_log_any(p_proc_name TEXT)
RETURNS BIGINT
LANGUAGE sql
AS $$
  SELECT COALESCE((
    SELECT rows_affected
    FROM bl_cl.etl_log
    WHERE procedure_name = p_proc_name
       OR procedure_name = ('bl_cl.' || p_proc_name)
       OR procedure_name = ('bl_3nf.' || p_proc_name)
       OR procedure_name = ('bl_dm.' || p_proc_name)
    ORDER BY log_id DESC
    LIMIT 1
  ), 0);
$$;

-- Populating the ETL test catalog
--required for automated post-load validation and for the PASS/FAIL report in tech.etl_test_results

INSERT INTO tech.etl_tests_catalog(test_name, test_group, sql_text, is_active)
VALUES
-- 1) DM FACT: Grain duplicates
(
  'DM_FACT_DUPLICATE_GRAIN',
  10,
  $$
  SELECT COUNT(*)::bigint AS err_cnt
  FROM (
    SELECT order_id, order_line_id, event_dt, COUNT(*) c
    FROM bl_dm.fct_order_line_dd
    GROUP BY 1,2,3
    HAVING COUNT(*) > 1
  ) t;
  $$,
  true
),

-- 2) DM FACT: NULL
(
  'DM_FACT_NULL_KEYS',
  10,
  $$
  SELECT COUNT(*)::bigint AS err_cnt
  FROM bl_dm.fct_order_line_dd
  WHERE customer_surr_id IS NULL
     OR contract_surr_id IS NULL
     OR idea_surr_id IS NULL
     OR city_id IS NULL
     OR country_id IS NULL;
  $$,
  true
),

-- 3) Coverage: DM  (rolling window)
(
  'ROLL3M_DM_COVERS_3NF',
  20,
  $$
  WITH w AS (
    SELECT date_trunc('month', CURRENT_DATE)::date - INTERVAL '2 months' AS dt_from,
           (date_trunc('month', CURRENT_DATE)::date + INTERVAL '1 month') AS dt_to
  ),
  c AS (
    SELECT
      (SELECT COUNT(*)::bigint
       FROM bl_3nf.ce_order_lines ol
       JOIN bl_3nf.ce_orders o ON o.order_id = ol.order_id
       CROSS JOIN w
       WHERE o.order_dt >= w.dt_from AND o.order_dt < w.dt_to) AS cnt_3nf,
      (SELECT COUNT(*)::bigint
       FROM bl_dm.fct_order_line_dd f
       CROSS JOIN w
       WHERE f.event_dt >= w.dt_from AND f.event_dt < w.dt_to) AS cnt_dm
  )
  SELECT CASE WHEN cnt_dm >= cnt_3nf THEN 0 ELSE (cnt_3nf - cnt_dm) END AS err_cnt
  FROM c;
  $$,
  true
);


-- A procedure that runs all data quality tests after the ETL process.
CREATE OR REPLACE PROCEDURE tech.run_tests(p_batch_id BIGINT)
LANGUAGE plpgsql
AS $$
DECLARE
  r RECORD;
  v_err_cnt BIGINT := 0;
  v_status  TEXT;
  v_details TEXT;

  cur_tests CURSOR FOR
    SELECT test_group, test_name, sql_text
    FROM tech.etl_tests_catalog
    WHERE is_active = TRUE
    ORDER BY test_group, test_id;
BEGIN
  OPEN cur_tests;

  LOOP
    FETCH cur_tests INTO r;
    EXIT WHEN NOT FOUND;

    BEGIN
      -- We expect the test to return one row with the column `err_cnt
      EXECUTE r.sql_text INTO v_err_cnt;

      IF COALESCE(v_err_cnt,0) = 0 THEN
        v_status := 'PASS';
        v_details := 'ok';
      ELSE
        v_status := 'FAIL';
        v_details := 'errors found';
      END IF;

      INSERT INTO tech.etl_test_results(
        batch_id, test_group, test_name, status, failed_rows_cnt, details, created_ts
      )
      VALUES (
        p_batch_id, r.test_group, r.test_name, v_status, COALESCE(v_err_cnt,0), v_details, clock_timestamp()
      );

      RAISE NOTICE 'TEST % (group %) => % (failed_rows_cnt=%)',
        r.test_name, r.test_group, v_status, COALESCE(v_err_cnt,0);

    EXCEPTION WHEN OTHERS THEN
      INSERT INTO tech.etl_test_results(
        batch_id, test_group, test_name, status, failed_rows_cnt, details, created_ts
      )
      VALUES (
        p_batch_id, r.test_group, r.test_name, 'ERROR', 0, SQLERRM, clock_timestamp()
      );

      RAISE NOTICE 'TEST % (group %) => ERROR: %',
        r.test_name, r.test_group, SQLERRM;
    END;
  END LOOP;

  CLOSE cur_tests;
END;
$$;

-- The watermark mechanism stores the state of the ETL process: the last successfully processed batch, the load timestamp, and the most recent error
CREATE OR REPLACE PROCEDURE tech.set_watermark(IN p_object_name text, IN p_watermark_type text, IN p_watermark_value text)
 LANGUAGE plpgsql
AS $procedure$
BEGIN
  INSERT INTO tech.etl_watermark(object_name, watermark_type, watermark_value, updated_ts)
  VALUES (p_object_name, p_watermark_type, p_watermark_value, clock_timestamp())
  ON CONFLICT (object_name, watermark_type)
  DO UPDATE SET
    watermark_value = EXCLUDED.watermark_value,
    updated_ts = EXCLUDED.updated_ts;
END;
$procedure$

-- =============================================================================
-- 4. ОРКЕСТРАЦИЯ (ГЛАВНЫЙ ЗАПУСК)
-- =============================================================================

CREATE OR REPLACE PROCEDURE tech.run_etl(p_batch_name TEXT DEFAULT 'demo_run')
LANGUAGE plpgsql
AS $$
DECLARE
    v_batch_id BIGINT;
    v_step_id  BIGINT;

    v_rows_b2c BIGINT;
    v_rows_b2b BIGINT;

    v_rows_step BIGINT;
    v_rows_one  BIGINT;

    v_proc_name TEXT;

    v_proc_list_3nf TEXT[] := ARRAY[
      'prc_load_ce_countries',
      'prc_load_ce_cities',
      'prc_load_ce_categories',
      'prc_load_ce_subcategories',
      'prc_load_ce_industry_domains',
      'prc_load_ce_authors',
      'prc_load_ce_account_managers',
      'prc_load_ce_contracts',
      'prc_load_ce_ideas',
      'prc_load_ce_customers_scd',
      'prc_load_ce_orders'
    ];

    v_proc_list_dm_dims TEXT[] := ARRAY[
      'prc_load_dim_ideas',
      'prc_load_dm_dim_contracts',
      'prc_load_dm_dim_customers_scd'
    ];
BEGIN

    RAISE NOTICE '====================================';
    RAISE NOTICE 'ETL START';
    RAISE NOTICE '====================================';

    v_batch_id := tech.start_batch(p_batch_name);

    -- 01 SA+CL
    v_step_id := tech.start_step(v_batch_id, '01_load_sa_cl');
    BEGIN
        CALL sa_b2c.load_sa_and_cl(v_batch_id);
        CALL sa_b2b.load_sa_and_cl(v_batch_id);

        SELECT count(*) INTO v_rows_b2c FROM bl_cl.wrk_b2c;
        SELECT count(*) INTO v_rows_b2b FROM bl_cl.wrk_b2b;

        PERFORM tech.finish_step(v_step_id, 'SUCCESS', v_rows_b2c + v_rows_b2b, NULL);
    EXCEPTION WHEN OTHERS THEN
        PERFORM tech.finish_step(v_step_id, 'FAILED', NULL, SQLERRM);
        RAISE;
    END;

    -- 02 3NF dims+orders
    v_step_id := tech.start_step(v_batch_id, '02_load_3nf_dims_orders');
    BEGIN
        v_rows_step := 0;

        FOREACH v_proc_name IN ARRAY v_proc_list_3nf
        LOOP
            EXECUTE format('CALL bl_cl.%I()', v_proc_name);
            v_rows_one := tech.get_last_rows_from_blcl_log_any(v_proc_name);
            v_rows_step := v_rows_step + v_rows_one;
            RAISE NOTICE '   3NF: % -> rows=%', v_proc_name, v_rows_one;
        END LOOP;

        PERFORM tech.finish_step(v_step_id, 'SUCCESS', v_rows_step, NULL);
    EXCEPTION WHEN OTHERS THEN
        PERFORM tech.finish_step(v_step_id, 'FAILED', NULL, SQLERRM);
        RAISE;
    END;

    -- 03 3NF FACT incr
    v_step_id := tech.start_step(v_batch_id, '03_load_3nf_fact_order_lines_incr');
    BEGIN
        CALL bl_3nf.prc_load_ce_order_lines_incr();
        v_rows_one := tech.get_last_rows_from_blcl_log_any('prc_load_ce_order_lines_incr');
        PERFORM tech.finish_step(v_step_id, 'SUCCESS', v_rows_one, NULL);
    EXCEPTION WHEN OTHERS THEN
        PERFORM tech.finish_step(v_step_id, 'FAILED', NULL, SQLERRM);
        RAISE;
    END;

    -- 04 DM dims
    v_step_id := tech.start_step(v_batch_id, '04_load_dm_dims');
    BEGIN
        v_rows_step := 0;

        FOREACH v_proc_name IN ARRAY v_proc_list_dm_dims
        LOOP
            EXECUTE format('CALL bl_cl.%I()', v_proc_name);
            v_rows_one := tech.get_last_rows_from_blcl_log_any(v_proc_name);
            v_rows_step := v_rows_step + v_rows_one;
            RAISE NOTICE '   DM DIM: % -> rows=%', v_proc_name, v_rows_one;
        END LOOP;

        PERFORM tech.finish_step(v_step_id, 'SUCCESS', v_rows_step, NULL);
    EXCEPTION WHEN OTHERS THEN
        PERFORM tech.finish_step(v_step_id, 'FAILED', NULL, SQLERRM);
        RAISE;
    END;

    -- 05 DM FACT roll 3 months (partition swap)
    v_step_id := tech.start_step(v_batch_id, '05_load_dm_fact_roll3m');
    BEGIN
        CALL bl_dm.prc_load_fct_order_line_dd_incremental();
        v_rows_one := tech.get_last_rows_from_blcl_log_any('prc_load_fct_order_line_dd_incremental');
        PERFORM tech.finish_step(v_step_id, 'SUCCESS', v_rows_one, NULL);
    EXCEPTION WHEN OTHERS THEN
        PERFORM tech.finish_step(v_step_id, 'FAILED', NULL, SQLERRM);
        RAISE;
    END;

    -- 06 tests
    v_step_id := tech.start_step(v_batch_id, '06_run_tests');
    BEGIN
        CALL tech.run_tests(v_batch_id);

        -- Number of failed tests (FAIL + ERROR)
        SELECT COUNT(*)
        INTO v_rows_one
        FROM tech.etl_test_results
        WHERE batch_id = v_batch_id
          AND status IN ('FAIL','ERROR');

        -- rows_affected = Number of failed tests
        PERFORM tech.finish_step(v_step_id, 'SUCCESS', v_rows_one, NULL);
    EXCEPTION WHEN OTHERS THEN
        PERFORM tech.finish_step(v_step_id, 'FAILED', NULL, SQLERRM);
        RAISE;
    END;

    -- finish batch
    PERFORM tech.finish_batch(v_batch_id, 'SUCCESS', NULL);
    CALL tech.set_watermark('DWH_PIPELINE', 'LAST_SUCCESS_BATCH_ID', v_batch_id::text);
    CALL tech.set_watermark('DWH_PIPELINE', 'LAST_SUCCESS_TS', clock_timestamp()::text);

    RAISE NOTICE '====================================';
    RAISE NOTICE 'ETL SUCCESS';
    RAISE NOTICE '====================================';

EXCEPTION WHEN OTHERS THEN
    IF v_batch_id IS NOT NULL THEN
        PERFORM tech.finish_batch(v_batch_id, 'FAILED', SQLERRM);
    END IF;
    CALL tech.set_watermark('DWH_PIPELINE', 'LAST_FAILED_BATCH_ID', COALESCE(v_batch_id,0)::text);
    CALL tech.set_watermark('DWH_PIPELINE', 'LAST_ERROR', SQLERRM);
    RAISE;
END;
$$;

ALTER FOREIGN TABLE sa_b2c.ext_b2c
OPTIONS (SET filename 'C:/datasets/split_out/B2C_INCREMENT_5_PLUS_UPDATES.csv');

ALTER FOREIGN TABLE sa_b2b.ext_b2b
OPTIONS (SET filename 'C:/datasets/split_out/B2B_INCREMENT_5_PLUS_UPDATES.csv');

CALL tech.run_etl('initial_5');



