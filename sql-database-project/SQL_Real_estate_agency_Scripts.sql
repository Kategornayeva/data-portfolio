CREATE DATABASE real_estate_agency;

-- ============================================================
-- SCHEMA INITIALIZATION
-- Creates the dedicated schema for project tables.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS agency;

-- ============================================================
-- TABLE: client_type
-- Stores available client types (buyer, seller, renter, investor).
-- ============================================================

CREATE TABLE IF NOT EXISTS agency.client_type (
    client_type_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    type_name   VARCHAR(50) NOT NULL UNIQUE
);

-- ============================================================
-- TABLE: property_type
-- Stores property types (e.g., apartment, house, commercial)
-- ============================================================

CREATE TABLE IF NOT EXISTS agency.property_type (
    property_type_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    type_name   VARCHAR(50) NOT NULL UNIQUE
);

-- ============================================================
-- TABLE: property_status
-- Stores property status values (e.g., available, reserved, sold)
-- ============================================================

CREATE TABLE IF NOT EXISTS agency.property_status (
    property_status_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status_name   VARCHAR(50) NOT NULL UNIQUE
);

-- ============================================================
-- TABLE: contract_type
-- Stores contract types (e.g., sale, rent, lease)
-- ============================================================

CREATE TABLE IF NOT EXISTS agency.contract_type (
    contract_type_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    type_name   VARCHAR(50) NOT NULL UNIQUE
);

-- ============================================================
-- TABLE: contract_status
-- Stores contract status values (e.g., active, completed, canceled)
-- ============================================================

CREATE TABLE IF NOT EXISTS agency.contract_status (
    contract_status_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status_name   VARCHAR(50) NOT NULL UNIQUE
);

-- ============================================================
-- TABLE: payment_type
-- Stores types of payments (e.g., cash, card, bank transfer)
-- ============================================================

CREATE TABLE IF NOT EXISTS agency.payment_type (
    payment_type_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    type_name   VARCHAR(50) NOT NULL UNIQUE
);

-- ============================================================
-- TABLE: payment_status
-- Stores payment processing statuses (e.g., pending, completed, failed)
-- ============================================================

CREATE TABLE IF NOT EXISTS agency.payment_status (
    payment_status_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    status_name   VARCHAR(50) NOT NULL UNIQUE
);


-- ============================================================
-- TABLE: showing_result
-- Stores outcomes of property showings (e.g., interested, declined, no_show)
-- ============================================================

CREATE TABLE IF NOT EXISTS agency.showing_result (
    result_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    result_name   VARCHAR(50) NOT NULL UNIQUE
);


-- ============================================================
-- TABLE: address
-- Stores complete property address information
-- ============================================================

CREATE TABLE IF NOT EXISTS agency.address (
    address_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    city        VARCHAR(100) NOT NULL,
    street      VARCHAR(150) NOT NULL,
    building    VARCHAR(20) NOT NULL,
    apartment   VARCHAR(20),
	zipcode     VARCHAR(20)
);

-- ============================================================
-- TABLE: owner
-- Stores property owner information (full name, contacts, ID document)
-- ============================================================

CREATE TABLE IF NOT EXISTS agency.owner (
    owner_id   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name  VARCHAR(150) NOT NULL,
    last_name   VARCHAR(150) NOT NULL,
	phone       VARCHAR(20) NOT NULL,
    email       VARCHAR(150) NOT NULL UNIQUE,
	document_id VARCHAR(50) NOT NULL UNIQUE,
	last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- TABLE: agent
-- Stores real estate agents and hierarchical relationships (manager → subordinate).
-- ============================================================

CREATE TABLE IF NOT EXISTS agency.agent (
    agent_id INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    first_name   VARCHAR(150) NOT NULL,
    last_name    VARCHAR(150) NOT NULL,
    email        VARCHAR(150) NOT NULL UNIQUE,
    phone        VARCHAR(20) NOT NULL UNIQUE,
    hired_at     DATE NOT NULL,
	last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    manager_id   INTEGER NULL,

    CONSTRAINT fk_agency_agent
        FOREIGN KEY (manager_id)
            REFERENCES agency.agent (agent_id)
            ON DELETE SET NULL
);



-- ============================================================
-- TABLE: client
-- Stores client information and links to client_type
-- ============================================================

CREATE TABLE IF NOT EXISTS agency.client (
    client_id             INTEGER PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
	
    first_name            VARCHAR(150) NOT NULL,
    last_name             VARCHAR(150) NOT NULL,
    email                 VARCHAR(150) NOT NULL UNIQUE,
    phone                 VARCHAR(20) NOT NULL UNIQUE,
    registration_date     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	last_update           TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    client_type_id        INTEGER NOT NULL,
	
    FOREIGN KEY (client_type_id)
        REFERENCES agency.client_type (client_type_id)
   
);


-- ============================================================
-- TABLE: property
-- Stores property characteristics and links to:address, 
-- property_type, property_status
-- ============================================================
CREATE TABLE IF NOT EXISTS agency.property (
    property_id     INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    area            DECIMAL(10,2)  NOT NULL CHECK (area > 0),
    price           DECIMAL(12,2) NOT NULL CHECK (price >= 0),
    rooms           INT           NOT NULL CHECK (rooms > 0),
    year_built      INT           NOT NULL CHECK (year_built BETWEEN 1600 AND EXTRACT(YEAR FROM CURRENT_DATE)),
    description     TEXT,

    last_update     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    address_id      INT NOT NULL,
    property_type_id  INT NOT NULL,
    property_status_id INT NOT NULL,

    CONSTRAINT fk_property_address
        FOREIGN KEY (address_id)
        REFERENCES agency.address(address_id),

    CONSTRAINT fk_property_type
        FOREIGN KEY (property_type_id)
        REFERENCES agency.property_type(property_type_id),

    CONSTRAINT fk_property_status
        FOREIGN KEY (property_status_id)
        REFERENCES agency.property_status(property_status_id)
);


-- ============================================================
-- TABLE: property_owner
-- Linking table for properties ↔ owners, including ownership share.
-- -- The property_owner table represents a many-to-many relationship 
-- between properties and owners. 
-- Each row indicates that a specific owner holds a defined ownership share 
-- of a specific property. 

-- The UNIQUE(property_id, owner_id) constraint ensures that the same owner 
-- cannot be assigned to the same property more than once, preventing 
-- duplicate or inconsistent ownership records.

-- ON DELETE CASCADE is used for both foreign keys because if either 
-- the property or the owner is removed from the system, the corresponding 
-- ownership link becomes invalid and must be removed automatically.

-- The ownership_share column reflects the percentage of ownership 
-- and must be between 0 and 1, enforced by a CHECK constraint.

-- ============================================================
CREATE TABLE IF NOT EXISTS agency.property_owner (
    property_owner_id  INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    ownership_share    DECIMAL(3,2) NOT NULL
        CHECK (ownership_share > 0 AND ownership_share <= 1),

    last_update        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    property_id        INT NOT NULL,
    owner_id           INT NOT NULL,

    CONSTRAINT fk_property_owner_property
        FOREIGN KEY (property_id)
        REFERENCES agency.property(property_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_property_owner_owner
        FOREIGN KEY (owner_id)
        REFERENCES agency.owner(owner_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    -- one owner cannot appear twice for the same property
    CONSTRAINT uq_property_owner UNIQUE (property_id, owner_id)
);


-- ============================================================
-- TABLE: showing
-- -- The showing table stores information about property viewings.
-- Each record represents a scheduled visit where a client views a specific
-- property with an agent at a particular date and time.
-- The UNIQUE constraint across (property_id, client_id, showing_datetime)
-- ensures that the same client cannot be scheduled to view the same property
-- more than once at the exact same time.
-- ============================================================

CREATE TABLE IF NOT EXISTS agency.showing (
    showing_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    showing_datetime TIMESTAMP NOT NULL,
    comment          TEXT,
    last_update      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    property_id      INT NOT NULL,
    client_id        INT NOT NULL,
    agent_id         INT NOT NULL,
    result_id        INT,

    -- FK: property
    CONSTRAINT fk_showing_property
        FOREIGN KEY (property_id)
        REFERENCES agency.property(property_id)
        ON DELETE CASCADE,

    -- FK: client
    CONSTRAINT fk_showing_client
        FOREIGN KEY (client_id)
        REFERENCES agency.client(client_id)
        ON DELETE CASCADE,

    -- FK: agent
    CONSTRAINT fk_showing_agent
        FOREIGN KEY (agent_id)
        REFERENCES agency.agent(agent_id),

    -- FK: showing_result
    CONSTRAINT fk_showing_result
        FOREIGN KEY (result_id)
        REFERENCES agency.showing_result(result_id),

    -- Composite unique key to prevent duplicates
    CONSTRAINT uq_showing UNIQUE (property_id, client_id, showing_datetime)
);

-- ============================================================
-- TABLE: property
-- Stores property characteristics and links to: address,
-- property_type, property_status.
-- ON DELETE CASCADE is used for address_id because if an address
-- is removed, the property record cannot exist without it.
-- ============================================================


CREATE TABLE IF NOT EXISTS agency.contract (
    contract_id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    contract_number      VARCHAR(50) NOT NULL UNIQUE,
    contract_date        DATE NOT NULL,
    validity_period      DATE CHECK (validity_period IS NULL OR validity_period > contract_date),
    final_price          DECIMAL(12,2) NOT NULL CHECK (final_price >= 0),
    last_update          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    property_id          INT NOT NULL,
    client_id            INT NOT NULL,
    agent_id             INT NOT NULL,
    contract_type_id     INT NOT NULL,
    contract_status_id   INT NOT NULL,

    -- Property reference (CASCADE is acceptable in student project context)
    CONSTRAINT fk_contract_property
        FOREIGN KEY (property_id)
        REFERENCES agency.property(property_id)
        ON DELETE CASCADE,

    -- Client reference
    CONSTRAINT fk_contract_client
        FOREIGN KEY (client_id)
        REFERENCES agency.client(client_id)
        ON DELETE CASCADE,

    -- Agent reference (agent may be deleted, but contracts should stay)
    CONSTRAINT fk_contract_agent
        FOREIGN KEY (agent_id)
        REFERENCES agency.agent(agent_id),

    -- Contract type reference (dictionary — cannot be deleted)
    CONSTRAINT fk_contract_type
        FOREIGN KEY (contract_type_id)
        REFERENCES agency.contract_type(contract_type_id),

    -- Contract status reference (dictionary — cannot be deleted)
    CONSTRAINT fk_contract_status
        FOREIGN KEY (contract_status_id)
        REFERENCES agency.contract_status(contract_status_id)
);


-- ============================================================
-- TABLE: payment
-- Stores payments linked to contracts and payment details.
-- ============================================================
CREATE TABLE IF NOT EXISTS agency.payment (
    payment_id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    amount             DECIMAL(12,2) NOT NULL CHECK (amount >= 0),
    payment_date       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_update        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    contract_id        INT NOT NULL,
    payment_type_id    INT NOT NULL,
    payment_status_id  INT NOT NULL,

    -- Contract reference (payments depend on contracts)
    CONSTRAINT fk_payment_contract
        FOREIGN KEY (contract_id)
        REFERENCES agency.contract(contract_id)
        ON DELETE CASCADE
		ON UPDATE CASCADE,

    -- Payment type reference (dictionary)
    CONSTRAINT fk_payment_type
        FOREIGN KEY (payment_type_id)
        REFERENCES agency.payment_type(payment_type_id),

    -- Payment status reference (dictionary)
    CONSTRAINT fk_payment_status
        FOREIGN KEY (payment_status_id)
        REFERENCES agency.payment_status(payment_status_id)
);

-- ============================================================
-- TABLE: property_history
-- Stores historical changes of property attributes.
-- ============================================================

CREATE TABLE IF NOT EXISTS agency.property_history (
    history_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    old_price DECIMAL(12,2) CHECK (old_price >= 0),
    new_price DECIMAL(12,2) CHECK (new_price >= 0),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    comment TEXT,

    changed_by INT ,
    property_id INT NOT NULL,
    old_status_id INT,
    new_status_id INT,

    CONSTRAINT fk_ph_agent
        FOREIGN KEY (changed_by)
        REFERENCES agency.agent(agent_id)
        ON DELETE SET NULL,

    CONSTRAINT fk_ph_property
        FOREIGN KEY (property_id)
        REFERENCES agency.property(property_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_ph_old_status
        FOREIGN KEY (old_status_id)
        REFERENCES agency.property_status(property_status_id),

    CONSTRAINT fk_ph_new_status
        FOREIGN KEY (new_status_id)
        REFERENCES agency.property_status(property_status_id)
);

-- ============================================================
-- CHECK CONSTRAINTS (added via ALTER TABLE as required)
-- ============================================================

-- Property price must be at least 10,000
ALTER TABLE agency.property
ADD CONSTRAINT chk_property_price_min
CHECK (price >= 10000);

-- Contract date must be after January 1, 2024
ALTER TABLE agency.contract
ADD CONSTRAINT chk_contract_date_modern
CHECK (contract_date > DATE '2024-01-01');

-- Payment amount must be strictly positive
ALTER TABLE agency.payment
ADD CONSTRAINT chk_payment_amount_positive
CHECK (amount > 0);

-- Showing datetime must be in the future
ALTER TABLE agency.showing
ADD CONSTRAINT chk_showing_future_datetime
CHECK (showing_datetime > CURRENT_TIMESTAMP);

-- Owner phone number must start with a plus sign
ALTER TABLE agency.owner
ADD CONSTRAINT chk_owner_phone_format
CHECK (phone LIKE '+%');

-- Client email must contain @ symbol
ALTER TABLE agency.client
ADD CONSTRAINT chk_client_email_format
CHECK (email LIKE '%@%');



-- ============================================================
-- BLOCK 1: DICTIONARIES
-- Loads all dictionary tables in one controlled transaction.
-- Safe pattern: BEGIN → multiple SAVEPOINT → INSERT → COMMIT
-- ============================================================

BEGIN;

-- *************** client_type ***************
SAVEPOINT sp_client_type;

INSERT INTO agency.client_type (type_name)
SELECT v.type_name
FROM (VALUES
        ('buyer'),
        ('seller'),
        ('renter'),
        ('investor'),
        ('partner'),
        ('guest')
     ) AS v(type_name)
WHERE NOT EXISTS (
    SELECT 1 
    FROM agency.client_type ct
    WHERE LOWER(ct.type_name) = LOWER(v.type_name)
)
RETURNING client_type_id, type_name;

-- ROLLBACK TO SAVEPOINT sp_client_type; -- (if needed)


-- *************** property_type ***************
SAVEPOINT sp_property_type;

INSERT INTO agency.property_type (type_name)
SELECT v.type_name
FROM (VALUES
        ('apartment'),
        ('house'),
        ('commercial'),
        ('studio'),
        ('townhouse'),
        ('warehouse')
     ) AS v(type_name)
WHERE NOT EXISTS (
    SELECT 1 
    FROM agency.property_type pt
    WHERE LOWER(pt.type_name) = LOWER(v.type_name)
)
RETURNING property_type_id, type_name;

-- ROLLBACK TO SAVEPOINT sp_property_type;


-- *************** property_status ***************
SAVEPOINT sp_property_status;

INSERT INTO agency.property_status (status_name)
SELECT v.status_name
FROM (VALUES
        ('available'),
        ('reserved'),
        ('sold'),
        ('rented'),
        ('archived'),
        ('under_review')
     ) AS v(status_name)
WHERE NOT EXISTS (
    SELECT 1
    FROM agency.property_status ps
    WHERE LOWER(ps.status_name) = LOWER(v.status_name)
)
RETURNING property_status_id, status_name;

-- ROLLBACK TO SAVEPOINT sp_property_status;


-- *************** contract_type ***************
SAVEPOINT sp_contract_type;

INSERT INTO agency.contract_type (type_name)
SELECT v.type_name
FROM (VALUES
        ('sale'),
        ('rent'),
        ('lease'),
        ('purchase'),
        ('mortgage'),
        ('exchange')
     ) AS v(type_name)
WHERE NOT EXISTS (
    SELECT 1
    FROM agency.contract_type ct
    WHERE LOWER(ct.type_name) = LOWER(v.type_name)
)
RETURNING contract_type_id, type_name;

-- ROLLBACK TO SAVEPOINT sp_contract_type;


-- *************** contract_status ***************
SAVEPOINT sp_contract_status;

INSERT INTO agency.contract_status (status_name)
SELECT v.status_name
FROM (VALUES
        ('active'),
        ('completed'),
        ('cancelled'),
        ('expired'),
        ('draft'),
        ('pending')
     ) AS v(status_name)
WHERE NOT EXISTS (
    SELECT 1
    FROM agency.contract_status cs
    WHERE LOWER(cs.status_name) = LOWER(v.status_name)
)
RETURNING contract_status_id, status_name;

-- ROLLBACK TO SAVEPOINT sp_contract_status;


-- *************** payment_type ***************
SAVEPOINT sp_payment_type;

INSERT INTO agency.payment_type (type_name)
SELECT v.type_name
FROM (VALUES
        ('cash'),
        ('card'),
        ('bank_transfer'),
        ('crypto'),
        ('mobile_payment'),
        ('cheque')
     ) AS v(type_name)
WHERE NOT EXISTS (
    SELECT 1
    FROM agency.payment_type pt
    WHERE LOWER(pt.type_name) = LOWER(v.type_name)
)
RETURNING payment_type_id, type_name;

-- ROLLBACK TO SAVEPOINT sp_payment_type;


-- *************** payment_status ***************
SAVEPOINT sp_payment_status;

INSERT INTO agency.payment_status (status_name)
SELECT v.status_name
FROM (VALUES
        ('pending'),
        ('completed'),
        ('failed'),
        ('rejected'),
        ('processing'),
        ('refunded')
     ) AS v(status_name)
WHERE NOT EXISTS (
    SELECT 1
    FROM agency.payment_status ps
    WHERE LOWER(ps.status_name) = LOWER(v.status_name)
)
RETURNING payment_status_id, status_name;

-- ROLLBACK TO SAVEPOINT sp_payment_status;


-- *************** showing_result ***************
SAVEPOINT sp_showing_result;

INSERT INTO agency.showing_result (result_name)
SELECT v.result_name
FROM (VALUES
        ('interested'),
        ('declined'),
        ('no_show'),
        ('delayed'),
        ('second_visit'),
        ('bad_impression')
     ) AS v(result_name)
WHERE NOT EXISTS (
    SELECT 1
    FROM agency.showing_result sr
    WHERE LOWER(sr.result_name) = LOWER(v.result_name)
)
RETURNING result_id, result_name;

-- ROLLBACK TO SAVEPOINT sp_showing_result;


COMMIT;

-- ================= END OF BLOCK 1 ============================


-- ============================================================
-- BLOCK 2: BASE ENTITIES
-- Loads address, owner, agent, client in one safe transaction.
-- ============================================================

BEGIN;

-- *************** address ***************
SAVEPOINT sp_address;

INSERT INTO agency.address (city, street, building, apartment, zipcode)
SELECT v.city, v.street, v.building, v.apartment, v.zipcode
FROM (VALUES
        ('Minsk', 'Lenina',  '10', '5',  '220030'),
        ('Minsk', 'Pobediteley', '15', '12', '220004'),
        ('Minsk', 'Nezavisimosti', '50', NULL, '220001'),
        ('Minsk', 'Komsomolskaya', '7A', '22', '220030'),
        ('Grodno', 'Ozheshko', '2', '3', '230025'),
        ('Brest', 'Masherova', '11', NULL, '224000')
     ) AS v(city, street, building, apartment, zipcode)
WHERE NOT EXISTS (
    SELECT 1
    FROM agency.address a
    WHERE a.city = v.city
      AND a.street = v.street
      AND a.building = v.building
      AND COALESCE(a.apartment,'') = COALESCE(v.apartment,'')
)
RETURNING address_id, city, street;

-- ROLLBACK TO SAVEPOINT sp_address;


-- *************** owner ***************
SAVEPOINT sp_owner;

INSERT INTO agency.owner (first_name, last_name, phone, email, document_id)
SELECT v.first_name, v.last_name, v.phone, v.email, v.document_id
FROM (VALUES
        ('Ivan',   'Ivanov',   '+375291112233', 'ivan@gmail.com',   'AB1234567'),
        ('Petr',   'Petrov',   '+375291234567', 'petrov@gmail.com', 'AB9876543'),
        ('Olga',   'Sidorova', '+375298887766', 'olga@mail.com',    'KH5566778'),
        ('Anna',   'Novik',    '+375292221144', 'anna@mail.com',    'MP4455667'),
        ('Sergey', 'Kozlov',   '+375296661122', 'serg@mail.com',    'PP9988776'),
        ('Maria',  'Petrova',  '+375291009988', 'maria@mail.com',   'LL1122334')
     ) AS v(first_name, last_name, phone, email, document_id)
WHERE NOT EXISTS (
    SELECT 1 FROM agency.owner o WHERE LOWER(o.email) = LOWER(v.email)
)
RETURNING owner_id, email;

-- ROLLBACK TO SAVEPOINT sp_owner;


-- *************** agent ***************
SAVEPOINT sp_agent;

INSERT INTO agency.agent (first_name, last_name, email, phone, hired_at)
SELECT v.first_name, v.last_name, v.email, v.phone, v.hired_at
FROM (VALUES
        ('Alex',   'Morozov', 'alex@agency.com',   '+375291111111', DATE '2023-05-10'),
        ('Diana',  'Kovaleva','diana@agency.com',  '+375292222222', DATE '2023-03-15'),
        ('Maxim',  'Rudnev',  'max@agency.com',    '+375293333333', DATE '2023-07-01'),
        ('Nina',   'Orlova',  'nina@agency.com',   '+375294444444', DATE '2023-09-20'),
        ('Roman',  'Karpov',  'roman@agency.com',  '+375295555555', DATE '2024-01-11'),
        ('Elena',  'Stepanova','elena@agency.com', '+375296666666', DATE '2023-12-05')
     ) AS v(first_name, last_name, email, phone, hired_at)
WHERE NOT EXISTS (
    SELECT 1 FROM agency.agent a WHERE LOWER(a.email) = LOWER(v.email)
)
RETURNING agent_id, email;

-- ROLLBACK TO SAVEPOINT sp_agent;


-- *************** client ***************
SAVEPOINT sp_client;

INSERT INTO agency.client (first_name, last_name, email, phone, client_type_id)
SELECT v.first_name, v.last_name, v.email, v.phone, ct.client_type_id
FROM (VALUES
        ('Oleg',   'Smirnov', 'oleg@gmail.com',   '+375291010101', 'buyer'),
        ('Irina',  'Kozlova', 'irina@gmail.com',  '+375292020202', 'seller'),
        ('Dmitry', 'Klimov',  'dk@mail.com',      '+375293030303', 'investor'),
        ('Svetlana','Moroz',  'sveta@mail.com',   '+375294040404', 'renter'),
        ('Kirill', 'Bondar',  'kirill@mail.com',  '+375295050505', 'buyer'),
        ('Yana',   'Semenova','yana@gmail.com',   '+375296060606', 'partner')
     ) AS v(first_name, last_name, email, phone, type_name)
INNER JOIN agency.client_type ct 
      ON LOWER(ct.type_name) = LOWER(v.type_name)
WHERE NOT EXISTS (
    SELECT 1 FROM agency.client c WHERE LOWER(c.email) = LOWER(v.email)
)
RETURNING client_id, email;

-- ROLLBACK TO SAVEPOINT sp_client;


COMMIT;

-- ================= END OF BLOCK 2 ============================


-- ============================================================
-- BLOCK 3: PROPERTY LAYER  
-- Loads: property, property_owner, property_history
-- Fully normalized JOINs (city, street, building, apartment)
-- ============================================================

BEGIN;

-- *************** property ***************
SAVEPOINT sp_property;

INSERT INTO agency.property 
(area, price, rooms, year_built, description,
 address_id, property_type_id, property_status_id)
SELECT 
    v.area,
    v.price,
    v.rooms,
    v.year_built,
    v.description,
    a.address_id,
    pt.property_type_id,
    ps.property_status_id
FROM (VALUES
        (45.5,  75000, 2, 1998, 'Nice small apartment',      'Minsk','Lenina',        '10','5',   'apartment','available'),
        (62.0,  99000, 3, 2005, 'Renovated flat',            'Minsk','Pobediteley',  '15','12',  'apartment','available'),
        (120.0, 150000,4, 2010, 'Modern house',              'Minsk','Nezavisimosti','50',NULL,  'house',    'available'),
        (200.0, 310000,5, 2018, 'Large private house',       'Brest','Masherova',    '11',NULL, 'house',     'reserved'),
        (55.0,  80000, 2, 2001, 'Studio apartment',          'Grodno','Ozheshko',    '2','3',   'studio',   'available'),
        (300.0, 500000,8, 2020, 'Commercial space',          'Minsk','Komsomolskaya','7A',NULL, 'commercial','available')
     ) AS v(area, price, rooms, year_built, description,
            city, street, building, apartment,
            type_name, status_name)
INNER JOIN agency.address a
      ON  a.city = v.city
      AND a.street = v.street
      AND a.building = v.building
      AND COALESCE(a.apartment, '') = COALESCE(v.apartment, '')
INNER JOIN agency.property_type pt
      ON LOWER(pt.type_name) = LOWER(v.type_name)
INNER JOIN agency.property_status ps
      ON LOWER(ps.status_name) = LOWER(v.status_name)
WHERE NOT EXISTS (
    SELECT 1 
    FROM agency.property p 
    WHERE p.address_id = a.address_id
)
RETURNING property_id, area;

--ROLLBACK TO SAVEPOINT sp_property;


-- *************** property_owner ***************
SAVEPOINT sp_property_owner;

INSERT INTO agency.property_owner (ownership_share, property_id, owner_id)
SELECT
    v.share,
    p.property_id,
    o.owner_id
FROM (VALUES
        (0.5, 'Minsk','Lenina','10','5',  'ivan@gmail.com'),
        (0.5, 'Minsk','Lenina','10','5',  'olga@mail.com'),
        (1.0, 'Minsk','Nezavisimosti','50',NULL, 'anna@mail.com'),
        (1.0, 'Grodno','Ozheshko','2','3','maria@mail.com'),
        (0.7, 'Brest','Masherova','11',NULL,'serg@mail.com'),
        (0.3, 'Brest','Masherova','11',NULL,'olga@mail.com')
     ) AS v(share, city, street, building, apartment, owner_email)
INNER JOIN agency.address a
      ON a.city = v.city
     AND a.street = v.street
     AND a.building = v.building
     AND COALESCE(a.apartment,'') = COALESCE(v.apartment,'')
INNER JOIN agency.property p
      ON p.address_id = a.address_id
INNER JOIN agency.owner o
      ON LOWER(o.email) = LOWER(v.owner_email)
WHERE NOT EXISTS (
    SELECT 1
    FROM agency.property_owner po
    WHERE po.property_id = p.property_id
      AND po.owner_id = o.owner_id
)
RETURNING property_owner_id, ownership_share;

-- ROLLBACK TO SAVEPOINT sp_property_owner;


-- *************** property_history ***************
SAVEPOINT sp_property_history;

INSERT INTO agency.property_history
(property_id, changed_by, old_status_id, new_status_id, comment)
SELECT
    p.property_id,
    ag.agent_id,
    ps_old.property_status_id,
    ps_new.property_status_id,
    v.comment
FROM (VALUES
        ('Minsk','Lenina','10','5','alex@agency.com','available','reserved','Price updated'),
        ('Minsk','Lenina','10','5','max@agency.com','reserved','available','Status reverted'),
        ('Brest','Masherova','11',NULL,'diana@agency.com','available','reserved','Owner change'),
        ('Minsk','Nezavisimosti','50',NULL,'roman@agency.com','available','sold','Deal closed'),
        ('Grodno','Ozheshko','2','3','elena@agency.com','available','reserved','Client interested'),
        ('Minsk','Komsomolskaya','7A',NULL,'alex@agency.com','available','reserved','Offer updated')
     ) AS v(city, street, building, apartment, agent_email, old_status, new_status, comment)

INNER JOIN agency.address a
      ON a.city = v.city
     AND a.street = v.street
     AND a.building = v.building
     AND COALESCE(a.apartment,'') = COALESCE(v.apartment,'')

INNER JOIN agency.property p
      ON p.address_id = a.address_id

INNER JOIN agency.agent ag
      ON LOWER(ag.email) = LOWER(v.agent_email)

INNER JOIN agency.property_status ps_old
      ON LOWER(ps_old.status_name) = LOWER(v.old_status)

INNER JOIN agency.property_status ps_new
      ON LOWER(ps_new.status_name) = LOWER(v.new_status)

WHERE NOT EXISTS (
    SELECT 1
    FROM agency.property_history ph
    WHERE ph.property_id = p.property_id
      AND ph.changed_by = ag.agent_id
      AND ph.old_status_id = ps_old.property_status_id
      AND ph.new_status_id = ps_new.property_status_id
)

RETURNING history_id;


--ROLLBACK TO SAVEPOINT sp_property_history;


COMMIT;

-- ================ END OF BLOCK 3 =============================

BEGIN;

---------------------------------------------------------------
-- *************** SHOWING ***************
---------------------------------------------------------------
SAVEPOINT sp_showing;

INSERT INTO agency.showing
(showing_datetime, comment, property_id, client_id, agent_id, result_id)
SELECT
    v.showing_datetime,
    v.comment,
    p.property_id,
    c.client_id,
    a.agent_id,
    sr.result_id
FROM (VALUES
    (TIMESTAMP '2026-01-05 10:00', 'First visit',      'oleg@gmail.com',    'alex@agency.com',   'Minsk','Lenina','10','5','interested'),
    (TIMESTAMP '2026-01-06 11:30', 'Client unsure',    'sveta@mail.com',    'diana@agency.com',  'Minsk','Pobediteley','15','12','declined'),
    (TIMESTAMP '2026-01-07 15:00', 'Strong interest',  'kirill@mail.com',   'max@agency.com',    'Minsk','Nezavisimosti','50',NULL,'interested'),
    (TIMESTAMP '2026-01-09 13:20', 'Bad impression',   'yana@gmail.com',    'nina@agency.com',   'Grodno','Ozheshko','2','3','bad_impression'),
    (TIMESTAMP '2026-01-11 09:45', 'Second look',      'irina@gmail.com',   'roman@agency.com',  'Brest','Masherova','11',NULL,'second_visit'),
    (TIMESTAMP '2026-01-12 16:10', 'Rescheduled',      'oleg@gmail.com',    'elena@agency.com',  'Minsk','Komsomolskaya','7A',NULL,'delayed')
) AS v(showing_datetime, comment, client_email, agent_email,
        city, street, building, apartment, result_name)

INNER JOIN agency.client c 
    ON LOWER(c.email) = LOWER(v.client_email)

INNER JOIN agency.agent a
    ON LOWER(a.email) = LOWER(v.agent_email)

INNER JOIN agency.address addr
    ON addr.city = v.city
   AND addr.street = v.street
   AND addr.building = v.building
   AND COALESCE(addr.apartment,'') = COALESCE(v.apartment,'')

INNER JOIN agency.property p
    ON p.address_id = addr.address_id

INNER JOIN agency.showing_result sr
    ON LOWER(sr.result_name) = LOWER(v.result_name)

WHERE NOT EXISTS (
    SELECT 1
    FROM agency.showing s
    WHERE s.property_id = p.property_id
      AND s.client_id = c.client_id
      AND s.showing_datetime = v.showing_datetime
)
RETURNING showing_id, showing_datetime;

--ROLLBACK TO SAVEPOINT sp_showing;



---------------------------------------------------------------
-- *************** CONTRACT ***************
---------------------------------------------------------------
SAVEPOINT sp_contract;

INSERT INTO agency.contract
(contract_number, contract_date, validity_period, final_price,
 property_id, client_id, agent_id, contract_type_id, contract_status_id)
SELECT
    v.contract_number,
    v.contract_date,
    v.validity_period,
    v.final_price,
    p.property_id,
    c.client_id,
    a.agent_id,
    ct.contract_type_id,
    cs.contract_status_id
FROM (VALUES
    ('CNT-001', DATE '2026-02-01', DATE '2026-12-31', 74000,  'oleg@gmail.com', 'alex@agency.com','Minsk','Lenina','10','5','sale','active'),
    ('CNT-002', DATE '2026-02-05', DATE '2026-12-31', 150000, 'dmitry@mail.com', 'roman@agency.com','Minsk','Nezavisimosti','50',NULL,'purchase','completed'),
    ('CNT-003', DATE '2026-02-06', DATE '2027-02-01', 310000, 'yana@gmail.com', 'max@agency.com','Brest','Masherova','11',NULL,'sale','pending'),
    ('CNT-004', DATE '2026-02-10', DATE '2026-12-31', 80000,  'kirill@mail.com','diana@agency.com','Grodno','Ozheshko','2','3','rent','active'),
    ('CNT-005', DATE '2026-02-12', DATE '2027-01-01', 500000, 'sveta@mail.com','elena@agency.com','Minsk','Komsomolskaya','7A',NULL,'lease','active')
) AS v(contract_number, contract_date, validity_period, final_price,
        client_email, agent_email, city, street, building, apartment,
        contract_type, contract_status)

INNER JOIN agency.client c 
      ON LOWER(c.email) = LOWER(v.client_email)

INNER JOIN agency.agent a
      ON LOWER(a.email) = LOWER(v.agent_email)

INNER JOIN agency.address addr
      ON addr.city = v.city
     AND addr.street = v.street
     AND addr.building = v.building
     AND COALESCE(addr.apartment,'') = COALESCE(v.apartment,'')

INNER JOIN agency.property p
      ON p.address_id = addr.address_id

INNER JOIN agency.contract_type ct
      ON LOWER(ct.type_name) = LOWER(v.contract_type)

INNER JOIN agency.contract_status cs
      ON LOWER(cs.status_name) = LOWER(v.contract_status)

WHERE NOT EXISTS (
    SELECT 1 
    FROM agency.contract c2
    WHERE c2.contract_number = v.contract_number
)
RETURNING contract_id, contract_number;



---------------------------------------------------------------
-- *************** PAYMENT ***************
---------------------------------------------------------------
SAVEPOINT sp_payment;

INSERT INTO agency.payment
(amount, payment_date, contract_id, payment_type_id, payment_status_id)
SELECT
    v.amount,
    v.payment_date,
    c.contract_id,
    pt.payment_type_id,
    ps.payment_status_id
FROM (VALUES
    (74000,  TIMESTAMP '2026-02-02 12:00', 'CNT-001', 'bank_transfer', 'completed'),
    (150000, TIMESTAMP '2026-02-06 09:30', 'CNT-002', 'card',         'completed'),
    (10000,  TIMESTAMP '2026-02-06 14:45', 'CNT-003', 'cash',         'pending'),
    (80000,  TIMESTAMP '2026-02-11 11:10', 'CNT-004', 'mobile_payment','completed'),
    (250000, TIMESTAMP '2026-02-15 17:20', 'CNT-005', 'crypto',       'processing')
) AS v(amount, payment_date, contract_number, type_name, status_name)

INNER JOIN agency.contract c
      ON c.contract_number = v.contract_number

INNER JOIN agency.payment_type pt
      ON LOWER(pt.type_name) = LOWER(v.type_name)

INNER JOIN agency.payment_status ps
      ON LOWER(ps.status_name) = LOWER(v.status_name)

WHERE NOT EXISTS (
    SELECT 1 
    FROM agency.payment p
    WHERE p.contract_id = c.contract_id
      AND p.amount = v.amount
      AND p.payment_date = v.payment_date
)
RETURNING payment_id, amount;

-- ROLLBACK TO SAVEPOINT sp_payment;



COMMIT;

/********************************************************************************************
 * TASK — Update a specific column of a single row in the "client" table using dynamic SQL
 *
 * Description:
 *     This function updates one chosen column of a row in the 'agency.client' table.
 *     It accepts three parameters:
 *         1. p_client_id     – the primary key of the client to update
 *         2. p_column_name   – the name of the column to update
 *         3. p_new_value     – the new value to assign to the column
 *
 * Requirements:
 *     - Must validate that the specified column exists in the table.
 *     - Must build the UPDATE statement using dynamic SQL (EXECUTE).
 *     - Must safely escape identifiers and values (use format() with %I and %L).
 *     - Must update the "last_update" field automatically.
 *     - Must return a text message describing the result.
 *     - Must be rerunnable (CREATE OR REPLACE FUNCTION).
 ********************************************************************************************/

CREATE OR REPLACE FUNCTION agency.update_client_dynamic(
    p_client_id INT,
    p_column_name TEXT,
    p_new_value TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    sql_stmt TEXT;
    column_exists BOOLEAN;
    updated_rows INT;   -- <<< ВОТ ЭТА ПЕРЕМЕННАЯ ОБЯЗАТЕЛЬНО НУЖНА
BEGIN
    -- Validate that the provided column exists
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'agency'
          AND table_name = 'client'
          AND column_name = p_column_name
    )
    INTO column_exists;

    IF NOT column_exists THEN
        RAISE EXCEPTION 'Column "%" does not exist in table agency.client', p_column_name;
    END IF;

    -- Build dynamic SQL
    sql_stmt := format(
        'UPDATE agency.client 
         SET %I = %L, last_update = CURRENT_TIMESTAMP 
         WHERE client_id = %s',
        p_column_name,
        p_new_value,
        p_client_id
    );

    EXECUTE sql_stmt;

    -- Count rows affected
    GET DIAGNOSTICS updated_rows = ROW_COUNT;

    IF updated_rows = 0 THEN
        RETURN format('Client with id %s not found. No updates applied.', p_client_id);
    END IF;

    RETURN format(
        'Successfully updated column "%s" for client_id = %s',
        p_column_name, p_client_id
    );
END;
$$;



-- ============================================================
-- TESTS FOR FUNCTION: update_client_dynamic
-- These tests verify correct behavior of the update function.
-- ============================================================


-- ===========================
-- TEST #1 — Successful update
-- Update email for client_id = 1
-- ===========================
SELECT agency.update_client_dynamic(1, 'email', 'new_email@test.com');

-- Check result:
SELECT client_id, email, last_update
FROM agency.client
WHERE client_id = 1;



-- ==========================================
-- TEST #2 — Invalid column name (should fail)
-- Attempt to update a nonexistent column
-- ==========================================
SELECT agency.update_client_dynamic(1, 'abracadabra', 'test');
-- Expected:
-- ERROR: Column "abracadabra" does not exist in table agency.client



-- ====================================
-- TEST #3 — Client ID not found (error)
-- Update row that does not exist
-- ====================================
SELECT agency.update_client_dynamic(9999, 'email', 'x@mail.com');
-- Expected:
-- ERROR: Client with id 9999 not found. No updates applied.



-- ====================================
-- TEST #4 — Valid numeric update
-- Update client_type_id for client_id = 3
-- ====================================
SELECT agency.update_client_dynamic(3, 'client_type_id', '2');

-- Check result:
SELECT client_id, client_type_id
FROM agency.client
WHERE client_id = 3;


/********************************************************************************************
 * FUNCTION: add_payment
 *
 * TASK:
 * Create a function that adds a new transaction (payment) into the payment table.
 * The function must accept natural keys as inputs:
 *     - contract_number (instead of contract_id)
 *     - payment_type name (instead of payment_type_id)
 *     - payment_status name (instead of payment_status_id)
 *
 * The function should:
 *     1. Validate existence of the contract_number, payment_type, payment_status
 *     2. Insert a new payment row into agency.payment
 *     3. Return a confirmation message on success
 *
 * Notes:
 *     - Multiple payments for the same contract MUST be allowed
 *     - Input values may have different letter cases (UPPER/lower/mIxEd)
 *     - The function returns TEXT describing the result of execution
 ********************************************************************************************/

CREATE OR REPLACE FUNCTION agency.add_payment(
    p_contract_number TEXT,
    p_amount NUMERIC,
    p_payment_date TIMESTAMP,
    p_payment_type TEXT,
    p_payment_status TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_contract_id INT;
    v_payment_type_id INT;
    v_payment_status_id INT;
BEGIN
    -- 1. Find contract_id by contract_number
    SELECT contract_id
    INTO v_contract_id
    FROM agency.contract
    WHERE contract_number = p_contract_number;

    IF v_contract_id IS NULL THEN
        RAISE NOTICE 'Contract "%" does not exist.', p_contract_number;
        RETURN 'contract not found';
    END IF;

    -- 2. Find payment_type_id
    SELECT payment_type_id
    INTO v_payment_type_id
    FROM agency.payment_type
    WHERE LOWER(type_name) = LOWER(p_payment_type);

    IF v_payment_type_id IS NULL THEN
        RAISE NOTICE 'Payment type "%" does not exist.', p_payment_type;
        RETURN 'payment type not found';
    END IF;

    -- 3. Find payment_status_id
    SELECT payment_status_id
    INTO v_payment_status_id
    FROM agency.payment_status
    WHERE LOWER(status_name) = LOWER(p_payment_status);

    IF v_payment_status_id IS NULL THEN
        RAISE NOTICE 'Payment status "%" does not exist.', p_payment_status;
        RETURN 'payment status not found';
    END IF;

    -- 4. Insert payment
    INSERT INTO agency.payment (amount, payment_date, contract_id, payment_type_id, payment_status_id)
    VALUES (p_amount, p_payment_date, v_contract_id, v_payment_type_id, v_payment_status_id);

    RETURN 'Payment added successfully';
END;
$$;

/********************************************************************************************
 * TEST 1 — Insert a valid payment (happy path)
 * Expected:
 *     - Function returns: 'Payment added successfully'
 *     - A new row appears in agency.payment
 ********************************************************************************************/
SELECT agency.add_payment(
    'CNT-001'::TEXT,
    50000::NUMERIC,
    NOW()::TIMESTAMP,
    'bank_transfer'::TEXT,
    'completed'::TEXT
);


SELECT *
FROM agency.payment
ORDER BY payment_id DESC
LIMIT 1;



/********************************************************************************************
 * TEST 2 — Non-existent contract number
 * Expected:
 *     - Function returns: 'contract not found'
 *     - No payment is inserted into agency.payment
 ********************************************************************************************/
SELECT agency.add_payment(
    'CNT-999'::TEXT,      -- DOES NOT EXIST
    30000::NUMERIC,
    NOW()::TIMESTAMP,
    'cash'::TEXT,
    'pending'::TEXT
);

-- Optional: confirm no new payment was added
SELECT *
FROM agency.payment
WHERE contract_id IS NULL;  -- should return 0 rows




/********************************************************************************************
 * TEST 3 — Non-existent payment type
 * Expected:
 *     - Function returns: 'payment type not found'
 ********************************************************************************************/
SELECT agency.add_payment(
    'CNT-003'::TEXT,       -- exists
    10000::NUMERIC,
    NOW()::TIMESTAMP,
    'whatthefuck'::TEXT,   -- not exists
    'pending'::TEXT        -- exists
);



/********************************************************************************************
 * TEST 4 — Non-existent payment status
 * Expected:
 *     - NOTICE: Payment status "hahaha" does not exist
 *     - Function returns: 'payment status not found'
 ********************************************************************************************/
SELECT agency.add_payment(
    'CNT-003'::TEXT,
    10000::NUMERIC,
    NOW()::TIMESTAMP,
    'whatever'::TEXT, --invalid status
    'pending'::TEXT
);




/********************************************************************************************
 * TEST 5 — Check that function handles lowercase/uppercase (case-insensitive)
 * Expected:
 *     - Should still insert successfully
 ********************************************************************************************/
SELECT agency.add_payment(
    'CNT-001'::TEXT,     -- lowercase on purpose
    77777::NUMERIC,
    NOW()::TIMESTAMP,
    'CARD'::TEXT,        -- uppercase on purpose
    'Completed'::TEXT    -- mixed case
);




/********************************************************************************************
 * TEST 6 — Inserting multiple payments for the same contract
 *
 * Expected:
 *     - Function allows multiple payments for one contract
 *     - All payments should appear in agency.payment
 ********************************************************************************************/

-- Insert payment #1
SELECT agency.add_payment(
    'CNT-001'::TEXT,
    11111::NUMERIC,
    NOW()::TIMESTAMP,
    'crypto'::TEXT,
    'processing'::TEXT
);

-- Insert payment #2
SELECT agency.add_payment(
    'CNT-001'::TEXT,
    22222::NUMERIC,
    NOW()::TIMESTAMP,
    'card'::TEXT,
    'pending'::TEXT
);

-- Check all payments for contract CNT-001
SELECT *
FROM agency.payment
WHERE contract_id = (
    SELECT contract_id
    FROM agency.contract
    WHERE contract_number = 'CNT-001'
);

/********************************************************************************************
 * VIEW NAME: quarterly_payment_analytics
 *
 * DESCRIPTION:
 *     This view provides payment analytics for the *most recently added quarter* in the
 *     database. The logic is fully dynamic — whenever new payments appear in a newer quarter,
 *     the view automatically updates to reflect that quarter.
 *
 * FEATURES:
 *     - Automatically detects the latest quarter (year + quarter) from agency.payment
 *     - Includes only payments from that quarter
 *     - Returns only NATURAL attributes (no surrogate keys)
 *     - Aggregates analytics per client & contract
 *
 * OUTPUT EXAMPLE:
 *     client_name, client_email, contract_number, payment_type, payment_status,
 *     total_amount, payments_count, avg_amount
 *
 * NOTES:
 *     Surrogate keys such as payment_id, contract_id, payment_type_id, etc. are excluded.
 ********************************************************************************************/

CREATE OR REPLACE VIEW agency.quarterly_payment_analytics AS
WITH last_q AS (
    /****************************************************************************************
     * STEP 1: Find the most recent quarter in the database
     * Returns exactly one row: (year, quarter)
     ****************************************************************************************/
    SELECT 
        EXTRACT(YEAR FROM payment_date) AS year,
        EXTRACT(QUARTER FROM payment_date) AS quarter
    FROM agency.payment
    ORDER BY year DESC, quarter DESC
    LIMIT 1
),

filtered_payments AS (
    /****************************************************************************************
     * STEP 2: Select all payments that belong to the most recent quarter
     * CROSS JOIN attaches last_q.year and last_q.quarter to every payment row
     * allowing the WHERE filter to work correctly
     ****************************************************************************************/
    SELECT p.*
    FROM agency.payment p
    CROSS JOIN last_q q
    WHERE EXTRACT(YEAR FROM p.payment_date) = q.year
      AND EXTRACT(QUARTER FROM p.payment_date) = q.quarter
)

SELECT
    /****************************************************************************************
     * STEP 3: Produce natural-key-based analytics
     * No surrogate keys appear in the output
     ****************************************************************************************/
    c.first_name || ' ' || c.last_name       AS client_name,
    c.email                                  AS client_email,
    ctr.contract_number                       AS contract_number,
    pt.type_name                              AS payment_type,
    ps.status_name                            AS payment_status,

    -- Analytics
    SUM(fp.amount)                            AS total_amount,
    COUNT(*)                                  AS payments_count,
    AVG(fp.amount)                            AS avg_amount

FROM filtered_payments fp

-- Join to NATURAL dimension tables
INNER JOIN agency.contract ctr
    ON ctr.contract_id = fp.contract_id

INNER JOIN agency.client c
    ON c.client_id = ctr.client_id

INNER JOIN agency.payment_type pt
    ON pt.payment_type_id = fp.payment_type_id

INNER JOIN agency.payment_status ps
    ON ps.payment_status_id = fp.payment_status_id

GROUP BY
    client_name, c.email, ctr.contract_number, pt.type_name, ps.status_name;

/********************************************************************************************
 * TASK — Create a read-only role for the manager
 *
 * DESCRIPTION:
 *     This script creates a secure read-only role intended for managers.
 *     The role follows best practices in PostgreSQL security:
 *       - Can log in to the database
 *       - Has SELECT access ONLY (no INSERT / UPDATE / DELETE / TRUNCATE)
 *       - Has NO ability to create tables, databases, roles, extensions, or schemas
 *       - Cannot escalate privileges (NOSUPERUSER)
 *       - Automatically receives SELECT permissions for future tables in schema "agency"
 *
 * SECURITY PRINCIPLES:
 *     - Principle of Least Privilege (PLP)
 *     - Separation of Duties (SoD)
 *     - Provides safe SELECT-only access to reporting views and data
 ********************************************************************************************/
-- ============================================================
-- READ-ONLY ROLE FOR MANAGERS
-- Provides safe SELECT-only access to reporting views and data
-- ============================================================

--  Create a dedicated read-only role for managers
CREATE ROLE manager_readonly
    LOGIN                      -- allows connecting to PostgreSQL
    PASSWORD 'StrongManagerPass123!'   -- strong password recommended
    NOSUPERUSER                -- prevents full database control
    NOCREATEDB                 -- cannot create new databases
    NOCREATEROLE               -- cannot create or modify roles
    NOINHERIT;                 -- prevents inheriting other privileges

-- Access to schema (required for table access)
GRANT USAGE ON SCHEMA agency TO manager_readonly;

-- Select permissions on all current tables
GRANT SELECT ON ALL TABLES IN SCHEMA agency TO manager_readonly;

-- Auto-grant SELECT for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA agency
GRANT SELECT ON TABLES TO manager_readonly;

-- Grant access to analytics view
GRANT SELECT ON agency.quarterly_payment_analytics TO manager_readonly;

-- Optional: additional explicit safety (blocks writes to the view)
COMMENT ON VIEW agency.quarterly_payment_analytics
    IS 'Read-only analytics view for managers';

/********************************************************************************************
 * ROLE DIAGNOSTICS SCRIPT — manager_readonly
 * This script checks:
 *   1. Role existence and login permissions
 *   2. Granted privileges for schema and tables
 *   3. SELECT access to views
 *   4. Default privileges configuration
 *   5. Summary status output
 ********************************************************************************************/

-- 1. Check if the role exists and can log in
SELECT
    rolname AS role_name,
    rolcanlogin AS can_login,
    rolsuper AS is_superuser,
    rolcreatedb AS can_create_db,
    rolcreaterole AS can_create_role
FROM pg_roles
WHERE rolname = 'manager_readonly';


-- 2. Check schema usage permissions
SELECT
    nspname AS schema_name,
    has_schema_privilege('manager_readonly', n.oid, 'USAGE') AS has_usage_privilege
FROM pg_namespace n
WHERE nspname = 'agency';


-- 3. Check SELECT privileges on all tables in schema "agency"
SELECT
    table_name,
    privilege_type
FROM information_schema.table_privileges
WHERE grantee = 'manager_readonly'
  AND table_schema = 'agency'
  AND privilege_type = 'SELECT'
ORDER BY table_name;


-- 4. Check SELECT privilege on the view (if exists)
SELECT
    table_name AS view_name,
    privilege_type
FROM information_schema.table_privileges
WHERE grantee = 'manager_readonly'
  AND table_name = 'agency.quarterly_payment_analytics';


-- 5. Check default privileges (future tables in schema)
SELECT
    defaclnamespace::regnamespace AS schema_name,
    defaclobjtype AS object_type,
    defaclacl AS default_acl
FROM pg_default_acl
WHERE defaclrole = (SELECT oid FROM pg_roles WHERE rolname = 'manager_readonly');


-- 6. Summary: what the role can and cannot do
SELECT
    'manager_readonly summary:' AS section,
    CASE
        WHEN EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'manager_readonly')
        THEN 'Role exists'
        ELSE 'Role NOT found'
    END AS role_exists,
    CASE
        WHEN has_schema_privilege('manager_readonly', 'agency', 'USAGE')
        THEN 'Can access schema'
        ELSE 'Cannot access schema'
    END AS schema_access,
    CASE
        WHEN EXISTS (
            SELECT 1 FROM information_schema.table_privileges
            WHERE grantee = 'manager_readonly'
              AND privilege_type = 'SELECT'
              AND table_schema = 'agency'
        )
        THEN 'Has SELECT on tables'
        ELSE 'NO SELECT permissions on tables'
    END AS table_select_status;

