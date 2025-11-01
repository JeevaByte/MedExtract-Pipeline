# MedExtract-Pipeline Test Plan

## Overview
This document outlines the comprehensive testing strategy for the MedExtract-Pipeline system.

---

## 1. Unit Testing

### Lambda Functions

#### SES Ingest Handler
- **Test 1**: Valid SES event processing
  - Input: Mock SES email receipt event
  - Expected: Metadata stored in S3, parser Lambda invoked
  
- **Test 2**: Malformed SES event handling
  - Input: Invalid SES event structure
  - Expected: Error logged, graceful failure

- **Test 3**: Spam/virus detected email
  - Input: Email with failed spam/virus verdict
  - Expected: Email quarantined, alert triggered

#### Attachment Parser
- **Test 4**: PDF attachment extraction
  - Input: Email with PDF attachment
  - Expected: Text extracted via Textract, stored in S3

- **Test 5**: Multiple attachments
  - Input: Email with PDF, DOCX, and image
  - Expected: All attachments processed, text combined

- **Test 6**: No attachments
  - Input: Plain text email only
  - Expected: Email body extracted, processed normally

#### Comprehend Medical Worker
- **Test 7**: Medical entity detection
  - Input: Clinical text with diagnoses, medications
  - Expected: Entities extracted with correct categories

- **Test 8**: ICD-10 inference
  - Input: Diagnosis text
  - Expected: ICD-10 codes returned with confidence scores

- **Test 9**: SNOMED CT inference
  - Input: Clinical concepts
  - Expected: SNOMED codes mapped correctly

- **Test 10**: Text length limit handling
  - Input: Text > 20KB
  - Expected: Text truncated, processed without error

#### Ontology Mapper
- **Test 11**: DynamoDB lookup success
  - Input: Known medical term
  - Expected: ICD-10 and SNOMED codes retrieved

- **Test 12**: Unknown term handling
  - Input: Unmapped medical term
  - Expected: Entity processed without mapping, flagged

- **Test 13**: Patient information extraction
  - Input: Text with PHI (name, DOB, MRN)
  - Expected: Patient demographics extracted

#### Postgres Loader
- **Test 14**: New patient insertion
  - Input: Patient data not in database
  - Expected: Patient record created

- **Test 15**: Existing patient update
  - Input: Patient with existing MRN
  - Expected: Patient record updated, not duplicated

- **Test 16**: Referential integrity
  - Input: Diagnoses, medications for patient
  - Expected: Foreign keys maintained, cascade deletes work

---

## 2. Integration Testing

### End-to-End Pipeline

#### Test E2E-1: Complete Referral Processing
**Steps:**
1. Send test email to SES
2. Verify email stored in S3
3. Confirm all Lambda functions execute in sequence
4. Validate data appears in PostgreSQL

**Success Criteria:**
- All pipeline stages complete without error
- Data correctly stored in database
- Processing time < 60 seconds

#### Test E2E-2: Error Recovery
**Steps:**
1. Simulate Comprehend Medical API failure
2. Verify error logged to CloudWatch
3. Check retry logic
4. Confirm graceful degradation

**Success Criteria:**
- Errors caught and logged
- Pipeline doesn't crash
- Failed messages can be reprocessed

#### Test E2E-3: Concurrent Processing
**Steps:**
1. Send 10 emails simultaneously
2. Monitor Lambda concurrency
3. Verify all emails processed
4. Check for race conditions

**Success Criteria:**
- All emails processed successfully
- No data corruption
- Database transactions isolated

---

## 3. Data Quality Testing

### Extraction Accuracy

#### Test DQ-1: Diagnosis Extraction
**Dataset:** 50 sample referrals with known diagnoses
**Metrics:**
- Precision: % of extracted diagnoses that are correct
- Recall: % of actual diagnoses extracted
- F1 Score: Harmonic mean of precision and recall

**Target:** Precision ≥ 0.85, Recall ≥ 0.80

#### Test DQ-2: Medication Extraction
**Dataset:** 50 sample referrals with medications
**Metrics:**
- Correct medication names
- Correct dosages
- Correct frequencies

**Target:** Accuracy ≥ 0.90

#### Test DQ-3: ICD-10 Mapping Accuracy
**Dataset:** 100 diagnoses with ground truth ICD-10 codes
**Metrics:**
- Exact code match rate
- Code family match rate (first 3 characters)

**Target:** Exact match ≥ 0.85

#### Test DQ-4: SNOMED CT Mapping Coverage
**Dataset:** 100 clinical concepts
**Metrics:**
- % of concepts with SNOMED mapping
- Mapping correctness

**Target:** Coverage ≥ 0.80, Correctness ≥ 0.90

---

## 4. Performance Testing

### Load Testing

#### Test P-1: Baseline Performance
**Load:** 1 email per minute
**Duration:** 1 hour
**Metrics:**
- Average processing time
- Lambda cold start frequency
- Database connection pool usage

#### Test P-2: Peak Load
**Load:** 100 emails per hour
**Duration:** 2 hours
**Metrics:**
- Processing time under load
- Lambda throttling events
- Database query performance

#### Test P-3: Stress Testing
**Load:** Gradually increase to 500 emails/hour
**Metrics:**
- System breaking point
- Error rate increase
- Resource utilization

**Target:** Support 200 emails/hour with <5% error rate

### Latency Testing

#### Test L-1: Component Latency
**Measure:**
- SES → S3 storage: < 1 second
- Textract processing: < 5 seconds per page
- Comprehend Medical: < 3 seconds per document
- DynamoDB lookup: < 100ms
- Database insert: < 500ms

#### Test L-2: End-to-End Latency
**Target:** 95th percentile < 60 seconds

---

## 5. Security Testing

### Authentication & Authorization

#### Test S-1: IAM Policy Validation
**Steps:**
1. Verify each Lambda has minimum required permissions
2. Test cross-service access restrictions
3. Validate KMS key access policies

#### Test S-2: Data Encryption
**Verify:**
- S3 objects encrypted with KMS
- RDS encryption at rest enabled
- Data in transit uses TLS 1.2+
- CloudWatch logs encrypted

#### Test S-3: PHI Protection
**Verify:**
- Patient names properly detected as PHI
- NHS numbers identified and protected
- Audit logs capture all PHI access

### Penetration Testing

#### Test S-4: Injection Attacks
**Test SQL injection in:**
- Patient name fields
- Diagnosis text
- Medication names

**Expected:** All inputs properly sanitized

#### Test S-5: Email Security
**Test:**
- Spoofed sender addresses
- Malicious attachments
- Oversized emails

**Expected:** Threats detected and quarantined

---

## 6. Compliance Testing

### GDPR/UK GDPR

#### Test C-1: Data Retention
**Verify:**
- S3 lifecycle policies move old data to Glacier
- Data deleted after retention period
- Soft delete implemented for database records

#### Test C-2: Right to Access
**Test:**
- Query all data for a specific patient
- Export data in machine-readable format

#### Test C-3: Right to Erasure
**Test:**
- Delete all records for a patient
- Verify cascading deletes work
- Confirm S3 objects removed

### NHS DSPT

#### Test C-4: Audit Trail
**Verify:**
- CloudTrail captures all API calls
- CloudWatch logs all processing steps
- Logs retained for required period (7 years)

#### Test C-5: Access Controls
**Verify:**
- MFA required for admin access
- Role-based access control implemented
- Principle of least privilege applied

---

## 7. Disaster Recovery Testing

### Backup & Restore

#### Test DR-1: Database Backup
**Steps:**
1. Trigger manual Aurora snapshot
2. Restore to new cluster
3. Verify data integrity

**Success Criteria:** RTO < 1 hour, RPO < 15 minutes

#### Test DR-2: S3 Recovery
**Steps:**
1. Enable versioning
2. Delete critical objects
3. Restore from version history

#### Test DR-3: Full System Recovery
**Steps:**
1. Delete entire Terraform stack
2. Redeploy from code
3. Restore data from backups
4. Verify system operational

**Target:** RTO < 4 hours

---

## 8. Monitoring & Alerting Testing

### CloudWatch Alarms

#### Test M-1: Lambda Error Alarm
**Trigger:** Force Lambda to throw error
**Expected:** Alarm fires within 5 minutes, SNS notification sent

#### Test M-2: High Latency Alarm
**Trigger:** Simulate slow processing
**Expected:** Latency alarm triggers

#### Test M-3: Database Connection Alarm
**Trigger:** Max out database connections
**Expected:** Alarm fires, auto-scaling triggered

---

## 9. User Acceptance Testing

### Clinical Workflow

#### Test UAT-1: Clinician Review
**Participants:** 5 clinicians
**Tasks:**
1. Review extracted referral data
2. Validate medical accuracy
3. Identify missing information

**Acceptance Criteria:** 
- 90% of extracted data accurate
- <5% critical errors
- Positive user feedback

#### Test UAT-2: Administrative Review
**Participants:** 2 administrators
**Tasks:**
1. Monitor system dashboard
2. Review audit logs
3. Generate compliance reports

---

## 10. Regression Testing

### Automated Test Suite

Run full test suite on every deployment:
- All unit tests
- Integration tests
- Smoke tests on production
- Data quality validation

**Target:** 95% test coverage, all tests pass

---

## Test Execution Schedule

### Phase 1: Development (Week 1-2)
- Unit tests
- Component integration tests

### Phase 2: Integration (Week 3)
- End-to-end pipeline tests
- Performance baseline

### Phase 3: Quality Assurance (Week 4)
- Data quality validation
- Security testing
- Load testing

### Phase 4: Pre-Production (Week 5)
- UAT
- Disaster recovery testing
- Compliance validation

### Phase 5: Production (Week 6+)
- Smoke tests
- Continuous monitoring
- Regression testing on updates

---

## Test Data

### Sample Datasets
1. **Basic Referrals:** 10 simple cases
2. **Complex Referrals:** 10 multi-condition cases
3. **Edge Cases:** 10 unusual formats/structures
4. **Stress Test Data:** 1000 synthetic referrals

### Ground Truth
- Manually annotated by clinicians
- ICD-10 codes verified against standards
- SNOMED codes validated

---

## Success Metrics

### Overall System
- Availability: 99.9%
- Error rate: <1%
- Processing time: 95th percentile < 60s

### Data Quality
- Extraction precision: ≥0.85
- Extraction recall: ≥0.80
- ICD-10 accuracy: ≥0.85
- SNOMED coverage: ≥0.80

### Security
- Zero PHI breaches
- 100% encryption compliance
- All vulnerabilities remediated

---

## Defect Management

### Severity Levels
- **Critical:** System down, data loss, PHI breach
- **High:** Major functionality broken, incorrect diagnoses
- **Medium:** Minor functionality issues, UI problems
- **Low:** Cosmetic issues, documentation errors

### Resolution Targets
- Critical: 4 hours
- High: 24 hours
- Medium: 1 week
- Low: 2 weeks

---

## Test Environment

### Development
- Isolated AWS account
- Synthetic test data only
- Full logging enabled

### Staging
- Production-like configuration
- De-identified real data
- Performance monitoring

### Production
- Live system
- Real patient data (with consent)
- Comprehensive monitoring

---

## Continuous Testing

### CI/CD Pipeline
1. Code commit triggers automated tests
2. All tests must pass before merge
3. Deployment to staging runs full test suite
4. Production deployment after manual approval

### Monitoring
- Real-time error tracking
- Performance metrics
- Data quality dashboards
- Security alerts

---

## Sign-off

Testing completed by: ___________________
Date: ___________________
Approved for production: Yes / No

---

**Note:** This test plan should be reviewed and updated quarterly to reflect system changes and new requirements.
