"""
SES Ingest Handler Lambda
Processes incoming emails from SES and stores them in S3
"""
import json
import boto3
import os
from datetime import datetime

s3_client = boto3.client('s3')
lambda_client = boto3.client('lambda')

S3_BUCKET = os.environ.get('S3_BUCKET')
PARSER_FUNCTION = os.environ.get('PARSER_FUNCTION', 'medextract-pipeline-parser')


def lambda_handler(event, context):
    """
    Process SES email receipt event
    """
    print(f"Received event: {json.dumps(event)}")
    
    try:
        # Extract SES message
        ses_notification = event['Records'][0]['ses']
        message_id = ses_notification['mail']['messageId']
        receipt = ses_notification['receipt']
        
        # Email metadata
        metadata = {
            'messageId': message_id,
            'timestamp': ses_notification['mail']['timestamp'],
            'source': ses_notification['mail']['source'],
            'destination': ses_notification['mail']['destination'],
            'subject': ses_notification['mail']['commonHeaders'].get('subject', ''),
            'recipients': receipt.get('recipients', []),
            'spamVerdict': receipt.get('spamVerdict', {}),
            'virusVerdict': receipt.get('virusVerdict', {}),
            'dkimVerdict': receipt.get('dkimVerdict', {}),
            'spfVerdict': receipt.get('spfVerdict', {})
        }
        
        # Store metadata
        metadata_key = f"metadata/{message_id}.json"
        s3_client.put_object(
            Bucket=S3_BUCKET,
            Key=metadata_key,
            Body=json.dumps(metadata, indent=2),
            ContentType='application/json'
        )
        
        print(f"Stored metadata for message {message_id}")
        
        # Invoke parser Lambda asynchronously
        parser_payload = {
            'messageId': message_id,
            's3Bucket': S3_BUCKET,
            's3Key': f"incoming/{message_id}"
        }
        
        lambda_client.invoke(
            FunctionName=PARSER_FUNCTION,
            InvocationType='Event',
            Payload=json.dumps(parser_payload)
        )
        
        print(f"Invoked parser for message {message_id}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Email processed successfully',
                'messageId': message_id
            })
        }
        
    except Exception as e:
        print(f"Error processing email: {str(e)}")
        raise
