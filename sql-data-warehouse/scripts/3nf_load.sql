CREATE ROLE bl_cl LOGIN PASSWORD 'bl_cl_pwd';
GRANT USAGE ON SCHEMA bl_cl TO bl_cl;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA bl_cl TO bl_cl;

GRANT USAGE ON SCHEMA bl_3nf TO bl_cl;

GRANT SELECT, INSERT, UPDATE, DELETE
ON ALL TABLES IN SCHEMA bl_3nf
TO bl_cl;

GRANT USAGE, SELECT
ON ALL SEQUENCES IN SCHEMA bl_3nf
TO bl_cl;

ALTER DEFAULT PRIVILEGES IN SCHEMA bl_3nf
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO bl_cl;

ALTER DEFAULT PRIVILEGES IN SCHEMA bl_3nf
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

CALL bl_cl.prc_write_log('test_log', 123, 'SUCCESS', 'logging check', NULL);


CREATE OR REPLACE FUNCTION bl_cl.fn_ce_countries()
RETURNS TABLE (
    country_src_id VARCHAR,
    country_name   VARCHAR,
    source_system  VARCHAR,
    source_entity  VARCHAR
)
LANGUAGE sql
AS $$
    SELECT DISTINCT
        country_id      AS country_src_id,
        country         AS country_name,
        source_system,
        'WRK_B2C'       AS source_entity
    FROM bl_cl.wrk_b2c
    WHERE country_id IS NOT NULL

    UNION

    SELECT DISTINCT
        country_id,
        country,
        source_system,
        'WRK_B2B'
    FROM bl_cl.wrk_b2b
    WHERE country_id IS NOT NULL;
$$;


CREATE OR REPLACE PROCEDURE bl_cl.prc_load_ce_countries()
LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
    v_rows INTEGER := 0;
BEGIN

    FOR r IN SELECT * FROM bl_cl.fn_ce_countries()
    LOOP
        INSERT INTO bl_3nf.ce_countries (
            country_id,
            country_src_id,
            country_name,
            source_system,
            source_entity,
            ta_insert_dt,
            ta_update_dt
        )
        VALUES (
            nextval('bl_3nf.seq_ce_countries_id'),
            r.country_src_id,
            r.country_name,
            r.source_system,
            r.source_entity,
            CURRENT_DATE,
            CURRENT_DATE
        )
        ON CONFLICT ON CONSTRAINT uk_ce_countries_src
        DO NOTHING;

        IF FOUND THEN
            v_rows := v_rows + 1;
        END IF;

    END LOOP;

    CALL bl_cl.prc_write_log(
        'prc_load_ce_countries',
        v_rows,
        'SUCCESS',
        'Countries loaded successfully',
        NULL
    );

EXCEPTION WHEN OTHERS THEN

    CALL bl_cl.prc_write_log(
        'prc_load_ce_countries',
        0,
        'ERROR',
        'Error during loading',
        SQLERRM
    );

END;
$$;


CALL bl_cl.prc_load_ce_countries();


CREATE OR REPLACE FUNCTION bl_cl.fn_ce_categories()
RETURNS TABLE (
    category_src_id VARCHAR,
    category_name   VARCHAR,
    source_system   VARCHAR,
    source_entity   VARCHAR
)
LANGUAGE sql
AS $$

    SELECT DISTINCT
        category_id    AS category_src_id,
        category       AS category_name,
        source_system,
        'WRK_B2C'      AS source_entity
    FROM bl_cl.wrk_b2c
    WHERE category_id IS NOT NULL

    UNION

    SELECT DISTINCT
        category_id,
        category,
        source_system,
        'WRK_B2B'
    FROM bl_cl.wrk_b2b
    WHERE category_id IS NOT NULL;
$$;

CALL bl_cl.prc_load_dim_ideas();



CREATE OR REPLACE FUNCTION bl_cl.fn_ce_countries()
RETURNS TABLE (
    country_src_id VARCHAR,
    country_name   VARCHAR,
    source_system  VARCHAR,
    source_entity  VARCHAR
)
LANGUAGE sql
AS $$
    SELECT DISTINCT
        country_id    AS country_src_id,
        country       AS country_name,
        source_system,
        'WRK_B2C'     AS source_entity
    FROM bl_cl.wrk_b2c
    WHERE country_id IS NOT NULL

    UNION

    SELECT DISTINCT
        country_id    AS country_src_id,
        country       AS country_name,
        source_system,
        'WRK_B2B'     AS source_entity
    FROM bl_cl.wrk_b2b
    WHERE country_id IS NOT NULL;
$$;


CREATE OR REPLACE PROCEDURE bl_cl.prc_load_ce_countries()
LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
    v_rows INTEGER := 0;
BEGIN

    FOR r IN SELECT * FROM bl_cl.fn_ce_countries()
    LOOP
        INSERT INTO bl_3nf.ce_countries (
            country_id,
            country_src_id,
            country_name,
            source_system,
            source_entity,
            ta_insert_dt,
            ta_update_dt
        )
        VALUES (
            nextval('bl_3nf.seq_ce_countries_id'),
            r.country_src_id,
            r.country_name,
            r.source_system,
            r.source_entity,
            CURRENT_DATE,
            CURRENT_DATE
        )
        ON CONFLICT ON CONSTRAINT uk_ce_countries_src
        DO NOTHING;

        IF FOUND THEN
            v_rows := v_rows + 1;
        END IF;

    END LOOP;

    CALL bl_cl.prc_write_log(
        'prc_load_ce_countries',
        v_rows,
        'SUCCESS',
        'Countries loaded successfully',
        NULL
    );

EXCEPTION WHEN OTHERS THEN

    CALL bl_cl.prc_write_log(
        'prc_load_ce_countries',
        0,
        'ERROR',
        'Error during loading',
        SQLERRM
    );

END;
$$;

CALL bl_cl.prc_load_ce_countries();


CREATE OR REPLACE FUNCTION bl_cl.fn_ce_categories()
RETURNS TABLE (
    category_src_id VARCHAR,
    category_name   VARCHAR,
    source_system   VARCHAR,
    source_entity   VARCHAR
)
LANGUAGE sql
AS $$
    SELECT DISTINCT
        category_id AS category_src_id,
        category    AS category_name,
        source_system,
        'WRK_B2C'   AS source_entity
    FROM bl_cl.wrk_b2c
    WHERE category_id IS NOT NULL

    UNION

    SELECT DISTINCT
        category_id AS category_src_id,
        category    AS category_name,
        source_system,
        'WRK_B2B'   AS source_entity
    FROM bl_cl.wrk_b2b
    WHERE category_id IS NOT NULL;
$$;


CREATE OR REPLACE PROCEDURE bl_cl.prc_load_ce_categories()
LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
    v_rows INTEGER := 0;
BEGIN
    FOR r IN SELECT * FROM bl_cl.fn_ce_categories()
    LOOP
        INSERT INTO bl_3nf.ce_categories (
            category_id,
            category_src_id,
            category_name,
            source_system,
            source_entity,
            ta_insert_dt,
            ta_update_dt
        )
        VALUES (
            nextval('bl_3nf.seq_ce_categories_id'),
            r.category_src_id,
            r.category_name,
            r.source_system,
            r.source_entity,
            CURRENT_DATE,
            CURRENT_DATE
        )
        ON CONFLICT ON CONSTRAINT uk_ce_categories_src
        DO NOTHING;
        IF FOUND THEN
            v_rows := v_rows + 1;
        END IF;
    END LOOP;
    CALL bl_cl.prc_write_log(
        'prc_load_ce_categories',
        v_rows,
        'SUCCESS',
        'Categories loaded successfully',
        NULL
    );
EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.prc_write_log(
        'prc_load_ce_categories',
        0,
        'ERROR',
        'Error during loading',
        SQLERRM
    );

END;
$$;

CALL bl_cl.prc_load_ce_categories();


CREATE OR REPLACE FUNCTION bl_cl.fn_ce_subcategories()
RETURNS TABLE (
    subcategory_src_id VARCHAR,
    subcategory_name   VARCHAR,
    category_src_id    VARCHAR,
    source_system      VARCHAR,
    source_entity      VARCHAR
)
LANGUAGE sql
AS $$
    SELECT DISTINCT
        subcategory_id AS subcategory_src_id,
        subcategory    AS subcategory_name,
        category_id    AS category_src_id,
        source_system,
        'WRK_B2C'      AS source_entity
    FROM bl_cl.wrk_b2c
    WHERE subcategory_id IS NOT NULL

    UNION

    SELECT DISTINCT
        subcategory_id AS subcategory_src_id,
        subcategory    AS subcategory_name,
        category_id    AS category_src_id,
        source_system,
        'WRK_B2B'      AS source_entity
    FROM bl_cl.wrk_b2b
    WHERE subcategory_id IS NOT NULL;
$$;

CREATE OR REPLACE PROCEDURE bl_cl.prc_load_ce_subcategories()
LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
    v_category_id BIGINT;
    v_rows INTEGER := 0;
BEGIN

    FOR r IN SELECT * FROM bl_cl.fn_ce_subcategories()
    LOOP
        -- obtain the category surrogate key
        SELECT category_id
        INTO v_category_id
        FROM bl_3nf.ce_categories
        WHERE category_src_id = r.category_src_id
          AND source_system   = r.source_system
          AND source_entity   = r.source_entity;

        -- If the category is found
        IF v_category_id IS NOT NULL THEN

            INSERT INTO bl_3nf.ce_subcategories (
                subcategory_id,
                subcategory_src_id,
                category_id,
                subcategory_name,
                source_system,
                source_entity,
                ta_insert_dt,
                ta_update_dt
            )
            VALUES (
                nextval('bl_3nf.seq_ce_subcategories_id'),
                r.subcategory_src_id,
                v_category_id,
                r.subcategory_name,
                r.source_system,
                r.source_entity,
                CURRENT_DATE,
                CURRENT_DATE
            )
            ON CONFLICT ON CONSTRAINT uk_ce_subcategories_src
            DO NOTHING;

            IF FOUND THEN
                v_rows := v_rows + 1;
            END IF;

        END IF;

    END LOOP;

    CALL bl_cl.prc_write_log(
        'prc_load_ce_subcategories',
        v_rows,
        'SUCCESS',
        'Subcategories loaded successfully',
        NULL
    );

EXCEPTION WHEN OTHERS THEN

    CALL bl_cl.prc_write_log(
        'prc_load_ce_subcategories',
        0,
        'ERROR',
        'Error during loading',
        SQLERRM
    );

END;
$$;

CALL bl_cl.prc_load_ce_subcategories();


CREATE OR REPLACE FUNCTION bl_cl.fn_ce_industry_domains()
RETURNS TABLE (
    industry_domain_src_id VARCHAR,
    industry_domain_name   VARCHAR,
    source_system          VARCHAR,
    source_entity          VARCHAR
)
LANGUAGE sql
AS $$
    SELECT DISTINCT
        industry_domain_id AS industry_domain_src_id,
        industry_domain    AS industry_domain_name,
        source_system,
        'WRK_B2C'          AS source_entity
    FROM bl_cl.wrk_b2c
    WHERE industry_domain_id IS NOT NULL

    UNION

    SELECT DISTINCT
        industry_domain_id AS industry_domain_src_id,
        industry_domain    AS industry_domain_name,
        source_system,
        'WRK_B2B'          AS source_entity
    FROM bl_cl.wrk_b2b
    WHERE industry_domain_id IS NOT NULL;
$$;



CREATE OR REPLACE PROCEDURE bl_cl.prc_load_ce_industry_domains()
LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
    v_rows INTEGER := 0;
BEGIN

    FOR r IN SELECT * FROM bl_cl.fn_ce_industry_domains()
    LOOP
        INSERT INTO bl_3nf.ce_industry_domains (
            industry_domain_id,
            industry_domain_src_id,
            industry_domain_name,
            source_system,
            source_entity,
            ta_insert_dt,
            ta_update_dt
        )
        VALUES (
            nextval('bl_3nf.seq_ce_industry_domains_id'),
            r.industry_domain_src_id,
            r.industry_domain_name,
            r.source_system,
            r.source_entity,
            CURRENT_DATE,
            CURRENT_DATE
        )
        ON CONFLICT ON CONSTRAINT uk_ce_industry_domains_src
        DO NOTHING;

        IF FOUND THEN
            v_rows := v_rows + 1;
        END IF;

    END LOOP;

    CALL bl_cl.prc_write_log(
        'prc_load_ce_industry_domains',
        v_rows,
        'SUCCESS',
        'Industry domains loaded successfully',
        NULL
    );

EXCEPTION WHEN OTHERS THEN

    CALL bl_cl.prc_write_log(
        'prc_load_ce_industry_domains',
        0,
        'ERROR',
        'Error during loading',
        SQLERRM
    );

END;
$$;


CALL bl_cl.prc_load_ce_industry_domains();


CREATE OR REPLACE FUNCTION bl_cl.fn_ce_authors()
RETURNS TABLE (
    author_src_id VARCHAR,
    author_name   VARCHAR,
    source_system VARCHAR,
    source_entity VARCHAR
)
LANGUAGE sql
AS $$
    SELECT DISTINCT
        author_id   AS author_src_id,
        author_name AS author_name,
        source_system,
        'WRK_B2C'   AS source_entity
    FROM bl_cl.wrk_b2c
    WHERE author_id IS NOT NULL

    UNION

    SELECT DISTINCT
        author_id,
        author_name,
        source_system,
        'WRK_B2B'   AS source_entity
    FROM bl_cl.wrk_b2b
    WHERE author_id IS NOT NULL;
$$;


CREATE OR REPLACE PROCEDURE bl_cl.prc_load_ce_authors()
LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
    v_rows INTEGER := 0;
BEGIN

    FOR r IN SELECT * FROM bl_cl.fn_ce_authors()
    LOOP
        INSERT INTO bl_3nf.ce_authors (
            author_id,
            author_src_id,
            author_name,
            source_system,
            source_entity,
            ta_insert_dt,
            ta_update_dt
        )
        VALUES (
            nextval('bl_3nf.seq_ce_authors_id'),
            r.author_src_id,
            r.author_name,
            r.source_system,
            r.source_entity,
            CURRENT_DATE,
            CURRENT_DATE
        )
        ON CONFLICT ON CONSTRAINT uk_ce_authors_src
        DO NOTHING;

        IF FOUND THEN
            v_rows := v_rows + 1;
        END IF;

    END LOOP;

    CALL bl_cl.prc_write_log(
        'prc_load_ce_authors',
        v_rows,
        'SUCCESS',
        'Authors loaded successfully',
        NULL
    );

EXCEPTION WHEN OTHERS THEN

    CALL bl_cl.prc_write_log(
        'prc_load_ce_authors',
        0,
        'ERROR',
        'Error during loading',
        SQLERRM
    );

END;
$$;

CALL bl_cl.prc_load_ce_authors();


CREATE OR REPLACE FUNCTION bl_cl.fn_ce_account_managers()
RETURNS TABLE (
    account_manager_src_id   VARCHAR,
    account_manager_name     VARCHAR,
    source_system            VARCHAR,
    source_entity            VARCHAR
)
LANGUAGE sql
AS $$
    SELECT DISTINCT
        account_manager_id   AS account_manager_src_id,
        account_manager_name AS account_manager_name,
        source_system,
        'WRK_B2B'            AS source_entity
    FROM bl_cl.wrk_b2b
    WHERE account_manager_id IS NOT NULL;
$$;



CREATE OR REPLACE PROCEDURE bl_cl.prc_load_ce_account_managers()
LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
    v_rows INTEGER := 0;
BEGIN

    FOR r IN SELECT * FROM bl_cl.fn_ce_account_managers()
    LOOP
        INSERT INTO bl_3nf.ce_account_managers (
            account_manager_id,
            account_manager_src_id,
            account_manager_name,
            source_system,
            source_entity,
            ta_insert_dt,
            ta_update_dt
        )
        VALUES (
            nextval('bl_3nf.seq_ce_account_managers_id'),
            r.account_manager_src_id,
            r.account_manager_name,
            r.source_system,
            r.source_entity,
            CURRENT_DATE,
            CURRENT_DATE
        )
        ON CONFLICT ON CONSTRAINT uk_ce_account_managers_src
        DO NOTHING;

        IF FOUND THEN
            v_rows := v_rows + 1;
        END IF;

    END LOOP;

    CALL bl_cl.prc_write_log(
        'prc_load_ce_account_managers',
        v_rows,
        'SUCCESS',
        'Account managers loaded successfully',
        NULL
    );

EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.prc_write_log(
        'prc_load_ce_account_managers',
        0,
        'ERROR',
        'Error during loading',
        SQLERRM
    );
END;
$$;


CALL bl_cl.prc_load_ce_account_managers();


CREATE OR REPLACE FUNCTION bl_cl.fn_ce_customers_scd_src()
RETURNS TABLE (
    customer_src_id    VARCHAR,
    customer_name      VARCHAR,
    customer_email     VARCHAR,
    device_type        VARCHAR,
    payment_method     VARCHAR,
    company_name       VARCHAR,
    company_industry   VARCHAR,
    tax_id             VARCHAR,
    source_system      VARCHAR,
    source_entity      VARCHAR
)
LANGUAGE sql
AS $$
    SELECT *
    FROM (
        SELECT DISTINCT ON (customer_id, source_system)
            customer_id       AS customer_src_id,
            customer_name,
            customer_email,
            device_type,
            payment_method,
            'N/A'             AS company_name,
            'N/A'             AS company_industry,
            'N/A'             AS tax_id,
            source_system,
            'WRK_B2C'         AS source_entity
        FROM bl_cl.wrk_b2c
        WHERE customer_id IS NOT NULL
        ORDER BY
            customer_id,
            source_system,
            CASE
                WHEN NULLIF(order_date,'') ~ '^\d{1,2}/\d{1,2}/\d{4}$'
                    THEN to_date(NULLIF(order_date,''), 'MM/DD/YYYY')
                WHEN NULLIF(order_date,'') ~ '^\d{4}-\d{2}-\d{2}$'
                    THEN to_date(NULLIF(order_date,''), 'YYYY-MM-DD')
                ELSE NULL
            END DESC NULLS LAST
    ) b2c

    UNION ALL

    SELECT *
    FROM (
        SELECT DISTINCT ON (customer_id, source_system)
            customer_id        AS customer_src_id,
            company_name       AS customer_name,
            NULL               AS customer_email,
            'N/A'              AS device_type,
            'N/A'              AS payment_method,
            company_name,
            company_industry,
            tax_id,
            source_system,
            'WRK_B2B'          AS source_entity
        FROM bl_cl.wrk_b2b
        WHERE customer_id IS NOT NULL
        ORDER BY
            customer_id,
            source_system,
            CASE
                WHEN NULLIF(order_date,'') ~ '^\d{1,2}/\d{1,2}/\d{4}$'
                    THEN to_date(NULLIF(order_date,''), 'MM/DD/YYYY')
                WHEN NULLIF(order_date,'') ~ '^\d{4}-\d{2}-\d{2}$'
                    THEN to_date(NULLIF(order_date,''), 'YYYY-MM-DD')
                ELSE NULL
            END DESC NULLS LAST
    ) b2b;
$$;



CREATE OR REPLACE PROCEDURE bl_cl.prc_load_ce_customers_scd()
LANGUAGE plpgsql
AS $$
DECLARE
    r RECORD;
    v_rows INTEGER := 0;

    v_active RECORD;
    v_today DATE := CURRENT_DATE;
    v_open_end DATE := DATE '9999-12-31';
BEGIN

    FOR r IN SELECT * FROM bl_cl.fn_ce_customers_scd_src()
    LOOP
        -- find active record
        SELECT *
        INTO v_active
        FROM bl_3nf.ce_customers_scd
        WHERE customer_src_id = r.customer_src_id
          AND source_system   = r.source_system
          AND source_entity   = r.source_entity
          AND is_active       = 'Y'
        LIMIT 1;

        -- if no active record -> insert new
        IF NOT FOUND THEN
            INSERT INTO bl_3nf.ce_customers_scd (
                customer_id,
                start_dt, end_dt, is_active,
                customer_src_id,
                customer_name, customer_email, device_type, payment_method,
                company_name, company_industry, tax_id,
                source_system, source_entity,
                ta_insert_dt
            )
            VALUES (
                nextval('bl_3nf.seq_ce_customers_id'),
                v_today, v_open_end, 'Y',
                r.customer_src_id,
                r.customer_name,
                COALESCE(r.customer_email,'N/A'),
                COALESCE(r.device_type,'N/A'),
                COALESCE(r.payment_method,'N/A'),
                COALESCE(r.company_name,'N/A'),
                COALESCE(r.company_industry,'N/A'),
                COALESCE(r.tax_id,'N/A'),
                r.source_system, r.source_entity,
                v_today
            );
            v_rows := v_rows + 1;

        ELSE
            -- compare attributes; if changed -> close old + insert new
            IF v_active.customer_name    IS DISTINCT FROM r.customer_name
            OR v_active.customer_email   IS DISTINCT FROM COALESCE(r.customer_email,'N/A')
            OR v_active.device_type      IS DISTINCT FROM COALESCE(r.device_type,'N/A')
            OR v_active.payment_method   IS DISTINCT FROM COALESCE(r.payment_method,'N/A')
            OR v_active.company_name     IS DISTINCT FROM COALESCE(r.company_name,'N/A')
            OR v_active.company_industry IS DISTINCT FROM COALESCE(r.company_industry,'N/A')
            OR v_active.tax_id           IS DISTINCT FROM COALESCE(r.tax_id,'N/A')
            THEN
                -- close old record
                UPDATE bl_3nf.ce_customers_scd
                SET end_dt = v_today - 1,
                    is_active = 'N'
                WHERE customer_id = v_active.customer_id
                  AND start_dt    = v_active.start_dt;

                -- insert new version
                INSERT INTO bl_3nf.ce_customers_scd (
                    customer_id,
                    start_dt, end_dt, is_active,
                    customer_src_id,
                    customer_name, customer_email, device_type, payment_method,
                    company_name, company_industry, tax_id,
                    source_system, source_entity,
                    ta_insert_dt
                )
                VALUES (
                    nextval('bl_3nf.seq_ce_customers_id'),
                    v_today, v_open_end, 'Y',
                    r.customer_src_id,
                    r.customer_name,
                    COALESCE(r.customer_email,'N/A'),
                    COALESCE(r.device_type,'N/A'),
                    COALESCE(r.payment_method,'N/A'),
                    COALESCE(r.company_name,'N/A'),
                    COALESCE(r.company_industry,'N/A'),
                    COALESCE(r.tax_id,'N/A'),
                    r.source_system, r.source_entity,
                    v_today
                );

                v_rows := v_rows + 1;
            END IF;
        END IF;

    END LOOP;

    CALL bl_cl.prc_write_log(
        'prc_load_ce_customers_scd',
        v_rows,
        'SUCCESS',
        'Customers SCD2 loaded successfully',
        NULL
    );

EXCEPTION WHEN OTHERS THEN
    CALL bl_cl.prc_write_log(
        'prc_load_ce_customers_scd',
        0,
        'ERROR',
        'Error during loading',
        SQLERRM
    );
END;
$$;

CALL bl_cl.prc_load_ce_customers_scd();

