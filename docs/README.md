# Architecture Diagram

This directory contains architecture diagrams for the MedExtract-Pipeline system.

## Files

- `mermaid-architecture.mmd` - Mermaid diagram source code showing the complete system architecture
- `architecture-diagram.png` - Visual representation of the architecture (to be generated)

## Generating PNG from Mermaid

To generate a PNG image from the Mermaid diagram:

### Option 1: Using Mermaid CLI
```bash
npm install -g @mermaid-js/mermaid-cli
mmdc -i mermaid-architecture.mmd -o architecture-diagram.png -t dark -b transparent
```

### Option 2: Using Online Editor
1. Visit https://mermaid.live/
2. Copy the contents of `mermaid-architecture.mmd`
3. Paste into the editor
4. Download as PNG

### Option 3: Using VS Code Extension
1. Install "Markdown Preview Mermaid Support" extension
2. Open `mermaid-architecture.mmd`
3. Right-click and select "Export Diagram"

## Architecture Overview

The diagram shows:

1. **Ingestion Layer** - Email receiving via Amazon SES with TLS encryption
2. **Processing Layer** - Lambda functions for parsing, NLP analysis, and data extraction
3. **Mapping Layer** - Ontology mapping using DynamoDB for ICD-10 and SNOMED CT codes
4. **Data Layer** - Aurora PostgreSQL for structured clinical data storage
5. **Analytics Layer** - QuickSight and Amazon Q for visualization and insights
6. **Security & Compliance** - KMS encryption, CloudTrail auditing, VPC isolation

## Key Components

- Amazon SES - Email receiving with TLS enforcement
- S3 - Encrypted storage with SSE-KMS
- Lambda - Serverless compute for processing pipeline
- Textract - Document text extraction
- Comprehend Medical - Medical NLP and entity recognition
- DynamoDB - Fast ontology code lookup
- Aurora PostgreSQL - Relational database for structured data
- KMS - Encryption key management
- CloudTrail - Audit logging
- VPC - Network isolation

## Data Flow

1. Referral email arrives via SES
2. Email stored in S3 (encrypted)
3. SES triggers Lambda ingest handler
4. Parser Lambda extracts text from attachments using Textract
5. Comprehend Medical Lambda analyzes text and extracts entities
6. Ontology mapper Lambda maps entities to standard codes
7. Postgres loader Lambda inserts data into database
8. Analytics tools query database for insights

## Security Features

- TLS enforced on all inbound emails
- S3 encryption with customer-managed KMS keys
- VPC isolation for Lambda and RDS
- IAM least-privilege access
- CloudTrail audit logging
- CloudWatch monitoring and alerting
