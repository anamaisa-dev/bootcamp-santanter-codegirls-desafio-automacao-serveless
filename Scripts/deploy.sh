#!/bin/bash

# Script de Deploy - Automação com Lambda, S3 e DynamoDB
# Este script automatiza toda a configuração do ambiente LocalStack

set -e

echo "=========================================="
echo "🚀 Iniciando Deploy do Projeto"
echo "=========================================="

# Variáveis
BUCKET_NAME="notas-fiscais-upload"
TABLE_NAME="NotasFiscais"
FUNCTION_NAME="ProcessarNotasFiscais"
API_NAME="NotasFiscaisAPI"
ENDPOINT_URL="http://localhost:4566"
REGION="us-east-1"

# 1. Verificar se LocalStack está rodando
echo "✓ Verificando LocalStack..."
if ! curl -s "${ENDPOINT_URL}/_localstack/health" > /dev/null; then
    echo "✗ LocalStack não está rodando!"
    echo "Execute: localstack start"
    exit 1
fi
echo "✓ LocalStack está disponível"

# 2. Criar Bucket S3
echo "✓ Criando bucket S3: $BUCKET_NAME"
aws s3api create-bucket \
  --bucket "$BUCKET_NAME" \
  --endpoint-url="$ENDPOINT_URL" \
  --region "$REGION" 2>/dev/null || echo "  Bucket já existe"

# 3. Criar Tabela DynamoDB
echo "✓ Criando tabela DynamoDB: $TABLE_NAME"
aws dynamodb create-table \
  --table-name "$TABLE_NAME" \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --endpoint-url="$ENDPOINT_URL" \
  --region "$REGION" 2>/dev/null || echo "  Tabela já existe"

# 4. Empacotar e criar Lambda
echo "✓ Preparando função Lambda"
cd lambda
zip -q lambda_function.zip grava_db.py 2>/dev/null || echo "  Arquivo já compactado"

echo "✓ Criando função Lambda: $FUNCTION_NAME"
aws lambda create-function \
  --function-name "$FUNCTION_NAME" \
  --runtime python3.9 \
  --role "arn:aws:iam::000000000000:role/lambda-role" \
  --handler "grava_db.lambda_handler" \
  --zip-file fileb://lambda_function.zip \
  --endpoint-url="$ENDPOINT_URL" \
  --region "$REGION" 2>/dev/null || echo "  Função já existe"

cd ..

# 5. Conceder permissão S3 → Lambda
echo "✓ Configurando permissões S3 → Lambda"
a
