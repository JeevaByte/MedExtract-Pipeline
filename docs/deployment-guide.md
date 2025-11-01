# MedExtract-Pipeline Deployment Guide

## Prerequisites

### Required Tools
- **Terraform** >= 1.0
- **AWS CLI** >= 2.0
- **Python** 3.11+
- **Git**
- **PostgreSQL Client** (for database management)

### AWS Account Setup
1. AWS account with administrative access
2. AWS CLI configured with appropriate credentials
3. Sufficient service quotas for:
   - Lambda functions (5 concurrent)
   - S3 buckets (3)
   - RDS Aurora Serverless instances (1)
   - SES email receiving enabled in your region

### Required AWS Services
Ensure the following services are available in your deployment region:
- Amazon SES
- Amazon S3
- AWS Lambda
- Amazon Comprehend Medical
- Amazon Textract
- Amazon DynamoDB
- Amazon Aurora PostgreSQL
- AWS KMS
- Amazon VPC
- CloudWatch
- CloudTrail

---

## Step 1: Clone Repository

```bash
git clone https://github.com/JeevaByte/MedExtract-Pipeline.git
cd MedExtract-Pipeline
```

---

## Step 2: Configure AWS Credentials

```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Default region: us-east-1 (or your preferred region)
# Default output format: json
```

Verify configuration:
```bash
aws sts get-caller-identity
```

---

## Step 3: Prepare Lambda Deployment Packages

Each Lambda function needs to be packaged with its dependencies:

```bash
# Create deployment packages
cd lambda

# SES Ingest Handler
cd ses_ingest_handler
pip install -r requirements.txt -t .
zip -r ../deployment_ses.zip .
cd ..

# Attachment Parser
cd attachment_parser
pip install -r requirements.txt -t .
zip -r ../deployment_parser.zip .
cd ..

# Comprehend Worker
cd comprehend_worker
pip install -r requirements.txt -t .
zip -r ../deployment_comprehend.zip .
cd ..

# Ontology Mapper
cd ontology_mapper
pip install -r requirements.txt -t .
zip -r ../deployment_mapper.zip .
cd ..

# Postgres Loader
cd loader
pip install -r requirements.txt -t .
zip -r ../deployment_loader.zip .
cd ..

cd ..
```

**Note**: For production, use CI/CD pipeline with proper build process.

---

## Step 4: Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
aws_region        = "us-east-1"
project_name      = "medextract-pipeline"
environment       = "dev"
ses_email_domain  = "yourdomain.com"  # Replace with your domain
db_master_username = "medextract_admin"
db_master_password = "YOUR_SECURE_PASSWORD"  # Use strong password
enable_cloudtrail = true
vpc_cidr          = "10.0.0.0/16"

tags = {
  Project     = "MedExtract-Pipeline"
  ManagedBy   = "Terraform"
  Compliance  = "NHS-DSPT"
  Environment = "dev"
}
```

**Security Note**: Store sensitive values in AWS Secrets Manager or use Terraform Cloud for remote state with encryption.

---

## Step 5: Initialize Terraform

```bash
terraform init
```

This will:
- Download required providers (AWS)
- Initialize backend configuration
- Prepare modules

---

## Step 6: Plan Infrastructure

```bash
terraform plan -out=tfplan
```

Review the plan carefully. Expected resources:
- 1 VPC with 2 subnets
- 2 Security Groups
- 3 S3 Buckets (emails, cloudtrail, artifacts)
- 1 KMS Key
- 1 DynamoDB Table
- 1 Aurora PostgreSQL Cluster
- 5 Lambda Functions
- 1 SES Receipt Rule Set
- IAM Roles and Policies
- CloudWatch Log Groups
- CloudTrail (if enabled)

---

## Step 7: Deploy Infrastructure

```bash
terraform apply tfplan
```

Deployment takes approximately 10-15 minutes. Monitor progress in the terminal.

**Important**: Save the outputs shown at the end - you'll need them for configuration.

---

## Step 8: Configure SES Domain

### Verify Domain
1. Get verification token from Terraform output
2. Add TXT record to your DNS:
   ```
   Name: _amazonses.yourdomain.com
   Type: TXT
   Value: [verification-token-from-output]
   ```

### Configure DKIM
Add DKIM CNAME records (3 records from Terraform output):
```
Name: [dkim-token-1]._domainkey.yourdomain.com
Type: CNAME
Value: [dkim-token-1].dkim.amazonses.com
```

### Configure MX Record
```
Name: yourdomain.com
Type: MX
Priority: 10
Value: inbound-smtp.[region].amazonaws.com
```

Verify setup:
```bash
aws ses get-identity-verification-attributes --identities yourdomain.com
```

---

## Step 9: Initialize Database Schema

Get database endpoint from Terraform output:
```bash
terraform output rds_cluster_endpoint
```

Connect to database:
```bash
psql -h [endpoint] -U medextract_admin -d medextract
```

Run schema script:
```bash
psql -h [endpoint] -U medextract_admin -d medextract -f ../sql/schema.sql
```

Optionally load seed data:
```bash
psql -h [endpoint] -U medextract_admin -d medextract -f ../sql/seed_data.sql
```

---

## Step 10: Load Ontology Mapping Data

Upload SNOMED/ICD-10 mapping to DynamoDB:

```python
import boto3
import csv

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('medextract-pipeline-ontology-dev')

with open('../mapping/snomed_icd10_map.csv', 'r') as f:
    reader = csv.DictReader(f)
    for row in reader:
        table.put_item(Item=row)

print("Ontology mapping loaded successfully")
```

Or use AWS CLI:
```bash
aws dynamodb batch-write-item --request-items file://mapping_batch.json
```

---

## Step 11: Configure Lambda Environment Variables

Update Lambda functions with correct environment variables:

```bash
# Update parser Lambda
aws lambda update-function-configuration \
  --function-name medextract-pipeline-parser \
  --environment Variables={COMPREHEND_FUNCTION=medextract-pipeline-comprehend}

# Update comprehend Lambda
aws lambda update-function-configuration \
  --function-name medextract-pipeline-comprehend \
  --environment Variables={MAPPER_FUNCTION=medextract-pipeline-mapper}

# Update mapper Lambda
aws lambda update-function-configuration \
  --function-name medextract-pipeline-mapper \
  --environment Variables={LOADER_FUNCTION=medextract-pipeline-loader,DYNAMODB_TABLE=medextract-pipeline-ontology-dev}

# Update loader Lambda with DB credentials
aws lambda update-function-configuration \
  --function-name medextract-pipeline-loader \
  --environment Variables={DB_ENDPOINT=[rds-endpoint],DB_NAME=medextract,DB_USER=medextract_admin,DB_PASSWORD=[password]}
```

**Security Best Practice**: Use AWS Secrets Manager for database credentials.

---

## Step 12: Test the Pipeline

Send a test email to your configured SES address:
```
referrals@yourdomain.com
```

Use the sample referral from `samples/sample_referral.eml`.

Monitor execution:
```bash
# Watch CloudWatch Logs
aws logs tail /aws/lambda/medextract-pipeline-ses-ingest --follow

# Check S3 for processed files
aws s3 ls s3://medextract-pipeline-emails-dev/incoming/
aws s3 ls s3://medextract-pipeline-emails-dev/extracted/
aws s3 ls s3://medextract-pipeline-emails-dev/structured/

# Verify database records
psql -h [endpoint] -U medextract_admin -d medextract -c "SELECT * FROM referrals ORDER BY created_at DESC LIMIT 5;"
```

---

## Step 13: Enable Monitoring

### CloudWatch Dashboard
Create custom dashboard:
```bash
aws cloudwatch put-dashboard --dashboard-name MedExtract-Pipeline --dashboard-body file://cloudwatch-dashboard.json
```

### Alarms
Set up alarms for:
- Lambda errors
- Database connection failures
- SES delivery issues
- High processing latency

Example alarm:
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name medextract-lambda-errors \
  --alarm-description "Alert on Lambda execution errors" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --threshold 5 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1
```

---

## Step 14: Security Hardening

### Enable S3 Block Public Access
```bash
aws s3api put-public-access-block \
  --bucket medextract-pipeline-emails-dev \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### Rotate KMS Keys
Set up automatic key rotation:
```bash
aws kms enable-key-rotation --key-id [kms-key-id]
```

### Review IAM Policies
Ensure least-privilege access for all roles.

### Enable VPC Flow Logs
```bash
aws ec2 create-flow-logs \
  --resource-type VPC \
  --resource-ids [vpc-id] \
  --traffic-type ALL \
  --log-destination-type cloud-watch-logs \
  --log-group-name /aws/vpc/medextract-pipeline
```

---

## Troubleshooting

### Lambda Function Fails
- Check CloudWatch Logs
- Verify IAM permissions
- Ensure VPC configuration is correct
- Check Lambda timeout and memory settings

### Database Connection Issues
- Verify security group rules
- Check subnet configuration
- Ensure Lambda is in correct VPC
- Verify database credentials

### SES Not Receiving Emails
- Verify MX records
- Check SES receipt rules
- Ensure domain is verified
- Review SES service limits

### Comprehend Medical Errors
- Check service availability in your region
- Verify IAM permissions for Comprehend Medical
- Ensure text length is within limits (20KB)

---

## Cleanup

To destroy all resources:

```bash
# Remove all S3 objects first
aws s3 rm s3://medextract-pipeline-emails-dev --recursive
aws s3 rm s3://medextract-pipeline-cloudtrail-dev --recursive

# Destroy infrastructure
terraform destroy

# Confirm deletion
```

**Warning**: This will permanently delete all data.

---

## Production Considerations

### High Availability
- Deploy across multiple Availability Zones
- Use Aurora Global Database for disaster recovery
- Implement multi-region SES configuration

### Scalability
- Adjust Lambda reserved concurrency
- Configure DynamoDB auto-scaling
- Optimize Aurora capacity settings
- Implement SQS for Lambda decoupling

### Compliance
- Enable S3 Object Lock for compliance retention
- Implement data lifecycle policies
- Regular security audits
- HIPAA compliance review (if applicable)

### Cost Optimization
- Use S3 Intelligent-Tiering
- Implement Aurora Serverless v2 auto-pause
- Optimize Lambda memory settings
- Review CloudWatch Logs retention

---

## Support

For issues or questions:
- Open GitHub issue: https://github.com/JeevaByte/MedExtract-Pipeline/issues
- Review documentation: `/docs/`
- Check CloudWatch Logs for detailed error messages

---

## Next Steps

- Set up CI/CD pipeline
- Integrate with FHIR servers
- Add Amazon Bedrock for LLM summarization
- Implement web UI for clinician review
- Deploy to production environment
