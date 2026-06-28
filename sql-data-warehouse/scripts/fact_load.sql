/* 
Step 1.
Recreate DM fact table as partitioned table 
to support rolling 3-month window load 
using ATTACH / DETACH partition strategy.
*/
BEGIN;

ALTER TABLE bl_dm.fct_order_line_dd
RENAME TO fct_order_line_dd_bak_nonpart;

-- 2) Сreate partitioned parent
CREATE TABLE bl_dm.fct_order_line_dd (
    event_dt            DATE   NOT NULL,
    order_id            BIGINT NOT NULL,
    order_line_id       BIGINT NOT NULL,

    customer_surr_id    BIGINT NOT NULL,
    date_dt             DATE   NOT NULL,
    contract_surr_id    BIGINT NOT NULL,
    idea_surr_id        BIGINT NOT NULL,

    country_id          BIGINT NOT NULL,
    city_id             BIGINT NOT NULL,

    gross_sales_amount  NUMERIC(15,2) NOT NULL,
    discount_amount     NUMERIC(15,2) NOT NULL,
    net_sales_amount    NUMERIC(15,2) NOT NULL,
    cost_amount         NUMERIC(15,2) NOT NULL,
    support_cost_amount NUMERIC(15,2) NOT NULL,
    quantity_cnt        INT NOT NULL,

    profit_amount       NUMERIC(15,2) NOT NULL,
    insert_dt           DATE NOT NULL
)
PARTITION BY RANGE (event_dt);

-- 3) Index on the parent table (will be created as a partitioned index)
CREATE INDEX IF NOT EXISTS ix_fct_order_line_grain
ON bl_dm.fct_order_line_dd (order_id, order_line_id, event_dt);

COMMIT;


/*
Step 2.
Create one monthly partition manually (current month).
This is useful to demonstrate partitioning mechanics in the report.
*/

DO $$
DECLARE
    v_from DATE := date_trunc('month', CURRENT_DATE)::date;
    v_to   DATE := (date_trunc('month', CURRENT_DATE) + INTERVAL '1 month')::date;
    v_part TEXT := format('fct_order_line_dd_p_%s', to_char(v_from,'YYYYMM'));
BEGIN
    EXECUTE format(
        'CREATE TABLE IF NOT EXISTS bl_dm.%I PARTITION OF bl_dm.fct_order_line_dd FOR VALUES FROM (%L) TO (%L);',
        v_part, v_from, v_to
    );
END $$;


-- Check partitions created for the fact table
SELECT
  nmsp_parent.nspname AS parent_schema,
  parent.relname      AS parent_table,
  nmsp_child.nspname  AS child_schema,
  child.relname       AS partition_table
FROM pg_inherits
JOIN pg_class parent       ON pg_inherits.inhparent = parent.oid
JOIN pg_class child        ON pg_inherits.inhrelid  = child.oid
JOIN pg_namespace nmsp_parent ON nmsp_parent.oid = parent.relnamespace
JOIN pg_namespace nmsp_child  ON nmsp_child.oid  = child.relnamespace
WHERE nmsp_parent.nspname = 'bl_dm'
  AND parent.relname = 'fct_order_line_dd'
ORDER BY partition_table;


/*
Step 3.
Create procedure to automatically create monthly partitions
for rolling 3-month window (current month + 2 previous months).
*/

CREATE OR REPLACE PROCEDURE bl_dm.prc_manage_fct_partitions_3m()
LANGUAGE plpgsql
AS $$
DECLARE
    v_month_start DATE;
    v_month_end   DATE;
    v_part_name   TEXT;
    v_i           INT;
	v_asof        DATE;
BEGIN

    SELECT COALESCE(MAX(order_dt), CURRENT_DATE)
INTO v_asof
FROM bl_3nf.ce_orders
WHERE order_id <> -1;
    -- Loop through 3 months: current month and 2 previous months
    FOR v_i IN 0..2 LOOP
        
        -- Calculate month start
        v_month_start := (date_trunc('month', v_asof)::date - (v_i || ' months')::interval)::date;
        v_month_start := v_month_start::date;
        -- Calculate month end
        v_month_end := (v_month_start + INTERVAL '1 month')::date;
        -- Generate partition table name (YYYYMM)
        v_part_name := format(
            'fct_order_line_dd_p_%s',
            to_char(v_month_start, 'YYYYMM')
        );
        -- Create partition if not exists
        EXECUTE format(
            'CREATE TABLE IF NOT EXISTS bl_dm.%I PARTITION OF bl_dm.fct_order_line_dd
             FOR VALUES FROM (%L) TO (%L);',
            v_part_name,
            v_month_start,
            v_month_end
        );
    END LOOP;
END;
$$;


CALL bl_dm.prc_manage_fct_partitions_3m();


/*
Step 4.
Rolling 3-month refresh using DETACH / ATTACH partition swap strategy.
This version swaps partitions with empty staging tables (no data load yet).
*/

CREATE OR REPLACE PROCEDURE bl_dm.prc_swap_fct_partitions_3m_empty()
LANGUAGE plpgsql
AS $$
DECLARE
    v_proc       TEXT := 'bl_dm.prc_swap_fct_partitions_3m_empty';
    v_rows       INT  := 0;
    v_month_start DATE;
    v_month_end   DATE;
    v_i           INT;
    v_part_name TEXT;
    v_stg_name  TEXT;
BEGIN
    -- Ensure partitions exist (Step 3 logic)
    CALL bl_dm.prc_manage_fct_partitions_3m();
    -- Loop through 3 months: current month and 2 previous months
    FOR v_i IN 0..2 LOOP
        v_month_start := date_trunc('month', CURRENT_DATE)::date - (v_i || ' months')::interval;
        v_month_start := v_month_start::date;
        v_month_end   := (v_month_start + INTERVAL '1 month')::date;
        v_part_name := format('fct_order_line_dd_p_%s', to_char(v_month_start,'YYYYMM'));
        v_stg_name  := format('fct_order_line_dd_stg_%s', to_char(v_month_start,'YYYYMM'));
        -- Drop staging table if exists
        EXECUTE format('DROP TABLE IF EXISTS bl_dm.%I', v_stg_name);
        -- Create empty staging table with same structure as parent
        EXECUTE format('CREATE TABLE bl_dm.%I (LIKE bl_dm.fct_order_line_dd INCLUDING ALL)', v_stg_name);
        -- Detach and drop existing partition (if exists)
        IF EXISTS (
            SELECT 1
            FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'bl_dm'
              AND c.relname = v_part_name
        ) THEN
            EXECUTE format('ALTER TABLE bl_dm.fct_order_line_dd DETACH PARTITION bl_dm.%I', v_part_name);
            EXECUTE format('DROP TABLE IF EXISTS bl_dm.%I', v_part_name);
        END IF;
        -- Attach staging table as a new partition for the month
        EXECUTE format(
            'ALTER TABLE bl_dm.fct_order_line_dd ATTACH PARTITION bl_dm.%I FOR VALUES FROM (%L) TO (%L)',
            v_stg_name, v_month_start, v_month_end
        );
        -- Rename staging partition to standard partition name
        EXECUTE format('ALTER TABLE bl_dm.%I RENAME TO %I', v_stg_name, v_part_name);
    END LOOP;
    CALL bl_cl.prc_write_log(v_proc, v_rows, 'SUCCESS', 'Rolling 3-month partitions swapped (empty refresh)');
EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.prc_write_log(v_proc, COALESCE(v_rows,0), 'ERROR', 'Partition swap failed', SQLERRM);
    RAISE;
END;
$$;



CALL bl_dm.prc_swap_fct_partitions_3m_empty();

/*
Incremental load of BL_3NF.CE_ORDER_LINES from BL_CL.WRK_B2C / BL_CL.WRK_B2B.
- LEFT JOIN used to avoid load failures
- Missing references mapped to -1 (unknown keys)
- Dedupe by UK: (order_line_src_id, source_system, source_entity)
*/

CREATE OR REPLACE PROCEDURE bl_3nf.prc_load_ce_order_lines_incr()
LANGUAGE plpgsql
AS $$
DECLARE
    v_proc  TEXT := 'bl_3nf.prc_load_ce_order_lines_incr';
    v_rows  INT  := 0;
    v_ins   INT  := 0;
BEGIN
    /* =========================
       B2C
       ========================= */
    INSERT INTO bl_3nf.ce_order_lines(
        order_line_id,
        order_line_src_id,
        contract_id,
        order_id,
        idea_id,
        quantity,
        gross_sales_amount,
        discount_amount,
        net_sales_amount,
        cost_amount,
        support_cost_amount,
        source_system,
        source_entity,
        ta_insert_dt,
        ta_update_dt
    )
    SELECT
        nextval('bl_3nf.seq_ce_order_lines_id'),
        w.order_line_id::varchar(100)                               AS order_line_src_id,

        -1::bigint                                                 AS contract_id,          -- B2C: no contracts
        COALESCE(o.order_id, -1)::bigint                            AS order_id,
        COALESCE(i.idea_id,  -1)::bigint                            AS idea_id,


      COALESCE(NULLIF(trim(w.quantity::text), '')::int, 0) AS quantity,

COALESCE(NULLIF(trim(w.gross_sales_amount::text), '')::numeric(15,2), 0)  AS gross_sales_amount,
COALESCE(NULLIF(trim(w.discount_amount::text), '')::numeric(15,2), 0)     AS discount_amount,
COALESCE(NULLIF(trim(w.net_sales_amount::text), '')::numeric(15,2), 0)    AS net_sales_amount,
COALESCE(NULLIF(trim(w.cost_amount::text), '')::numeric(15,2), 0)         AS cost_amount,
0::numeric(15,2) AS support_cost_amount,

        w.source_system::varchar(50)                                AS source_system,
        'WRK_B2C'::varchar(50)                                      AS source_entity,

        CURRENT_DATE                                                AS ta_insert_dt,
        CURRENT_DATE                                                AS ta_update_dt
    FROM bl_cl.wrk_b2c w
    LEFT JOIN bl_3nf.ce_orders o
           ON o.order_src_id   = w.order_id::varchar(100)
          AND o.source_system  = w.source_system::varchar(50)
          AND o.source_entity  = 'WRK_B2C'
    LEFT JOIN bl_3nf.ce_ideas i
           ON i.idea_src_id    = w.idea_id::varchar(100)
          AND i.source_system  = w.source_system::varchar(50)
          AND i.source_entity  = 'WRK_B2C'
    WHERE NOT EXISTS (
        SELECT 1
        FROM bl_3nf.ce_order_lines t
        WHERE t.order_line_src_id = w.order_line_id::varchar(100)
          AND t.source_system     = w.source_system::varchar(50)
          AND t.source_entity     = 'WRK_B2C'
    );

    GET DIAGNOSTICS v_ins = ROW_COUNT;
    v_rows := v_rows + v_ins;

    /* =========================
       B2B
       ========================= */
    INSERT INTO bl_3nf.ce_order_lines(
        order_line_id,
        order_line_src_id,
        contract_id,
        order_id,
        idea_id,
        quantity,
        gross_sales_amount,
        discount_amount,
        net_sales_amount,
        cost_amount,
        support_cost_amount,
        source_system,
        source_entity,
        ta_insert_dt,
        ta_update_dt
    )
    SELECT
        nextval('bl_3nf.seq_ce_order_lines_id'),
        w.order_line_id::varchar(100)                               AS order_line_src_id,

        COALESCE(c.contract_id, -1)::bigint                          AS contract_id,
        COALESCE(o.order_id,    -1)::bigint                          AS order_id,
        COALESCE(i.idea_id,     -1)::bigint                          AS idea_id,

COALESCE(NULLIF(trim(w.quantity::text), '')::int, 0) AS quantity,

COALESCE(NULLIF(trim(w.gross_sales_amount::text), '')::numeric(15,2), 0)  AS gross_sales_amount,
COALESCE(NULLIF(trim(w.discount_amount::text), '')::numeric(15,2), 0)     AS discount_amount,
COALESCE(NULLIF(trim(w.net_sales_amount::text), '')::numeric(15,2), 0)    AS net_sales_amount,
COALESCE(NULLIF(trim(w.cost_amount::text), '')::numeric(15,2), 0)         AS cost_amount,
COALESCE(NULLIF(trim(w.support_cost_amount::text), '')::numeric(15,2), 0) AS support_cost_amount,

        w.source_system::varchar(50)                                 AS source_system,
        'WRK_B2B'::varchar(50)                                       AS source_entity,

        CURRENT_DATE                                                 AS ta_insert_dt,
        CURRENT_DATE                                                 AS ta_update_dt
    FROM bl_cl.wrk_b2b w
    LEFT JOIN bl_3nf.ce_orders o
           ON o.order_src_id   = w.order_id::varchar(100)
          AND o.source_system  = w.source_system::varchar(50)
          AND o.source_entity  = 'WRK_B2B'
    LEFT JOIN bl_3nf.ce_contracts c
           ON c.contract_src_id = w.contract_id::varchar(100)
          AND c.source_system   = w.source_system::varchar(50)
          AND c.source_entity   = 'WRK_B2B'
    LEFT JOIN bl_3nf.ce_ideas i
           ON i.idea_src_id     = w.idea_id::varchar(100)
          AND i.source_system   = w.source_system::varchar(50)
          AND i.source_entity   = 'WRK_B2B'
    WHERE NOT EXISTS (
        SELECT 1
        FROM bl_3nf.ce_order_lines t
        WHERE t.order_line_src_id = w.order_line_id::varchar(100)
          AND t.source_system     = w.source_system::varchar(50)
          AND t.source_entity     = 'WRK_B2B'
    );

    GET DIAGNOSTICS v_ins = ROW_COUNT;
    v_rows := v_rows + v_ins;

    CALL bl_cl.prc_write_log(v_proc, v_rows, 'SUCCESS', 'Incremental load of CE_ORDER_LINES completed');

EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.prc_write_log(v_proc, COALESCE(v_rows,0), 'ERROR', '3NF fact load failed', SQLERRM);
    RAISE;
END;
$$;

CALL bl_3nf.prc_load_ce_order_lines_incr();


/*
Step 6.
Load DM fact BL_DM.FCT_ORDER_LINE_DD using monthly staging + partition swap (rolling 3 months).
Customer SCD2 mapping:
CE_ORDERS.customer_id -> BL_3NF.CE_CUSTOMERS_SCD (by date range) -> BL_DM.DIM_CUSTOMERS_SCD (by business key + date range).
All joins are LEFT JOIN, unknown keys are mapped to -1.
*/

CREATE OR REPLACE PROCEDURE bl_dm.prc_load_fct_order_line_dd_roll3m()
LANGUAGE plpgsql
AS $$
DECLARE
    v_proc TEXT := 'bl_dm.prc_load_fct_order_line_dd_roll3m';
    v_rows INT  := 0;
    v_ins  INT  := 0;

    v_asof        DATE;
    v_month_start DATE;
    v_month_end   DATE;
    v_i           INT;

    v_part_name TEXT;
    v_stg_name  TEXT;
BEGIN
    -- Anchor = max(order_dt), otherwise the window is empty
    SELECT COALESCE(MAX(order_dt), CURRENT_DATE)
    INTO v_asof
    FROM bl_3nf.ce_orders
    WHERE order_id <> -1;

    CALL bl_dm.prc_manage_fct_partitions_3m();

    FOR v_i IN 0..2 LOOP
        v_month_start := (date_trunc('month', v_asof)::date - (v_i || ' months')::interval)::date;
        v_month_end   := (v_month_start + INTERVAL '1 month')::date;

        v_part_name := format('fct_order_line_dd_p_%s', to_char(v_month_start,'YYYYMM'));
        v_stg_name  := format('fct_order_line_dd_stg_%s', to_char(v_month_start,'YYYYMM'));

        EXECUTE format('DROP TABLE IF EXISTS bl_dm.%I', v_stg_name);
        EXECUTE format('CREATE TABLE bl_dm.%I (LIKE bl_dm.fct_order_line_dd INCLUDING ALL)', v_stg_name);

        EXECUTE format($sql$
            INSERT INTO bl_dm.%I(
                event_dt, order_id, order_line_id,
                customer_surr_id, date_dt, contract_surr_id, idea_surr_id,
                country_id, city_id,
                gross_sales_amount, discount_amount, net_sales_amount,
                cost_amount, support_cost_amount, quantity_cnt,
                profit_amount, insert_dt
            )
            SELECT
                o.order_dt                                                      AS event_dt,
                o.order_id                                                      AS order_id,
                ol.order_line_id                                                AS order_line_id,

                COALESCE(dc.customer_surr_id, -1)                               AS customer_surr_id,
                o.order_dt                                                      AS date_dt,

                COALESCE(dct.contract_surr_id, -1)                              AS contract_surr_id,
                COALESCE(di.idea_surr_id, -1)                                   AS idea_surr_id,

                -1::bigint                 AS country_id,
                COALESCE(o.city_id, -1)    AS city_id,

                ol.gross_sales_amount,
                ol.discount_amount,
                ol.net_sales_amount,
                ol.cost_amount,
                ol.support_cost_amount,
                ol.quantity                                                     AS quantity_cnt,

                (ol.net_sales_amount - ol.cost_amount - ol.support_cost_amount) AS profit_amount,
                CURRENT_DATE                                                    AS insert_dt
            FROM bl_3nf.ce_order_lines ol
            JOIN bl_3nf.ce_orders o
              ON o.order_id = ol.order_id

            -- 3NF customer SCD2
            LEFT JOIN bl_3nf.ce_customers_scd c3
              ON c3.customer_id = o.customer_id
             AND o.order_dt >= c3.start_dt
             AND o.order_dt <  c3.end_dt

            -- DM customer SCD2
            LEFT JOIN bl_dm.dim_customers_scd dc
              ON dc.customer_src_id = c3.customer_src_id
             AND dc.customer_source = c3.source_system
             AND o.order_dt >= dc.start_dt
             AND o.order_dt <  dc.end_dt

            -- contracts
            LEFT JOIN bl_3nf.ce_contracts c
              ON c.contract_id = ol.contract_id
            LEFT JOIN bl_dm.dim_contracts dct
              ON dct.contract_src_id = c.contract_src_id
             AND dct.source_system   = c.source_system
             AND dct.source_entity   = c.source_entity

            -- ideas
            LEFT JOIN bl_3nf.ce_ideas i
              ON i.idea_id = ol.idea_id
            LEFT JOIN bl_dm.dim_ideas di
              ON di.idea_src_id    = i.idea_src_id
             AND di.source_system  = i.source_system
             AND di.source_entity  = i.source_entity

            WHERE o.order_dt >= %L::date
              AND o.order_dt <  %L::date
        $sql$, v_stg_name, v_month_start, v_month_end);

        GET DIAGNOSTICS v_ins = ROW_COUNT;
        v_rows := v_rows + v_ins;

        IF EXISTS (
            SELECT 1
            FROM pg_class c
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname='bl_dm' AND c.relname = v_part_name
        ) THEN
            EXECUTE format('ALTER TABLE bl_dm.fct_order_line_dd DETACH PARTITION bl_dm.%I', v_part_name);
            EXECUTE format('DROP TABLE IF EXISTS bl_dm.%I', v_part_name);
        END IF;

        EXECUTE format(
            'ALTER TABLE bl_dm.fct_order_line_dd ATTACH PARTITION bl_dm.%I FOR VALUES FROM (%L) TO (%L)',
            v_stg_name, v_month_start, v_month_end
        );

        EXECUTE format('ALTER TABLE bl_dm.%I RENAME TO %I', v_stg_name, v_part_name);
    END LOOP;

    CALL bl_cl.prc_write_log(v_proc, v_rows, 'SUCCESS', 'DM fact loaded via rolling 3-month partition swap (asof=max(order_dt))');
EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.prc_write_log(v_proc, COALESCE(v_rows,0), 'ERROR', 'DM fact load failed', SQLERRM);
    RAISE;
END;
$$;

CALL bl_dm.prc_load_fct_order_line_dd_roll3m();
