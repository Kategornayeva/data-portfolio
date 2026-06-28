

/********************************************************************************
Task 5 — Staging layer (SA): external (foreign) + source tables
+ CL layer (work tables) for deduplication 

- 1 schema per dataset: sa_b2c, sa_b2b
- external tables: ext_*
- source tables: src_*
- CL schema: bl_cl
- work tables: wrk_*
- explicit COMMIT
- TRUNCATE for re-runs
********************************************************************************/

-- 1) Initialize
CREATE EXTENSION IF NOT EXISTS file_fdw;
CREATE SERVER IF NOT EXISTS file_server FOREIGN DATA WRAPPER file_fdw;

CREATE SCHEMA IF NOT EXISTS sa_b2c;
CREATE SCHEMA IF NOT EXISTS sa_b2b;

--------------------------------------------------------------------------------
-- 2) External (foreign) tables — ALL columns VARCHAR(255)
--------------------------------------------------------------------------------

CREATE FOREIGN TABLE IF NOT EXISTS sa_b2c.ext_b2c (
    source_system       VARCHAR(255),
    order_id            VARCHAR(255),
    order_line_id       VARCHAR(255),
    order_date          VARCHAR(255),
    gross_sales_amount  VARCHAR(255),
    discount_amount     VARCHAR(255),
    net_sales_amount    VARCHAR(255),
    cost_amount         VARCHAR(255),
    quantity            VARCHAR(255),
    customer_id         VARCHAR(255),
    customer_name       VARCHAR(255),
    customer_email      VARCHAR(255),
    device_type         VARCHAR(255),
    payment_method      VARCHAR(255),
    country_id          VARCHAR(255),
    country             VARCHAR(255),
    city_id             VARCHAR(255),
    city                VARCHAR(255),
    idea_id             VARCHAR(255),
    idea_title          VARCHAR(255),
    category_id         VARCHAR(255),
    category            VARCHAR(255),
    subcategory_id      VARCHAR(255),
    subcategory         VARCHAR(255),
    industry_domain_id  VARCHAR(255),
    industry_domain     VARCHAR(255),
    idea_version        VARCHAR(255),
    author_id           VARCHAR(255),
    author_name         VARCHAR(255)
)
SERVER file_server
OPTIONS (
    filename 'C:/datasets/B2C_FINAL.csv',
    format 'csv',
    header 'true',
    delimiter ','
);

CREATE FOREIGN TABLE IF NOT EXISTS sa_b2b.ext_b2b (
    source_system         VARCHAR(255),
    order_id              VARCHAR(255),
    order_line_id         VARCHAR(255),
    order_date            VARCHAR(255),
    gross_sales_amount    VARCHAR(255),
    discount_amount       VARCHAR(255),
    net_sales_amount      VARCHAR(255),
    cost_amount           VARCHAR(255),
    support_cost_amount   VARCHAR(255),
    quantity              VARCHAR(255),
    customer_id           VARCHAR(255),
    company_name          VARCHAR(255),
    company_industry      VARCHAR(255),
    tax_id                VARCHAR(255),
    country_id            VARCHAR(255),
    country               VARCHAR(255),
    idea_id               VARCHAR(255),
    idea_title            VARCHAR(255),
    category_id           VARCHAR(255),
    category              VARCHAR(255),
    subcategory_id        VARCHAR(255),
    subcategory           VARCHAR(255),
    industry_domain_id    VARCHAR(255),
    industry_domain       VARCHAR(255),
    idea_version          VARCHAR(255),
    author_id             VARCHAR(255),
    author_name           VARCHAR(255),
    license_type          VARCHAR(255),
    seats                 VARCHAR(255),
    contract_id           VARCHAR(255),
    contract_start_date   VARCHAR(255),
    contract_end_date     VARCHAR(255),
    purchase_type         VARCHAR(255),
    account_manager_id    VARCHAR(255),
    account_manager_name  VARCHAR(255)
)
SERVER file_server
OPTIONS (
    filename 'C:/datasets/B2B_FINAL.csv',
    format 'csv',
    header 'true',
    delimiter ','
);

ALTER FOREIGN TABLE sa_b2c.ext_b2c
OPTIONS (SET filename 'C:/datasets/split_out/B2C_INITIAL_95.csv');

ALTER FOREIGN TABLE sa_b2b.ext_b2b
OPTIONS (SET filename 'C:/datasets/split_out/B2B_INITIAL_95.csv');

SELECT *
FROM sa_b2c.ext_b2c
LIMIT 5;
--------------------------------------------------------------------------------
-- 3) Source tables (physical) — explicit DDL, ALL VARCHAR(255)
--------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS sa_b2c.src_b2c (
    source_system       VARCHAR(255),
    order_id            VARCHAR(255),
    order_line_id       VARCHAR(255),
    order_date          VARCHAR(255),
    gross_sales_amount  VARCHAR(255),
    discount_amount     VARCHAR(255),
    net_sales_amount    VARCHAR(255),
    cost_amount         VARCHAR(255),
    quantity            VARCHAR(255),
    customer_id         VARCHAR(255),
    customer_name       VARCHAR(255),
    customer_email      VARCHAR(255),
    device_type         VARCHAR(255),
    payment_method      VARCHAR(255),
    country_id          VARCHAR(255),
    country             VARCHAR(255),
    city_id             VARCHAR(255),
    city                VARCHAR(255),
    idea_id             VARCHAR(255),
    idea_title          VARCHAR(255),
    category_id         VARCHAR(255),
    category            VARCHAR(255),
    subcategory_id      VARCHAR(255),
    subcategory         VARCHAR(255),
    industry_domain_id  VARCHAR(255),
    industry_domain     VARCHAR(255),
    idea_version        VARCHAR(255),
    author_id           VARCHAR(255),
    author_name         VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS sa_b2b.src_b2b (
    source_system         VARCHAR(255),
    order_id              VARCHAR(255),
    order_line_id         VARCHAR(255),
    order_date            VARCHAR(255),
    gross_sales_amount    VARCHAR(255),
    discount_amount       VARCHAR(255),
    net_sales_amount      VARCHAR(255),
    cost_amount           VARCHAR(255),
    support_cost_amount   VARCHAR(255),
    quantity              VARCHAR(255),
    customer_id           VARCHAR(255),
    company_name          VARCHAR(255),
    company_industry      VARCHAR(255),
    tax_id                VARCHAR(255),
    country_id            VARCHAR(255),
    country               VARCHAR(255),
    idea_id               VARCHAR(255),
    idea_title            VARCHAR(255),
    category_id           VARCHAR(255),
    category              VARCHAR(255),
    subcategory_id        VARCHAR(255),
    subcategory           VARCHAR(255),
    industry_domain_id    VARCHAR(255),
    industry_domain       VARCHAR(255),
    idea_version          VARCHAR(255),
    author_id             VARCHAR(255),
    author_name           VARCHAR(255),
    license_type          VARCHAR(255),
    seats                 VARCHAR(255),
    contract_id           VARCHAR(255),
    contract_start_date   VARCHAR(255),
    contract_end_date     VARCHAR(255),
    purchase_type         VARCHAR(255),
    account_manager_id    VARCHAR(255),
    account_manager_name  VARCHAR(255)
);

--------------------------------------------------------------------------------
-- 4) Load into SRC + explicit COMMIT
--------------------------------------------------------------------------------

BEGIN;

-- B2C: insert only new rows (dedupe on source_system + order_line_id)
INSERT INTO sa_b2c.src_b2c (
    source_system,
    order_id,
    order_line_id,
    order_date,
    gross_sales_amount,
    discount_amount,
    net_sales_amount,
    cost_amount,
    quantity,
    customer_id,
    customer_name,
    customer_email,
    device_type,
    payment_method,
    country_id,
    country,
    city_id,
    city,
    idea_id,
    idea_title,
    category_id,
    category,
    subcategory_id,
    subcategory,
    industry_domain_id,
    industry_domain,
    idea_version,
    author_id,
    author_name
)
SELECT DISTINCT
    e.source_system,
    e.order_id,
    e.order_line_id,
    e.order_date,
    e.gross_sales_amount,
    e.discount_amount,
    e.net_sales_amount,
    e.cost_amount,
    e.quantity,
    e.customer_id,
    e.customer_name,
    e.customer_email,
    e.device_type,
    e.payment_method,
    e.country_id,
    e.country,
    e.city_id,
    e.city,
    e.idea_id,
    e.idea_title,
    e.category_id,
    e.category,
    e.subcategory_id,
    e.subcategory,
    e.industry_domain_id,
    e.industry_domain,
    e.idea_version,
    e.author_id,
    e.author_name
FROM sa_b2c.ext_b2c e
WHERE NOT EXISTS (
    SELECT 1
    FROM sa_b2c.src_b2c s
    WHERE s.source_system = e.source_system
      AND s.order_line_id = e.order_line_id
);

-- B2B: insert only new rows (dedupe on source_system + order_line_id)
INSERT INTO sa_b2b.src_b2b (
    source_system,
    order_id,
    order_line_id,
    order_date,
    gross_sales_amount,
    discount_amount,
    net_sales_amount,
    cost_amount,
    support_cost_amount,
    quantity,
    customer_id,
    company_name,
    company_industry,
    tax_id,
    country_id,
    country,
    idea_id,
    idea_title,
    category_id,
    category,
    subcategory_id,
    subcategory,
    industry_domain_id,
    industry_domain,
    idea_version,
    author_id,
    author_name,
    license_type,
    seats,
    contract_id,
    contract_start_date,
    contract_end_date,
    purchase_type,
    account_manager_id,
    account_manager_name
)
SELECT DISTINCT
    e.source_system,
    e.order_id,
    e.order_line_id,
    e.order_date,
    e.gross_sales_amount,
    e.discount_amount,
    e.net_sales_amount,
    e.cost_amount,
    e.support_cost_amount,
    e.quantity,
    e.customer_id,
    e.company_name,
    e.company_industry,
    e.tax_id,
    e.country_id,
    e.country,
    e.idea_id,
    e.idea_title,
    e.category_id,
    e.category,
    e.subcategory_id,
    e.subcategory,
    e.industry_domain_id,
    e.industry_domain,
    e.idea_version,
    e.author_id,
    e.author_name,
    e.license_type,
    e.seats,
    e.contract_id,
    e.contract_start_date,
    e.contract_end_date,
    e.purchase_type,
    e.account_manager_id,
    e.account_manager_name
FROM sa_b2b.ext_b2b e
WHERE NOT EXISTS (
    SELECT 1
    FROM sa_b2b.src_b2b s
    WHERE s.source_system = e.source_system
      AND s.order_line_id = e.order_line_id
);

COMMIT;


--------------------------------------------------------------------------------
-- 5) CL layer: Work tables for deduplication 
--------------------------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS bl_cl;

BEGIN;

CREATE TABLE IF NOT EXISTS bl_cl.wrk_b2c AS
SELECT DISTINCT
    source_system,
    order_id,
    order_line_id,
    order_date,
    gross_sales_amount,
    discount_amount,
    net_sales_amount,
    cost_amount,
    quantity,
    customer_id,
    customer_name,
    customer_email,
    device_type,
    payment_method,
    country_id,
    country,
    city_id,
    city,
    idea_id,
    idea_title,
    category_id,
    category,
    subcategory_id,
    subcategory,
    industry_domain_id,
    industry_domain,
    idea_version,
    author_id,
    author_name
FROM sa_b2c.src_b2c;


CREATE TABLE IF NOT EXISTS bl_cl.wrk_b2b AS
SELECT DISTINCT
    source_system,
    order_id,
    order_line_id,
    order_date,
    gross_sales_amount,
    discount_amount,
    net_sales_amount,
    cost_amount,
    support_cost_amount,
    quantity,
    customer_id,
    company_name,
    company_industry,
    tax_id,
    country_id,
    country,
    idea_id,
    idea_title,
    category_id,
    category,
    subcategory_id,
    subcategory,
    industry_domain_id,
    industry_domain,
    idea_version,
    author_id,
    author_name,
    license_type,
    seats,
    contract_id,
    contract_start_date,
    contract_end_date,
    purchase_type,
    account_manager_id,
    account_manager_name
FROM sa_b2b.src_b2b;

COMMIT;


--------------------------------------------------------------------------------
-- 6) Verification
--------------------------------------------------------------------------------

SELECT 'B2C_EXT' as dataset, count(*) FROM sa_b2c.ext_b2c
UNION ALL
SELECT 'B2C_SRC' as dataset, count(*) FROM sa_b2c.src_b2c
UNION ALL
SELECT 'B2C_WRK' as dataset, count(*) FROM bl_cl.wrk_b2c
UNION ALL
SELECT 'B2B_EXT' as dataset, count(*) FROM sa_b2b.ext_b2b
UNION ALL
SELECT 'B2B_SRC' as dataset, count(*) FROM sa_b2b.src_b2b
UNION ALL
SELECT 'B2B_WRK' as dataset, count(*) FROM bl_cl.wrk_b2b;

SELECT * FROM sa_b2c.ext_b2c LIMIT 5;
SELECT * FROM sa_b2c.src_b2c LIMIT 10;
SELECT * FROM bl_cl.wrk_b2c LIMIT 10;

SELECT * FROM sa_b2b.ext_b2b LIMIT 10;
SELECT * FROM sa_b2b.src_b2b LIMIT 10;
SELECT * FROM bl_cl.wrk_b2b LIMIT 10;

