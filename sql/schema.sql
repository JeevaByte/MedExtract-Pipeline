-- MedExtract Pipeline PostgreSQL Schema
-- Database: medextract

-- Create database (run separately as superuser)
-- CREATE DATABASE medextract;

-- Connect to database
\c medextract;

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Patients table
CREATE TABLE IF NOT EXISTS patients (
    id SERIAL PRIMARY KEY,
    mrn VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255),
    dob DATE,
    gender VARCHAR(20),
    contact_phone VARCHAR(20),
    contact_email VARCHAR(255),
    address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index on MRN
CREATE INDEX idx_patients_mrn ON patients(mrn);

-- Diagnoses table
CREATE TABLE IF NOT EXISTS diagnoses (
    id SERIAL PRIMARY KEY,
    patient_id INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    diagnosis_text TEXT NOT NULL,
    icd10_code VARCHAR(10),
    snomed_code VARCHAR(20),
    confidence FLOAT,
    diagnosis_date DATE,
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX idx_diagnoses_patient_id ON diagnoses(patient_id);
CREATE INDEX idx_diagnoses_icd10 ON diagnoses(icd10_code);
CREATE INDEX idx_diagnoses_snomed ON diagnoses(snomed_code);

-- Medications table
CREATE TABLE IF NOT EXISTS medications (
    id SERIAL PRIMARY KEY,
    patient_id INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    medication_name VARCHAR(255) NOT NULL,
    rxnorm_code VARCHAR(20),
    dosage VARCHAR(100),
    frequency VARCHAR(100),
    route VARCHAR(50),
    start_date DATE,
    end_date DATE,
    confidence FLOAT,
    status VARCHAR(50) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX idx_medications_patient_id ON medications(patient_id);
CREATE INDEX idx_medications_rxnorm ON medications(rxnorm_code);

-- Procedures table
CREATE TABLE IF NOT EXISTS procedures (
    id SERIAL PRIMARY KEY,
    patient_id INTEGER NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    procedure_name VARCHAR(255) NOT NULL,
    procedure_type VARCHAR(100),
    snomed_code VARCHAR(20),
    procedure_date DATE,
    location VARCHAR(255),
    provider VARCHAR(255),
    confidence FLOAT,
    status VARCHAR(50) DEFAULT 'completed',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX idx_procedures_patient_id ON procedures(patient_id);
CREATE INDEX idx_procedures_snomed ON procedures(snomed_code);

-- Referrals table (audit trail)
CREATE TABLE IF NOT EXISTS referrals (
    id SERIAL PRIMARY KEY,
    message_id VARCHAR(255) UNIQUE NOT NULL,
    patient_id INTEGER REFERENCES patients(id),
    source_email VARCHAR(255),
    received_date TIMESTAMP,
    processed_date TIMESTAMP,
    status VARCHAR(50) DEFAULT 'pending',
    s3_bucket VARCHAR(255),
    s3_key VARCHAR(255),
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX idx_referrals_message_id ON referrals(message_id);
CREATE INDEX idx_referrals_patient_id ON referrals(patient_id);
CREATE INDEX idx_referrals_status ON referrals(status);

-- Extraction log table
CREATE TABLE IF NOT EXISTS extraction_logs (
    id SERIAL PRIMARY KEY,
    referral_id INTEGER REFERENCES referrals(id),
    stage VARCHAR(100),
    status VARCHAR(50),
    error_message TEXT,
    execution_time_ms INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index
CREATE INDEX idx_extraction_logs_referral_id ON extraction_logs(referral_id);

-- Create views for analytics

-- View: Patient Summary
CREATE OR REPLACE VIEW patient_summary AS
SELECT 
    p.id,
    p.mrn,
    p.name,
    p.dob,
    COUNT(DISTINCT d.id) as diagnosis_count,
    COUNT(DISTINCT m.id) as medication_count,
    COUNT(DISTINCT pr.id) as procedure_count,
    MAX(r.received_date) as last_referral_date
FROM patients p
LEFT JOIN diagnoses d ON p.id = d.patient_id
LEFT JOIN medications m ON p.id = m.patient_id
LEFT JOIN procedures pr ON p.id = pr.patient_id
LEFT JOIN referrals r ON p.id = r.patient_id
GROUP BY p.id, p.mrn, p.name, p.dob;

-- View: Processing Statistics
CREATE OR REPLACE VIEW processing_stats AS
SELECT 
    DATE(created_at) as date,
    COUNT(*) as total_referrals,
    COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed,
    COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending,
    AVG(EXTRACT(EPOCH FROM (processed_date - received_date))) as avg_processing_time_seconds
FROM referrals
GROUP BY DATE(created_at)
ORDER BY date DESC;

-- Grants (adjust as needed)
-- GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO medextract_app;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO medextract_app;

-- Comments
COMMENT ON TABLE patients IS 'Patient demographic and identification information';
COMMENT ON TABLE diagnoses IS 'Patient diagnoses extracted from referral documents';
COMMENT ON TABLE medications IS 'Patient medications and prescriptions';
COMMENT ON TABLE procedures IS 'Medical procedures and tests';
COMMENT ON TABLE referrals IS 'Referral email tracking and audit trail';
COMMENT ON TABLE extraction_logs IS 'Detailed logs of the extraction pipeline';

-- Functions

-- Update timestamp trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER update_patients_updated_at BEFORE UPDATE ON patients
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_diagnoses_updated_at BEFORE UPDATE ON diagnoses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_medications_updated_at BEFORE UPDATE ON medications
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_procedures_updated_at BEFORE UPDATE ON procedures
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_referrals_updated_at BEFORE UPDATE ON referrals
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMIT;
