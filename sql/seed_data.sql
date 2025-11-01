-- Sample seed data for MedExtract Pipeline
-- This data is for testing and demonstration purposes only

\c medextract;

-- Insert sample patients
INSERT INTO patients (mrn, name, dob, gender, created_at, updated_at) VALUES
('NHS001234', 'John Smith', '1982-07-14', 'Male', NOW(), NOW()),
('NHS005678', 'Mary Johnson', '1975-03-22', 'Female', NOW(), NOW()),
('NHS009012', 'Robert Williams', '1990-11-30', 'Male', NOW(), NOW());

-- Insert sample diagnoses
INSERT INTO diagnoses (patient_id, diagnosis_text, icd10_code, snomed_code, confidence, diagnosis_date, created_at) VALUES
(1, 'Type 2 Diabetes Mellitus', 'E11', '44054006', 0.95, '2024-01-15', NOW()),
(1, 'Hypertension', 'I10', '38341003', 0.92, '2024-01-15', NOW()),
(2, 'Asthma', 'J45', '195967001', 0.88, '2024-02-10', NOW()),
(3, 'Depression', 'F32', '35489007', 0.85, '2024-03-05', NOW());

-- Insert sample medications
INSERT INTO medications (patient_id, medication_name, rxnorm_code, dosage, frequency, route, confidence, created_at) VALUES
(1, 'Metformin', '6809', '500mg', 'Twice daily', 'Oral', 0.93, NOW()),
(1, 'Lisinopril', '29046', '10mg', 'Once daily', 'Oral', 0.91, NOW()),
(2, 'Albuterol', '435', '90mcg', 'As needed', 'Inhaled', 0.89, NOW()),
(3, 'Sertraline', '36437', '50mg', 'Once daily', 'Oral', 0.87, NOW());

-- Insert sample procedures
INSERT INTO procedures (patient_id, procedure_name, procedure_type, snomed_code, procedure_date, confidence, created_at) VALUES
(1, 'HbA1c Test', 'Laboratory', '43396009', '2024-01-15', 0.94, NOW()),
(1, 'Blood Pressure Measurement', 'Vital Signs', '75367002', '2024-01-15', 0.96, NOW()),
(2, 'Spirometry', 'Pulmonary Function', '127783003', '2024-02-10', 0.90, NOW()),
(3, 'PHQ-9 Depression Screening', 'Mental Health', '715252007', '2024-03-05', 0.88, NOW());

-- Insert sample referrals
INSERT INTO referrals (message_id, patient_id, source_email, received_date, processed_date, status, s3_bucket, s3_key, metadata) VALUES
('msg-001-2024', 1, 'gp.surgery@nhs.uk', '2024-01-15 09:30:00', '2024-01-15 09:35:00', 'completed', 'medextract-pipeline-emails-dev', 'incoming/msg-001-2024', '{"spam_score": 0.1, "virus_check": "clean"}'::jsonb),
('msg-002-2024', 2, 'clinic@nhs.uk', '2024-02-10 14:20:00', '2024-02-10 14:28:00', 'completed', 'medextract-pipeline-emails-dev', 'incoming/msg-002-2024', '{"spam_score": 0.0, "virus_check": "clean"}'::jsonb),
('msg-003-2024', 3, 'hospital@nhs.uk', '2024-03-05 11:15:00', '2024-03-05 11:22:00', 'completed', 'medextract-pipeline-emails-dev', 'incoming/msg-003-2024', '{"spam_score": 0.2, "virus_check": "clean"}'::jsonb);

-- Insert sample extraction logs
INSERT INTO extraction_logs (referral_id, stage, status, execution_time_ms, created_at) VALUES
(1, 'ses_ingest', 'success', 250, '2024-01-15 09:30:15'),
(1, 'attachment_parser', 'success', 1850, '2024-01-15 09:31:00'),
(1, 'comprehend_worker', 'success', 3200, '2024-01-15 09:33:00'),
(1, 'ontology_mapper', 'success', 800, '2024-01-15 09:34:00'),
(1, 'postgres_loader', 'success', 450, '2024-01-15 09:35:00');

COMMIT;

-- Verify data
SELECT 'Patients:', COUNT(*) FROM patients;
SELECT 'Diagnoses:', COUNT(*) FROM diagnoses;
SELECT 'Medications:', COUNT(*) FROM medications;
SELECT 'Procedures:', COUNT(*) FROM procedures;
SELECT 'Referrals:', COUNT(*) FROM referrals;
