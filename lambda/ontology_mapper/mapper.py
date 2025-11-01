"""
Ontology Mapper Lambda
Maps extracted entities to standardized ontology codes using DynamoDB
"""
import json
import boto3
import os
from decimal import Decimal

s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
lambda_client = boto3.client('lambda')

DYNAMODB_TABLE = os.environ.get('DYNAMODB_TABLE', 'medextract-pipeline-ontology-dev')
LOADER_FUNCTION = os.environ.get('LOADER_FUNCTION', 'medextract-pipeline-loader')


def lambda_handler(event, context):
    """
    Map entities to ontology codes using DynamoDB lookup
    """
    print(f"Received event: {json.dumps(event)}")
    
    try:
        message_id = event['messageId']
        s3_bucket = event['s3Bucket']
        results = event['results']
        
        table = dynamodb.Table(DYNAMODB_TABLE)
        
        # Enhance entities with additional mappings
        mapped_entities = []
        
        for entity in results.get('entities', []):
            # Try to find mapping in DynamoDB
            mapping = lookup_mapping(table, entity['text'], entity['category'])
            
            mapped_entity = {
                **entity,
                'mapped': mapping is not None
            }
            
            if mapping:
                mapped_entity.update({
                    'icd10_code': mapping.get('icd10_code'),
                    'snomed_code': mapping.get('snomed_code'),
                    'preferred_term': mapping.get('preferred_term')
                })
            
            mapped_entities.append(mapped_entity)
        
        # Create structured output
        structured_data = {
            'messageId': message_id,
            'patient': extract_patient_info(mapped_entities),
            'diagnoses': extract_diagnoses(results, mapped_entities),
            'medications': extract_medications(results),
            'procedures': extract_procedures(mapped_entities),
            'timestamp': context.aws_request_id
        }
        
        # Store structured data
        structured_key = f"structured/{message_id}.json"
        s3_client.put_object(
            Bucket=s3_bucket,
            Key=structured_key,
            Body=json.dumps(structured_data, indent=2, default=decimal_default),
            ContentType='application/json'
        )
        
        print(f"Stored structured data for message {message_id}")
        
        # Invoke Postgres loader
        loader_payload = {
            'messageId': message_id,
            's3Bucket': s3_bucket,
            'structuredKey': structured_key,
            'data': structured_data
        }
        
        lambda_client.invoke(
            FunctionName=LOADER_FUNCTION,
            InvocationType='Event',
            Payload=json.dumps(loader_payload, default=decimal_default)
        )
        
        print(f"Invoked Postgres loader for message {message_id}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Ontology mapping completed',
                'messageId': message_id,
                'mappedCount': sum(1 for e in mapped_entities if e['mapped'])
            })
        }
        
    except Exception as e:
        print(f"Error mapping ontology: {str(e)}")
        raise


def lookup_mapping(table, entity_text, entity_type):
    """Look up entity in DynamoDB ontology table"""
    try:
        response = table.get_item(
            Key={
                'entity_text': entity_text.lower(),
                'entity_type': entity_type
            }
        )
        return response.get('Item')
    except Exception as e:
        print(f"Error looking up mapping: {str(e)}")
        return None


def extract_patient_info(entities):
    """Extract patient demographic information"""
    patient_info = {}
    
    for entity in entities:
        if entity['category'] == 'PROTECTED_HEALTH_INFORMATION':
            if entity['type'] == 'NAME':
                patient_info['name'] = entity['text']
            elif entity['type'] == 'AGE':
                patient_info['age'] = entity['text']
            elif entity['type'] == 'ID':
                patient_info['mrn'] = entity['text']
    
    return patient_info


def extract_diagnoses(results, mapped_entities):
    """Extract and structure diagnoses"""
    diagnoses = []
    
    # From ICD-10 inference
    for icd10 in results.get('icd10', []):
        diagnoses.append({
            'text': icd10['text'],
            'icd10_code': icd10['code'],
            'description': icd10['description'],
            'confidence': float(icd10['score'])
        })
    
    # From SNOMED inference
    snomed_map = {s['text']: s for s in results.get('snomed', [])}
    
    # Combine with mapped entities
    for diagnosis in diagnoses:
        if diagnosis['text'] in snomed_map:
            diagnosis['snomed_code'] = snomed_map[diagnosis['text']]['code']
    
    return diagnoses


def extract_medications(results):
    """Extract medication information"""
    medications = []
    
    for med in results.get('medications', []):
        medications.append({
            'name': med['text'],
            'rxnorm_code': med['code'],
            'description': med['description'],
            'confidence': float(med['score'])
        })
    
    return medications


def extract_procedures(entities):
    """Extract procedure information"""
    procedures = []
    
    for entity in entities:
        if entity['category'] == 'TEST_TREATMENT_PROCEDURE':
            procedures.append({
                'name': entity['text'],
                'type': entity['type'],
                'confidence': float(entity['score']),
                'snomed_code': entity.get('snomed_code')
            })
    
    return procedures


def decimal_default(obj):
    """JSON serializer for Decimal objects"""
    if isinstance(obj, Decimal):
        return float(obj)
    raise TypeError
