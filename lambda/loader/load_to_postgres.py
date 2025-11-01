"""
Postgres Loader Lambda
Loads structured medical data into Aurora PostgreSQL
"""
import json
import boto3
import os
import psycopg2
from datetime import datetime

s3_client = boto3.client('s3')
secrets_client = boto3.client('secretsmanager')

DB_ENDPOINT = os.environ.get('DB_ENDPOINT')
DB_NAME = os.environ.get('DB_NAME', 'medextract')
DB_USER = os.environ.get('DB_USER', 'medextract_admin')
DB_SECRET_NAME = os.environ.get('DB_SECRET_NAME')


def lambda_handler(event, context):
    """
    Load structured data into PostgreSQL database
    """
    print(f"Received event: {json.dumps(event)}")
    
    try:
        message_id = event['messageId']
        data = event['data']
        
        # Get database credentials
        db_password = get_db_password()
        
        # Connect to database
        conn = psycopg2.connect(
            host=DB_ENDPOINT.split(':')[0],
            port=5432,
            database=DB_NAME,
            user=DB_USER,
            password=db_password,
            sslmode='require'
        )
        
        cursor = conn.cursor()
        
        # Insert patient information
        patient_id = insert_patient(cursor, data.get('patient', {}), message_id)
        
        # Insert diagnoses
        for diagnosis in data.get('diagnoses', []):
            insert_diagnosis(cursor, patient_id, diagnosis)
        
        # Insert medications
        for medication in data.get('medications', []):
            insert_medication(cursor, patient_id, medication)
        
        # Insert procedures
        for procedure in data.get('procedures', []):
            insert_procedure(cursor, patient_id, procedure)
        
        # Commit transaction
        conn.commit()
        
        print(f"Successfully loaded data for message {message_id}")
        
        cursor.close()
        conn.close()
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Data loaded successfully',
                'messageId': message_id,
                'patientId': patient_id
            })
        }
        
    except Exception as e:
        print(f"Error loading data: {str(e)}")
        if 'conn' in locals():
            conn.rollback()
            conn.close()
        raise


def get_db_password():
    """Retrieve database password from environment or Secrets Manager"""
    if DB_SECRET_NAME:
        response = secrets_client.get_secret_value(SecretId=DB_SECRET_NAME)
        secret = json.loads(response['SecretString'])
        return secret['password']
    else:
        return os.environ.get('DB_PASSWORD', '')


def insert_patient(cursor, patient_data, message_id):
    """Insert or update patient record"""
    mrn = patient_data.get('mrn', message_id)
    name = patient_data.get('name', 'Unknown')
    age = patient_data.get('age')
    
    # Calculate approximate DOB from age if available
    dob = None
    if age:
        try:
            age_int = int(age.split()[0])
            current_year = datetime.now().year
            dob = f"{current_year - age_int}-01-01"
        except:
            pass
    
    # Upsert patient
    cursor.execute("""
        INSERT INTO patients (mrn, name, dob, created_at, updated_at)
        VALUES (%s, %s, %s, NOW(), NOW())
        ON CONFLICT (mrn) 
        DO UPDATE SET 
            name = EXCLUDED.name,
            dob = COALESCE(EXCLUDED.dob, patients.dob),
            updated_at = NOW()
        RETURNING id
    """, (mrn, name, dob))
    
    patient_id = cursor.fetchone()[0]
    return patient_id


def insert_diagnosis(cursor, patient_id, diagnosis):
    """Insert diagnosis record"""
    cursor.execute("""
        INSERT INTO diagnoses 
        (patient_id, diagnosis_text, icd10_code, snomed_code, confidence, created_at)
        VALUES (%s, %s, %s, %s, %s, NOW())
    """, (
        patient_id,
        diagnosis.get('text'),
        diagnosis.get('icd10_code'),
        diagnosis.get('snomed_code'),
        diagnosis.get('confidence', 0.0)
    ))


def insert_medication(cursor, patient_id, medication):
    """Insert medication record"""
    cursor.execute("""
        INSERT INTO medications 
        (patient_id, medication_name, rxnorm_code, confidence, created_at)
        VALUES (%s, %s, %s, %s, NOW())
    """, (
        patient_id,
        medication.get('name'),
        medication.get('rxnorm_code'),
        medication.get('confidence', 0.0)
    ))


def insert_procedure(cursor, patient_id, procedure):
    """Insert procedure record"""
    cursor.execute("""
        INSERT INTO procedures 
        (patient_id, procedure_name, procedure_type, snomed_code, confidence, created_at)
        VALUES (%s, %s, %s, %s, %s, NOW())
    """, (
        patient_id,
        procedure.get('name'),
        procedure.get('type'),
        procedure.get('snomed_code'),
        procedure.get('confidence', 0.0)
    ))
