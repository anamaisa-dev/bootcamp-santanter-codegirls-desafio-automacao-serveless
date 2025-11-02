# ============================================================
# ID: SETUP-001
# Nome: Script de Configuração LocalStack
# Descrição: Configura todos os recursos AWS localmente
# Versão: 1.0
# ============================================================

#!/bin/bash

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Iniciando setup do LocalStack${NC}"
echo -e "${BLUE}========================================${NC}"

# SETUP-001: Definir variáveis
echo -e "${GREEN}[1/8] Configurando variáveis de ambiente...${NC}"
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export LOCALSTACK_ENDPOINT=http://localhost:4566

# SETUP-002: Criar bucket S3
echo -e "${GREEN}[2/8] Criando bucket S3...${NC}"
aws s3api create-bucket \
  --bucket notas-fiscais-upload \
  --endpoint-url=$LOCALSTACK_ENDPOINT

# SETUP-003: Criar tabela DynamoDB
echo -e "${GREEN}[3/8] Criando tabela DynamoDB...${NC}"
aws dynamodb create-table \
  --table-name NotasFiscais \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --endpoint-url=$LOCALSTACK_ENDPOINT

# SETUP-004: Criar função Lambda
echo -e "${GREEN}[4/8] Criando função Lambda...${NC}"
cd lambda
zip -r lambda_function.zip lambda_processor.py
cd ..

aws lambda create-function \
  --function-name ProcessarNotasFiscais \
  --runtime python3.9 \
  --role arn:aws:iam::000000000000:role/lambda-role \
  --handler lambda_processor.lambda_handler \
  --zip-file fileb://lambda/lambda_function.zip \
  --endpoint-url=$LOCALSTACK_ENDPOINT

# SETUP-005: Conceder permissão S3 → Lambda
echo -e "${GREEN}[5/8] Configurando permissões...${NC}"
aws lambda add-permission \
  --function-name ProcessarNotasFiscais \
  --statement-id s3-trigger-permission \
  --action "lambda:InvokeFunction
