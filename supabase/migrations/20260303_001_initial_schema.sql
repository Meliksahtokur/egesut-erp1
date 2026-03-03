-- Enable Row Level Security
ALTER TABLE hayvanlar ENABLE ROW LEVEL SECURITY;
ALTER TABLE stok ENABLE ROW LEVEL SECURITY;
ALTER TABLE stok_hareket ENABLE ROW LEVEL SECURITY;
ALTER TABLE gorev_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE hastalik_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE tohumlama ENABLE ROW LEVEL SECURITY;
ALTER TABLE dogum ENABLE ROW LEVEL SECURITY;
ALTER TABLE buzagi_takip ENABLE ROW LEVEL SECURITY;

-- Table Definitions
CREATE TABLE hayvanlar (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(255) NOT NULL,
    birth_date DATE,
    -- Add more fields as needed
);

CREATE TABLE stok (
    id SERIAL PRIMARY KEY,
    hayvan_id INT REFERENCES hayvanlar(id),
    quantity INT,
    -- Add more fields as needed
);

CREATE TABLE stok_hareket (
    id SERIAL PRIMARY KEY,
    stok_id INT REFERENCES stok(id),
    movement_type VARCHAR(50),
    quantity INT,
    movement_date TIMESTAMP DEFAULT current_timestamp,
    -- Add more fields as needed
);

CREATE TABLE gorev_log (
    id SERIAL PRIMARY KEY,
    hayvan_id INT REFERENCES hayvanlar(id),
    description TEXT,
    log_date TIMESTAMP DEFAULT current_timestamp,
    -- Add more fields as needed
);

CREATE TABLE hastalik_log (
    id SERIAL PRIMARY KEY,
    hayvan_id INT REFERENCES hayvanlar(id),
    disease VARCHAR(255),
    diagnosis_date TIMESTAMP DEFAULT current_timestamp,
    -- Add more fields as needed
);

CREATE TABLE tohumlama (
    id SERIAL PRIMARY KEY,
    hayvan_id INT REFERENCES hayvanlar(id),
    insemination_date TIMESTAMP DEFAULT current_timestamp,
    -- Add more fields as needed
);

CREATE TABLE dogum (
    id SERIAL PRIMARY KEY,
    hayvan_id INT REFERENCES hayvanlar(id),
    birth_date TIMESTAMP DEFAULT current_timestamp,
    -- Add more fields as needed
);

CREATE TABLE buzagi_takip (
    id SERIAL PRIMARY KEY,
    hayvan_id INT REFERENCES hayvanlar(id),
    tracking_date TIMESTAMP DEFAULT current_timestamp,
    -- Add more fields as needed
);

-- Policies for Row Level Security
CREATE POLICY select_policy ON hayvanlar
    FOR SELECT
    USING (true);  -- Apply your own conditions

CREATE POLICY insert_policy ON hayvanlar
    FOR INSERT
    WITH CHECK (true);  -- Apply your own conditions

-- Add more policies for other tables similarly
