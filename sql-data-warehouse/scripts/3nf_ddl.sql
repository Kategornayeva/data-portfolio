/* ============================================================================
   Project: DWH / BL_3NF Layer
   Script : 03_bl_3nf_ddl.sql
   Purpose: Create BL_3NF schema, sequences and 3NF tables (DDL only).
   Notes  :
     - Surrogate keys are generated using SEQUENCES (no SERIAL/IDENTITY).
     - Business keys are stored as <entity>_src_id + source_system + source_entity (UK).
     - All scripts are rerunnable (IF NOT EXISTS).
   ============================================================================ */

-- ============================================================================
-- 1) Schema
-- ============================================================================
CREATE SCHEMA IF NOT EXISTS bl_3nf;

-- ============================================================================
-- Reference: Countries
-- ============================================================================

CREATE SEQUENCE IF NOT EXISTS bl_3nf.seq_ce_countries_id
START WITH 1
INCREMENT BY 1;
CREATE TABLE IF NOT EXISTS bl_3nf.ce_countries (
    country_id        BIGINT NOT NULL,
    country_src_id    VARCHAR(100) NOT NULL,
    country_name      VARCHAR(255) NOT NULL,
    source_system     VARCHAR(50)  NOT NULL,
    source_entity     VARCHAR(50)  NOT NULL,
    ta_insert_dt      DATE         NOT NULL,
    ta_update_dt      DATE         NOT NULL,

    CONSTRAINT pk_ce_countries PRIMARY KEY (country_id),
    CONSTRAINT uk_ce_countries_src UNIQUE (country_src_id, source_system, source_entity)
);


-- ============================================================================
-- Reference: Industry Domains
-- ============================================================================

CREATE SEQUENCE IF NOT EXISTS bl_3nf.seq_ce_industry_domains_id
START WITH 1
INCREMENT BY 1;

CREATE TABLE IF NOT EXISTS bl_3nf.ce_industry_domains (
    industry_domain_id      BIGINT       NOT NULL,
    industry_domain_src_id  VARCHAR(100) NOT NULL,
    industry_domain_name    VARCHAR(255) NOT NULL,
    source_system           VARCHAR(50)  NOT NULL,
    source_entity           VARCHAR(50)  NOT NULL,
    ta_insert_dt            DATE         NOT NULL,
    ta_update_dt            DATE         NOT NULL,

    CONSTRAINT pk_ce_industry_domains PRIMARY KEY (industry_domain_id),
    CONSTRAINT uk_ce_industry_domains_src UNIQUE (industry_domain_src_id, source_system, source_entity)
);

-- ============================================================================
-- Reference: Categories
-- ============================================================================
CREATE SEQUENCE IF NOT EXISTS bl_3nf.seq_ce_categories_id
START WITH 1
INCREMENT BY 1;

CREATE TABLE IF NOT EXISTS bl_3nf.ce_categories (
    category_id       BIGINT       NOT NULL,
    category_src_id   VARCHAR(100) NOT NULL,
    category_name     VARCHAR(255) NOT NULL,
    source_system     VARCHAR(50)  NOT NULL,
    source_entity     VARCHAR(50)  NOT NULL,
    ta_insert_dt      DATE         NOT NULL,
    ta_update_dt      DATE         NOT NULL,

    CONSTRAINT pk_ce_categories PRIMARY KEY (category_id),
    CONSTRAINT uk_ce_categories_src UNIQUE (category_src_id, source_system, source_entity)
);


-- ============================================================================
-- Reference: Authors
-- ============================================================================
CREATE SEQUENCE IF NOT EXISTS bl_3nf.seq_ce_authors_id
START WITH 1
INCREMENT BY 1;

CREATE TABLE IF NOT EXISTS bl_3nf.ce_authors (
    author_id        BIGINT       NOT NULL,
    author_src_id    VARCHAR(100) NOT NULL,
    author_name      VARCHAR(255) NOT NULL,
    source_system    VARCHAR(50)  NOT NULL,
    source_entity    VARCHAR(50)  NOT NULL,
    ta_insert_dt     DATE         NOT NULL,
    ta_update_dt     DATE         NOT NULL,

    CONSTRAINT pk_ce_authors PRIMARY KEY (author_id),
    CONSTRAINT uk_ce_authors_src UNIQUE (author_src_id, source_system, source_entity)
);


-- ============================================================================
-- Reference: Account Managers
-- ============================================================================
CREATE SEQUENCE IF NOT EXISTS bl_3nf.seq_ce_account_managers_id
START WITH 1
INCREMENT BY 1;

CREATE TABLE IF NOT EXISTS bl_3nf.ce_account_managers (
    account_manager_id      BIGINT       NOT NULL,
    account_manager_src_id  VARCHAR(100) NOT NULL,
    account_manager_name    VARCHAR(255) NOT NULL,
    source_system           VARCHAR(50)  NOT NULL,
    source_entity           VARCHAR(50)  NOT NULL,
    ta_insert_dt            DATE         NOT NULL,
    ta_update_dt            DATE         NOT NULL,

    CONSTRAINT pk_ce_account_managers PRIMARY KEY (account_manager_id),
    CONSTRAINT uk_ce_account_managers_src UNIQUE (account_manager_src_id, source_system, source_entity)
);

-- ============================================================================
-- Reference: Subcategories
-- ============================================================================
CREATE SEQUENCE IF NOT EXISTS bl_3nf.seq_ce_subcategories_id
START WITH 1
INCREMENT BY 1;
CREATE TABLE IF NOT EXISTS bl_3nf.ce_subcategories (
    subcategory_id       BIGINT       NOT NULL,
    subcategory_src_id   VARCHAR(100) NOT NULL,
    category_id          BIGINT       NOT NULL,
    subcategory_name     VARCHAR(255) NOT NULL,
    source_system        VARCHAR(50)  NOT NULL,
    source_entity        VARCHAR(50)  NOT NULL,
    ta_insert_dt         DATE         NOT NULL,
    ta_update_dt         DATE         NOT NULL,

    CONSTRAINT pk_ce_subcategories PRIMARY KEY (subcategory_id),
    CONSTRAINT uk_ce_subcategories_src UNIQUE (subcategory_src_id, source_system, source_entity),
    CONSTRAINT fk_ce_subcategories__category
        FOREIGN KEY (category_id)
        REFERENCES bl_3nf.ce_categories (category_id)
);

-- ============================================================================
-- Reference: Cities
-- ============================================================================
CREATE SEQUENCE IF NOT EXISTS bl_3nf.seq_ce_cities_id
START WITH 1
INCREMENT BY 1;
CREATE TABLE IF NOT EXISTS bl_3nf.ce_cities (
    city_id        BIGINT       NOT NULL,
    city_src_id    VARCHAR(100) NOT NULL,
    country_id     BIGINT       NOT NULL,
    city_name      VARCHAR(255) NOT NULL,
    source_system  VARCHAR(50)  NOT NULL,
    source_entity  VARCHAR(50)  NOT NULL,
    ta_insert_dt   DATE         NOT NULL,
    ta_update_dt   DATE         NOT NULL,

    CONSTRAINT pk_ce_cities PRIMARY KEY (city_id),
    CONSTRAINT uk_ce_cities_src UNIQUE (city_src_id, source_system, source_entity),
    CONSTRAINT fk_ce_cities__country
        FOREIGN KEY (country_id)
        REFERENCES bl_3nf.ce_countries (country_id)
);

-- ============================================================================
-- Reference: Ideas
-- ============================================================================
DROP TABLE IF EXISTS bl_3nf.ce_ideas;
DROP SEQUENCE IF EXISTS bl_3nf.seq_ce_ideas_id;

CREATE SEQUENCE IF NOT EXISTS bl_3nf.seq_ce_ideas_id
START WITH 1
INCREMENT BY 1;
CREATE TABLE IF NOT EXISTS bl_3nf.ce_ideas (
    idea_id              BIGINT       NOT NULL,
    idea_src_id          VARCHAR(100) NOT NULL,
    idea_title           VARCHAR(500) NOT NULL,
    idea_version         VARCHAR(50)  NOT NULL,
    author_id            BIGINT       NOT NULL,
    subcategory_id       BIGINT       NOT NULL,
    industry_domain_id   BIGINT       NOT NULL,
    source_system        VARCHAR(50)  NOT NULL,
    source_entity        VARCHAR(50)  NOT NULL,
    ta_insert_dt         DATE         NOT NULL,
    ta_update_dt         DATE         NOT NULL,

    CONSTRAINT pk_ce_ideas PRIMARY KEY (idea_id),
    CONSTRAINT uk_ce_ideas_src UNIQUE (idea_src_id, source_system, source_entity),

    CONSTRAINT fk_ce_ideas__author
        FOREIGN KEY (author_id)
        REFERENCES bl_3nf.ce_authors (author_id),

    CONSTRAINT fk_ce_ideas__subcategory
        FOREIGN KEY (subcategory_id)
        REFERENCES bl_3nf.ce_subcategories (subcategory_id),

    CONSTRAINT fk_ce_ideas__industry_domain
        FOREIGN KEY (industry_domain_id)
        REFERENCES bl_3nf.ce_industry_domains (industry_domain_id)
);


-- ============================================================================
-- Reference: Contracts
-- ============================================================================
CREATE SEQUENCE IF NOT EXISTS bl_3nf.seq_ce_contracts_id
START WITH 1
INCREMENT BY 1;

CREATE TABLE IF NOT EXISTS bl_3nf.ce_contracts (
    contract_id        BIGINT       NOT NULL,
    contract_src_id    VARCHAR(100) NOT NULL,
    purchase_type      VARCHAR(50)  NOT NULL,
    license_type       VARCHAR(50)  NOT NULL,
    seats              INTEGER      NOT NULL,
    account_manager_id BIGINT       NOT NULL,
    source_system      VARCHAR(50)  NOT NULL,
    source_entity      VARCHAR(50)  NOT NULL,
    ta_insert_dt       DATE         NOT NULL,
    ta_update_dt       DATE         NOT NULL,

    CONSTRAINT pk_ce_contracts PRIMARY KEY (contract_id),
    CONSTRAINT uk_ce_contracts_src UNIQUE (contract_src_id, source_system, source_entity),
    CONSTRAINT fk_ce_contracts__am
        FOREIGN KEY (account_manager_id)
        REFERENCES bl_3nf.ce_account_managers (account_manager_id)
);


-- ============================================================================
-- Core: Orders
-- ============================================================================
CREATE SEQUENCE IF NOT EXISTS bl_3nf.seq_ce_orders_id
START WITH 1
INCREMENT BY 1;
CREATE TABLE IF NOT EXISTS bl_3nf.ce_orders (
    order_id            BIGINT       NOT NULL,
    order_src_id        VARCHAR(100) NOT NULL,
    order_dt            DATE         NOT NULL,
    contract_start_dt   DATE         NOT NULL,
    contract_end_dt     DATE         NOT NULL,
    customer_id         BIGINT       NOT NULL,   -- logical FK (SCD2)
    city_id             BIGINT       NOT NULL,
    source_system       VARCHAR(50)  NOT NULL,
    source_entity       VARCHAR(50)  NOT NULL,
    ta_insert_dt        DATE         NOT NULL,
    ta_update_dt        DATE         NOT NULL,

    CONSTRAINT pk_ce_orders PRIMARY KEY (order_id),
    CONSTRAINT uk_ce_orders_src UNIQUE (order_src_id, source_system, source_entity),
    CONSTRAINT fk_ce_orders_city
        FOREIGN KEY (city_id)
        REFERENCES bl_3nf.ce_cities (city_id)
);


-- ============================================================================
-- Core: Order Lines
-- ============================================================================
CREATE SEQUENCE IF NOT EXISTS bl_3nf.seq_ce_order_lines_id
START WITH 1
INCREMENT BY 1;

CREATE TABLE IF NOT EXISTS bl_3nf.ce_order_lines (
    order_line_id        BIGINT        NOT NULL,
    order_line_src_id    VARCHAR(100)  NOT NULL,

    contract_id          BIGINT        NOT NULL,
    order_id             BIGINT        NOT NULL,
    idea_id              BIGINT        NOT NULL,

    quantity             INTEGER       NOT NULL,
    gross_sales_amount   NUMERIC(15,2) NOT NULL,
    discount_amount      NUMERIC(15,2) NOT NULL,
    net_sales_amount     NUMERIC(15,2) NOT NULL,
    cost_amount          NUMERIC(15,2) NOT NULL,
    support_cost_amount  NUMERIC(15,2) NOT NULL,

    source_system        VARCHAR(50)   NOT NULL,
    source_entity        VARCHAR(50)   NOT NULL,
    ta_insert_dt         DATE          NOT NULL,
    ta_update_dt         DATE          NOT NULL,

    CONSTRAINT pk_ce_order_lines PRIMARY KEY (order_line_id),
    CONSTRAINT uk_ce_order_lines_src UNIQUE (order_line_src_id, source_system, source_entity),

    CONSTRAINT fk_ce_ol_order
        FOREIGN KEY (order_id)
        REFERENCES bl_3nf.ce_orders (order_id),

    CONSTRAINT fk_ce_ol_contract
        FOREIGN KEY (contract_id)
        REFERENCES bl_3nf.ce_contracts (contract_id),

    CONSTRAINT fk_ce_ol_idea
        FOREIGN KEY (idea_id)
        REFERENCES bl_3nf.ce_ideas (idea_id)
);


-- ============================================================================
-- SCD Type 2: Customers
-- ============================================================================
CREATE SEQUENCE IF NOT EXISTS bl_3nf.seq_ce_customers_id
START WITH 1
INCREMENT BY 1;

CREATE TABLE IF NOT EXISTS bl_3nf.ce_customers_scd (
    customer_id        BIGINT       NOT NULL,

    start_dt           DATE         NOT NULL,
    end_dt             DATE         NOT NULL,
    is_active          VARCHAR(1)   NOT NULL,

    customer_src_id    VARCHAR(100) NOT NULL,
    customer_name      VARCHAR(255) NOT NULL,
    customer_email     VARCHAR(255) NOT NULL,
    device_type        VARCHAR(50)  NOT NULL,
    payment_method     VARCHAR(50)  NOT NULL,
    company_name       VARCHAR(255) NOT NULL,
    company_industry   VARCHAR(100) NOT NULL,
    tax_id             VARCHAR(50)  NOT NULL,

    source_system      VARCHAR(50)  NOT NULL,
    source_entity      VARCHAR(50)  NOT NULL,

    ta_insert_dt       DATE         NOT NULL,

    CONSTRAINT pk_ce_customers_scd
        PRIMARY KEY (customer_id, start_dt),

    CONSTRAINT uk_ce_customers_scd_src
        UNIQUE (customer_src_id, source_system, source_entity, start_dt)
);
