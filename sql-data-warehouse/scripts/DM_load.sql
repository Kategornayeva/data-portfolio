-- Grants for BL_CL role to write into BL_DM
GRANT USAGE ON SCHEMA bl_dm TO bl_cl;

GRANT SELECT, INSERT, UPDATE, DELETE
ON ALL TABLES IN SCHEMA bl_dm
TO bl_cl;

GRANT USAGE, SELECT
ON ALL SEQUENCES IN SCHEMA bl_dm
TO bl_cl;

ALTER DEFAULT PRIVILEGES IN SCHEMA bl_dm
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO bl_cl;

ALTER DEFAULT PRIVILEGES IN SCHEMA bl_dm
GRANT USAGE, SELECT ON SEQUENCES TO bl_cl;


CREATE TABLE IF NOT EXISTS bl_cl.etl_log (
    log_id         BIGSERIAL PRIMARY KEY,
    log_dt         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    procedure_name TEXT      NOT NULL,
    rows_affected  INTEGER   NOT NULL DEFAULT 0,
    status         TEXT      NOT NULL,      -- 'SUCCESS' / 'ERROR'
    message        TEXT      NULL,
    error_text     TEXT      NULL
);

SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'bl_cl'
  AND table_name = 'etl_log'
ORDER BY ordinal_position;


CREATE OR REPLACE PROCEDURE bl_cl.prc_write_log(
    p_procedure_name TEXT,
    p_rows_affected  INTEGER,
    p_status         TEXT,
    p_message        TEXT DEFAULT NULL,
    p_error_text     TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO bl_cl.etl_log(procedure_name, rows_affected, status, message, error_text)
    VALUES (p_procedure_name, COALESCE(p_rows_affected,0), p_status, p_message, p_error_text);
END;
$$;

CREATE TYPE bl_cl.t_dim_ideas_row AS (
    idea_src_id            varchar(100),
    idea_title             varchar(500),
    idea_version           varchar(50),
    idea_category_id       varchar(100),
    idea_category_name     varchar(255),
    idea_subcategory_id    varchar(100),
    idea_subcategory_name  varchar(255),
    industry_domain_src_id varchar(100),
    industry_domain_name   varchar(255),
    author_src_id          varchar(100),
    author_name            varchar(255),
    source_system          varchar(50),
    source_entity          varchar(50)
);

CREATE OR REPLACE PROCEDURE bl_cl.prc_load_dim_ideas()
LANGUAGE plpgsql
AS
$$
DECLARE
    -- Procedure name for logging
    v_proc_name      TEXT := 'bl_cl.prc_load_dim_ideas';

    -- Counter of affected rows (for logging and rerun validation)
    v_rows_affected  INTEGER := 0;
    v_rc             INTEGER := 0;

    -- Dynamic SQL text (required by assignment)
    v_sql            TEXT;

    -- Cursor variable
    c_ideas          REFCURSOR;

    -- Variable of composite type (one row from source)
    v_row            bl_cl.t_dim_ideas_row;
BEGIN

    ------------------------------------------------------------------
    -- 1. Ensure default (-1) row exists in dimension table
    --    This guarantees referential integrity for unknown values
    ------------------------------------------------------------------
    INSERT INTO bl_dm.dim_ideas (
        idea_surr_id,
        idea_src_id,
        idea_title,
        idea_version,
        idea_category_id,
        idea_category_name,
        idea_subcategory_id,
        idea_subcategory_name,
        industry_domain_src_id,
        industry_domain_name,
        author_src_id,
        author_name,
        insert_dt,
        update_dt,
        source_system,
        source_entity
    )
    SELECT
        -1,
        'n.a.',
        'n.a.',
        'n.a.',
        'n.a.',
        'n.a.',
        'n.a.',
        'n.a.',
        'n.a.',
        'n.a.',
        'n.a.',
        'n.a.',
        CURRENT_DATE,
        CURRENT_DATE,
        'MANUAL',
        'MANUAL'
    WHERE NOT EXISTS (
        SELECT 1
        FROM bl_dm.dim_ideas
        WHERE idea_surr_id = -1
    );

    GET DIAGNOSTICS v_rc = ROW_COUNT;
    v_rows_affected := v_rows_affected + v_rc;

    ------------------------------------------------------------------
    -- 2. Build dynamic SQL to extract flattened idea data from BL_3NF
    ------------------------------------------------------------------
    v_sql := $q$
        SELECT
            i.idea_src_id,
            i.idea_title,
            i.idea_version,

            c.category_src_id,
            c.category_name,

            s.subcategory_src_id,
            s.subcategory_name,

            d.industry_domain_src_id,
            d.industry_domain_name,

            a.author_src_id,
            a.author_name,

            i.source_system,
            i.source_entity
        FROM bl_3nf.ce_ideas i
        JOIN bl_3nf.ce_authors a
          ON a.author_id = i.author_id
        JOIN bl_3nf.ce_subcategories s
          ON s.subcategory_id = i.subcategory_id
        JOIN bl_3nf.ce_categories c
          ON c.category_id = s.category_id
        JOIN bl_3nf.ce_industry_domains d
          ON d.industry_domain_id = i.industry_domain_id
    $q$;

    ------------------------------------------------------------------
    -- 3. Open cursor using dynamic SQL
    ------------------------------------------------------------------
    OPEN c_ideas FOR EXECUTE v_sql;

    LOOP
        FETCH c_ideas INTO v_row;
        EXIT WHEN NOT FOUND;

        ------------------------------------------------------------------
        -- 4. UPSERT logic (SCD Type 1 behavior)
        --    Insert new row or update existing one if attributes changed
        ------------------------------------------------------------------
        INSERT INTO bl_dm.dim_ideas (
            idea_surr_id,
            idea_src_id,
            idea_title,
            idea_version,
            idea_category_id,
            idea_category_name,
            idea_subcategory_id,
            idea_subcategory_name,
            industry_domain_src_id,
            industry_domain_name,
            author_src_id,
            author_name,
            insert_dt,
            update_dt,
            source_system,
            source_entity
        )
        VALUES (
            nextval('bl_dm.seq_dim_ideas'),
            v_row.idea_src_id,
            v_row.idea_title,
            v_row.idea_version,
            v_row.idea_category_id,
            v_row.idea_category_name,
            v_row.idea_subcategory_id,
            v_row.idea_subcategory_name,
            v_row.industry_domain_src_id,
            v_row.industry_domain_name,
            v_row.author_src_id,
            v_row.author_name,
            CURRENT_DATE,
            CURRENT_DATE,
            v_row.source_system,
            v_row.source_entity
           )
        ON CONFLICT (idea_src_id, source_system, source_entity)
        DO UPDATE SET
            idea_title             = EXCLUDED.idea_title,
            idea_version           = EXCLUDED.idea_version,
            idea_category_id       = EXCLUDED.idea_category_id,
            idea_category_name     = EXCLUDED.idea_category_name,
            idea_subcategory_id    = EXCLUDED.idea_subcategory_id,
            idea_subcategory_name  = EXCLUDED.idea_subcategory_name,
            industry_domain_src_id = EXCLUDED.industry_domain_src_id,
            industry_domain_name   = EXCLUDED.industry_domain_name,
            author_src_id          = EXCLUDED.author_src_id,
            author_name            = EXCLUDED.author_name,
            update_dt              = CURRENT_DATE
        WHERE
            bl_dm.dim_ideas.idea_title IS DISTINCT FROM EXCLUDED.idea_title OR
            bl_dm.dim_ideas.idea_version IS DISTINCT FROM EXCLUDED.idea_version OR
            bl_dm.dim_ideas.idea_category_id IS DISTINCT FROM EXCLUDED.idea_category_id OR
            bl_dm.dim_ideas.idea_category_name IS DISTINCT FROM EXCLUDED.idea_category_name OR
            bl_dm.dim_ideas.idea_subcategory_id IS DISTINCT FROM EXCLUDED.idea_subcategory_id OR
            bl_dm.dim_ideas.idea_subcategory_name IS DISTINCT FROM EXCLUDED.idea_subcategory_name OR
            bl_dm.dim_ideas.industry_domain_src_id IS DISTINCT FROM EXCLUDED.industry_domain_src_id OR
            bl_dm.dim_ideas.industry_domain_name IS DISTINCT FROM EXCLUDED.industry_domain_name OR
            bl_dm.dim_ideas.author_src_id IS DISTINCT FROM EXCLUDED.author_src_id OR
            bl_dm.dim_ideas.author_name IS DISTINCT FROM EXCLUDED.author_name;

        GET DIAGNOSTICS v_rc = ROW_COUNT;
        v_rows_affected := v_rows_affected + v_rc;

    END LOOP;

    CLOSE c_ideas;

    ------------------------------------------------------------------
    -- 5. Write SUCCESS log entry
    ------------------------------------------------------------------
    CALL bl_cl.prc_write_log(
        v_proc_name,
        v_rows_affected,
        'SUCCESS',
        'DIM_IDEAS load completed successfully',
        NULL
    );

EXCEPTION
    WHEN OTHERS THEN
        ------------------------------------------------------------------
        -- Write ERROR log entry
        ------------------------------------------------------------------
        CALL bl_cl.prc_write_log(
            v_proc_name,
            COALESCE(v_rows_affected, 0),
            'ERROR',
            'DIM_IDEAS load failed',
            SQLERRM
        );
        RAISE;
END;
$$;


CREATE OR REPLACE PROCEDURE bl_cl.prc_load_dm_dim_contracts()
LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
    v_rows INTEGER := 0;

    cur_contracts CURSOR FOR
        SELECT
            c.contract_src_id,
            c.purchase_type,
            c.license_type,
            c.seats AS seats_cnt,
            COALESCE(am.account_manager_src_id, 'n.a.') AS account_manager_src_id,
            COALESCE(am.account_manager_name,   'n.a.') AS account_manager_name,
            c.source_system,
            c.source_entity
        FROM bl_3nf.ce_contracts c
        LEFT JOIN bl_3nf.ce_account_managers am
          ON am.account_manager_id = c.account_manager_id
        WHERE c.contract_id <> -1;
BEGIN
    OPEN cur_contracts;

    LOOP
        FETCH cur_contracts INTO r;
        EXIT WHEN NOT FOUND;

        IF NOT EXISTS (
            SELECT 1
            FROM bl_dm.dim_contracts d
            WHERE d.contract_src_id = r.contract_src_id
              AND d.source_system   = r.source_system
              AND d.source_entity   = r.source_entity
        ) THEN
            INSERT INTO bl_dm.dim_contracts (
                contract_surr_id,
                contract_src_id,
                purchase_type,
                license_type,
                seats_cnt,
                account_manager_src_id,
                account_manager_name,
                insert_dt,
                update_dt,
                source_system,
                source_entity
            )
            VALUES (
                nextval('bl_dm.seq_dim_contracts'),
                r.contract_src_id,
                COALESCE(r.purchase_type, 'n.a.'),
                COALESCE(r.license_type,  'n.a.'),
                COALESCE(r.seats_cnt, 0),
                r.account_manager_src_id,
                r.account_manager_name,
                CURRENT_DATE,
                CURRENT_DATE,
                r.source_system,
                r.source_entity
            );

            v_rows := v_rows + 1;
        END IF;

    END LOOP;

    CLOSE cur_contracts;

    CALL bl_cl.prc_write_log(
        'prc_load_dm_dim_contracts',
        v_rows,
        'SUCCESS',
        'DIM_CONTRACTS loaded (no contract dates in DIM)',
        NULL
    );

EXCEPTION WHEN OTHERS THEN
    BEGIN
        CLOSE cur_contracts;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    CALL bl_cl.prc_write_log(
        'prc_load_dm_dim_contracts',
        0,
        'ERROR',
        'Error loading DIM_CONTRACTS',
        SQLERRM
    );
END;
$$;

CALL bl_cl.prc_load_dm_dim_contracts();

SELECT *
FROM bl_cl.etl_log
WHERE procedure_name = 'prc_load_dm_dim_contracts'
ORDER BY log_dt DESC
LIMIT 5;


CREATE OR REPLACE PROCEDURE bl_cl.prc_load_dm_dim_customers_scd()
LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
    v_rows_closed  INTEGER := 0;
    v_rows_insert  INTEGER := 0;
    v_tmp          INTEGER;
BEGIN
    FOR r IN
        SELECT
            s.customer_src_id,
            s.customer_name,
            s.customer_email,
            s.device_type,
            s.payment_method,
            s.company_name,
            s.company_industry,
            s.tax_id,
            s.source_system,
            s.source_entity
        FROM bl_3nf.ce_customers_scd s
        WHERE s.is_active = 'Y'
          AND s.customer_id <> -1
    LOOP
        -- 1) Если уже есть идентичная активная запись в DM — ничего не делаем (repeatable)
        IF EXISTS (
            SELECT 1
            FROM bl_dm.dim_customers_scd d
            WHERE d.customer_src_id = r.customer_src_id
              AND d.customer_source = r.source_system
              AND d.is_active = 'Y'
              AND d.customer_name    IS NOT DISTINCT FROM r.customer_name
              AND d.customer_email   IS NOT DISTINCT FROM r.customer_email
              AND d.device_type      IS NOT DISTINCT FROM r.device_type
              AND d.payment_method   IS NOT DISTINCT FROM r.payment_method
              AND d.company_name     IS NOT DISTINCT FROM r.company_name
              AND d.company_industry IS NOT DISTINCT FROM r.company_industry
              AND d.tax_id           IS NOT DISTINCT FROM r.tax_id
        ) THEN
            CONTINUE;
        END IF;

        -- 2) Раз собираемся вставлять новую версию -> закрываем ВСЕ активные по ключу уникальности
        UPDATE bl_dm.dim_customers_scd d
        SET end_dt = CURRENT_DATE - 1,
            is_active = 'N'
        WHERE d.customer_src_id = r.customer_src_id
          AND d.customer_source = r.source_system
          AND d.is_active = 'Y';

        GET DIAGNOSTICS v_tmp = ROW_COUNT;
        v_rows_closed := v_rows_closed + v_tmp;

        -- 3) Вставляем новую активную версию
        INSERT INTO bl_dm.dim_customers_scd (
            customer_surr_id,
            customer_src_id,
            customer_source,
            customer_name,
            customer_email,
            device_type,
            payment_method,
            company_name,
            company_industry,
            tax_id,
            start_dt,
            end_dt,
            is_active,
            insert_dt,
            source_system,
            source_entity
        )
        VALUES (
            nextval('bl_dm.seq_dim_customers_scd'),
            r.customer_src_id,
            r.source_system,
            r.customer_name,
            r.customer_email,
            r.device_type,
            r.payment_method,
            r.company_name,
            r.company_industry,
            r.tax_id,
            CURRENT_DATE,
            DATE '9999-12-31',
            'Y',
            CURRENT_DATE,
            r.source_system,
            r.source_entity
        );

        v_rows_insert := v_rows_insert + 1;
    END LOOP;

    CALL bl_cl.prc_write_log(
        'prc_load_dm_dim_customers_scd',
        v_rows_closed + v_rows_insert,
        'SUCCESS',
        'DIM_CUSTOMERS_SCD loaded successfully',
        NULL
    );

EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.prc_write_log(
        'prc_load_dm_dim_customers_scd',
        0,
        'ERROR',
        'Error loading DIM_CUSTOMERS_SCD',
        SQLERRM
    );
END;
$$;


CALL bl_cl.prc_load_dm_dim_customers_scd();
