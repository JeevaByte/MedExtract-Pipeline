"""
Comprehend Medical Worker Lambda
Extracts medical entities using Amazon Comprehend Medical
"""
import json
import boto3
import os

s3_client = boto3.client('s3')
comprehend_medical = boto3.client('comprehendmedical')
lambda_client = boto3.client('lambda')

MAPPER_FUNCTION = os.environ.get('MAPPER_FUNCTION', 'medextract-pipeline-mapper')


def lambda_handler(event, context):
    """
    Process text with Amazon Comprehend Medical
    """
    print(f"Received event: {json.dumps(event)}")
    
    try:
        message_id = event['messageId']
        s3_bucket = event['s3Bucket']
        text_key = event.get('textKey')
        
        # Get text from S3 if not in payload
        if 'text' in event:
            text = event['text']
        else:
            response = s3_client.get_object(Bucket=s3_bucket, Key=text_key)
            text = response['Body'].read().decode('utf-8')
        
        # Limit text size for Comprehend Medical (20KB limit)
        text = text[:20000]
        
        # Detect medical entities
        entities_response = comprehend_medical.detect_entities_v2(Text=text)
        
        # Infer ICD-10-CM codes
        icd10_response = comprehend_medical.infer_icd10_cm(Text=text)
        
        # Infer SNOMED CT codes
        snomed_response = comprehend_medical.infer_snomed_ct(Text=text)
        
        # Infer RxNorm codes for medications
        rxnorm_response = comprehend_medical.infer_rx_norm(Text=text)
        
        # Process and structure results
        results = {
            'messageId': message_id,
            'entities': process_entities(entities_response),
            'icd10': process_icd10(icd10_response),
            'snomed': process_snomed(snomed_response),
            'medications': process_rxnorm(rxnorm_response)
        }
        
        # Store results
        results_key = f"comprehend/{message_id}.json"
        s3_client.put_object(
            Bucket=s3_bucket,
            Key=results_key,
            Body=json.dumps(results, indent=2),
            ContentType='application/json'
        )
        
        print(f"Stored Comprehend Medical results for message {message_id}")
        
        # Invoke ontology mapper
        mapper_payload = {
            'messageId': message_id,
            's3Bucket': s3_bucket,
            'resultsKey': results_key,
            'results': results
        }
        
        lambda_client.invoke(
            FunctionName=MAPPER_FUNCTION,
            InvocationType='Event',
            Payload=json.dumps(mapper_payload)
        )
        
        print(f"Invoked ontology mapper for message {message_id}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Comprehend Medical processing completed',
                'messageId': message_id,
                'entityCount': len(results['entities']),
                'icd10Count': len(results['icd10']),
                'snomedCount': len(results['snomed'])
            })
        }
        
    except Exception as e:
        print(f"Error processing with Comprehend Medical: {str(e)}")
        raise


def process_entities(response):
    """Process detected entities"""
    entities = []
    
    for entity in response.get('Entities', []):
        entities.append({
            'text': entity['Text'],
            'category': entity['Category'],
            'type': entity['Type'],
            'score': entity['Score'],
            'beginOffset': entity['BeginOffset'],
            'endOffset': entity['EndOffset'],
            'attributes': [
                {
                    'type': attr['Type'],
                    'score': attr['Score'],
                    'relationshipScore': attr.get('RelationshipScore', 0),
                    'text': attr.get('Text', '')
                }
                for attr in entity.get('Attributes', [])
            ]
        })
    
    return entities


def process_icd10(response):
    """Process ICD-10-CM codes"""
    icd10_codes = []
    
    for entity in response.get('Entities', []):
        for concept in entity.get('ICD10CMConcepts', []):
            icd10_codes.append({
                'text': entity['Text'],
                'code': concept['Code'],
                'description': concept['Description'],
                'score': concept['Score']
            })
    
    return icd10_codes


def process_snomed(response):
    """Process SNOMED CT codes"""
    snomed_codes = []
    
    for entity in response.get('Entities', []):
        for concept in entity.get('SNOMEDCTConcepts', []):
            snomed_codes.append({
                'text': entity['Text'],
                'code': concept['Code'],
                'description': concept['Description'],
                'score': concept['Score']
            })
    
    return snomed_codes


def process_rxnorm(response):
    """Process RxNorm medication codes"""
    medications = []
    
    for entity in response.get('Entities', []):
        for concept in entity.get('RxNormConcepts', []):
            medications.append({
                'text': entity['Text'],
                'code': concept['Code'],
                'description': concept['Description'],
                'score': concept['Score']
            })
    
    return medications
