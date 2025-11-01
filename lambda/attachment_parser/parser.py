"""
Attachment Parser Lambda
Extracts text from email attachments using Amazon Textract
"""
import json
import boto3
import os
import email
from email import policy
import io

s3_client = boto3.client('s3')
textract_client = boto3.client('textract')
lambda_client = boto3.client('lambda')

COMPREHEND_FUNCTION = os.environ.get('COMPREHEND_FUNCTION', 'medextract-pipeline-comprehend')


def lambda_handler(event, context):
    """
    Parse email and extract text from attachments
    """
    print(f"Received event: {json.dumps(event)}")
    
    try:
        message_id = event['messageId']
        s3_bucket = event['s3Bucket']
        s3_key = event['s3Key']
        
        # Download email from S3
        response = s3_client.get_object(Bucket=s3_bucket, Key=s3_key)
        email_content = response['Body'].read()
        
        # Parse email
        msg = email.message_from_bytes(email_content, policy=policy.default)
        
        # Extract email body
        email_body = extract_email_body(msg)
        
        # Extract attachments
        attachments = extract_attachments(msg, s3_bucket, message_id)
        
        # Process attachments with Textract
        extracted_texts = []
        
        for attachment in attachments:
            if attachment['content_type'] in ['application/pdf', 'image/png', 'image/jpeg']:
                text = process_with_textract(s3_bucket, attachment['s3_key'])
                extracted_texts.append({
                    'filename': attachment['filename'],
                    'text': text
                })
        
        # Combine all text
        combined_text = f"Email Body:\n{email_body}\n\n"
        for item in extracted_texts:
            combined_text += f"\nAttachment: {item['filename']}\n{item['text']}\n"
        
        # Store extracted text
        text_key = f"extracted/{message_id}.txt"
        s3_client.put_object(
            Bucket=s3_bucket,
            Key=text_key,
            Body=combined_text.encode('utf-8'),
            ContentType='text/plain'
        )
        
        print(f"Stored extracted text for message {message_id}")
        
        # Invoke Comprehend Medical worker
        comprehend_payload = {
            'messageId': message_id,
            's3Bucket': s3_bucket,
            'textKey': text_key,
            'text': combined_text[:10000]  # Limit size for Lambda payload
        }
        
        lambda_client.invoke(
            FunctionName=COMPREHEND_FUNCTION,
            InvocationType='Event',
            Payload=json.dumps(comprehend_payload)
        )
        
        print(f"Invoked Comprehend worker for message {message_id}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Parsing completed successfully',
                'messageId': message_id,
                'attachmentCount': len(attachments),
                'textLength': len(combined_text)
            })
        }
        
    except Exception as e:
        print(f"Error parsing email: {str(e)}")
        raise


def extract_email_body(msg):
    """Extract plain text body from email"""
    body = ""
    
    if msg.is_multipart():
        for part in msg.walk():
            if part.get_content_type() == "text/plain":
                body += part.get_payload(decode=True).decode('utf-8', errors='ignore')
    else:
        body = msg.get_payload(decode=True).decode('utf-8', errors='ignore')
    
    return body


def extract_attachments(msg, s3_bucket, message_id):
    """Extract and store attachments"""
    attachments = []
    
    for part in msg.walk():
        if part.get_content_maintype() == 'multipart':
            continue
        if part.get('Content-Disposition') is None:
            continue
        
        filename = part.get_filename()
        if filename:
            content = part.get_payload(decode=True)
            content_type = part.get_content_type()
            
            # Store attachment in S3
            s3_key = f"attachments/{message_id}/{filename}"
            s3_client.put_object(
                Bucket=s3_bucket,
                Key=s3_key,
                Body=content,
                ContentType=content_type
            )
            
            attachments.append({
                'filename': filename,
                'content_type': content_type,
                's3_key': s3_key,
                'size': len(content)
            })
            
            print(f"Stored attachment: {filename}")
    
    return attachments


def process_with_textract(bucket, key):
    """Process document with Amazon Textract"""
    try:
        response = textract_client.detect_document_text(
            Document={
                'S3Object': {
                    'Bucket': bucket,
                    'Name': key
                }
            }
        )
        
        # Extract text from Textract response
        text_lines = []
        for block in response.get('Blocks', []):
            if block['BlockType'] == 'LINE':
                text_lines.append(block['Text'])
        
        return '\n'.join(text_lines)
        
    except Exception as e:
        print(f"Error processing with Textract: {str(e)}")
        return ""
