# Automação com Lambda, S3 e DynamoDB - AWS LocalStack

> Automação serverless com AWS Lambda, S3 e DynamoDB para processar arquivos, registrar dados e expor consultas via API, simulando tudo localmente com LocalStack.

***

## Índice

- [Sobre o Projeto](#sobre-o-projeto)
- [Arquitetura da Solução](#arquitetura-da-solução)
- [Tecnologias Utilizadas](#tecnologias-utilizadas)
- [Pré-requisitos](#pré-requisitos)
- [Configuração do Ambiente](#configuração-do-ambiente)
- [Implementação Prática](#implementação-prática)
- [Testes e Validação](#testes-e-validação)
- [Aprendizados e Insights](#aprendizados-e-insights)

***

## Sobre o Projeto

Este projeto implementa uma solução serverless automatizada para processamento de notas fiscais usando AWS Lambda, S3 e DynamoDB. O objetivo é consolidar conhecimentos em:

- Arquitetura event-driven (orientada a eventos)
- Processamento automatizado de arquivos
- Integração entre serviços AWS
- Desenvolvimento local com LocalStack
- API REST com API Gateway

**Caso de Uso Real:** Sistema de processamento automático de notas fiscais que registra dados em banco NoSQL para consulta posterior via API.

***

## Arquitetura da Solução

![Arquitetura](/Imagens/arquitetura.jpg)

### Componentes

| Serviço | Função |
|---------|--------|
| **S3** | Armazena arquivos de notas fiscais (JSON) |
| **Lambda** | Processa arquivos e grava no DynamoDB |
| **DynamoDB** | Banco NoSQL para persistência dos dados |
| **API Gateway** | Expõe endpoints REST para consulta |
| **LocalStack** | Simula ambiente AWS localmente |

***

## Tecnologias Utilizadas

- **AWS Lambda** - Computação serverless
- **Amazon S3** - Armazenamento de objetos
- **Amazon DynamoDB** - Banco de dados NoSQL
- **API Gateway** - Gerenciamento de APIs REST
- **LocalStack** - Emulador AWS local
- **Python 3.9** - Linguagem da função Lambda
- **AWS CLI** - Interface de linha de comando
- **Docker** - Container para LocalStack

***

## Pré-requisitos

Antes de começar, certifique-se de ter instalado:

```bash
# Docker (para rodar LocalStack)
docker --version

# Python 3.9+
python --version

# AWS CLI
aws --version

# LocalStack CLI
localstack --version
```

### Instalação do LocalStack

```bash
# Via pip
pip install localstack

# Ou via Docker
docker pull localstack/localstack
```

***

## Configuração do Ambiente

### 1. Iniciar o LocalStack

```bash
# Via CLI
localstack start

# Ou via Docker
docker run -d --name localstack \
  -p 4566:4566 -p 4571:4571 \
  -e SERVICES=s3,lambda,dynamodb,apigateway \
  -e DEBUG=1 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  localstack/localstack
```

### 2. Configurar AWS CLI para LocalStack

```bash
# Configurar credenciais (valores fictícios)
aws configure
# AWS Access Key ID: test
# AWS Secret Access Key: test
# Default region: us-east-1
# Default output format: json

# Definir variáveis de ambiente (PowerShell)
$env:AWS_ACCESS_KEY_ID="test"
$env:AWS_SECRET_ACCESS_KEY="test"
$env:AWS_DEFAULT_REGION="us-east-1"
```

### 3. Verificar LocalStack

```powershell
Invoke-RestMethod -Uri "http://localhost:4566/_localstack/health"
```

***

## Implementação Prática

### Passo 1: Criar Bucket S3

```bash
aws s3api create-bucket \
  --bucket notas-fiscais-upload \
  --endpoint-url=http://localhost:4566
```

### Passo 2: Criar Tabela DynamoDB

```bash
aws dynamodb create-table \
  --table-name NotasFiscais \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --endpoint-url=http://localhost:4566
```

### Passo 3: Criar Função Lambda

**Arquivo:** `grava_db.py`

```python
import json
import boto3
from datetime import datetime

dynamodb = boto3.resource('dynamodb', endpoint_url='http://localhost:4566')
table = dynamodb.Table('NotasFiscais')

def lambda_handler(event, context):
    try:
        # Extrair dados do evento S3
        for record in event['Records']:
            bucket = record['s3']['bucket']['name']
            key = record['s3']['object']['key']
            
            # Ler arquivo do S3
            s3_client = boto3.client('s3', endpoint_url='http://localhost:4566')
            response = s3_client.get_object(Bucket=bucket, Key=key)
            content = response['Body'].read().decode('utf-8')
            nota = json.loads(content)
            
            # Adicionar timestamp
            nota['timestamp'] = datetime.now().isoformat()
            
            # Gravar no DynamoDB
            table.put_item(Item=nota)
            
        return {
            'statusCode': 200,
            'body': json.dumps('Nota fiscal processada com sucesso!')
        }
    except Exception as e:
        print(f'Erro: {str(e)}')
        return {
            'statusCode': 500,
            'body': json.dumps(f'Erro ao processar: {str(e)}')
        }
```

**Empacotar e criar Lambda:**

```bash
# Criar arquivo zip
zip lambda_function.zip grava_db.py

# Criar função Lambda
aws lambda create-function \
  --function-name ProcessarNotasFiscais \
  --runtime python3.9 \
  --role arn:aws:iam::000000000000:role/lambda-role \
  --handler grava_db.lambda_handler \
  --zip-file fileb://lambda_function.zip \
  --endpoint-url=http://localhost:4566
```

### Passo 4: Configurar Trigger S3 → Lambda

**Arquivo:** `notification_roles.json`

```json
{
  "LambdaFunctionConfigurations": [
    {
      "LambdaFunctionArn": "arn:aws:lambda:us-east-1:000000000000:function:ProcessarNotasFiscais",
      "Events": ["s3:ObjectCreated:*"]
    }
  ]
}
```

```bash
# Conceder permissão
aws lambda add-permission \
  --function-name ProcessarNotasFiscais \
  --statement-id s3-trigger-permission \
  --action "lambda:InvokeFunction" \
  --principal s3.amazonaws.com \
  --source-arn "arn:aws:s3:::notas-fiscais-upload" \
  --endpoint-url=http://localhost:4566

# Configurar notificação
aws s3api put-bucket-notification-configuration \
  --bucket notas-fiscais-upload \
  --notification-configuration file://notification_roles.json \
  --endpoint-url=http://localhost:4566
```

### Passo 5: Criar API Gateway

```bash
# Criar API
aws apigateway create-rest-api \
  --name "NotasFiscaisAPI" \
  --endpoint-url=http://localhost:4566

# Obter ID da API (exemplo: abc123)
# Obter ID do recurso raiz (exemplo: xyz456)

aws apigateway get-resources \
  --rest-api-id abc123 \
  --endpoint-url=http://localhost:4566

# Criar recurso /notas
aws apigateway create-resource \
  --rest-api-id abc123 \
  --parent-id xyz456 \
  --path-part "notas" \
  --endpoint-url=http://localhost:4566

# Configurar método POST
aws apigateway put-method \
  --rest-api-id abc123 \
  --resource-id mno789 \
  --http-method POST \
  --authorization-type "NONE" \
  --endpoint-url=http://localhost:4566

# Integrar com Lambda
aws apigateway put-integration \
  --rest-api-id abc123 \
  --resource-id mno789 \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:000000000000:function:ProcessarNotasFiscais/invocations" \
  --endpoint-url=http://localhost:4566

# Deploy da API
aws apigateway create-deployment \
  --rest-api-id abc123 \
  --stage-name dev \
  --endpoint-url=http://localhost:4566
```

***

## Testes e Validação

### Teste 1: Upload de Arquivo

```bash
# Criar arquivo de teste
echo '{"id": "NF-001", "cliente": "João Silva", "valor": 1500.00, "data_emissao": "2025-11-02"}' > nota_teste.json

# Enviar para S3
aws s3 cp nota_teste.json s3://notas-fiscais-upload/ \
  --endpoint-url=http://localhost:4566
```

### Teste 2: Consultar DynamoDB

```bash
aws dynamodb scan \
  --table-name NotasFiscais \
  --endpoint-url=http://localhost:4566
```

### Teste 3: Testar API Gateway

```powershell
# POST - Criar nota
Invoke-RestMethod -Uri "http://localhost:4566/restapis/abc123/dev/_user_request_/notas" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"id": "NF-999", "cliente": "Maria Santos", "valor": 2000.0, "data_emissao": "2025-11-02"}'

# GET - Listar notas
Invoke-RestMethod -Uri "http://localhost:4566/restapis/abc123/dev/_user_request_/notas" `
  -Method GET
```

***

## Aprendizados e Insights

### Principais Conquistas

1. **Event-Driven Architecture:** Compreendi como eventos do S3 acionam automaticamente funções Lambda
2. **Serverless na Prática:** Implementei processamento sem gerenciar servidores
3. **LocalStack:** Dominei o desenvolvimento local, economizando custos e acelerando testes
4. **Integração Multi-Serviços:** Conectei S3, Lambda, DynamoDB e API Gateway
5. **IAM e Permissões:** Configurei roles e policies para comunicação entre serviços

### Desafios Encontrados

| Desafio | Solução |
|---------|---------|
| Endpoints LocalStack | Sempre usar `--endpoint-url=http://localhost:4566` |
| ARNs fictícios | LocalStack aceita ARN `000000000000` para testes |
| Permissões Lambda | Adicionar `lambda:add-permission` para cada trigger |
| Deploy da API | Necessário `create-deployment` após cada mudança |

### Boas Práticas Aplicadas

- Princípio do menor privilégio em IAM
- Tratamento de erros em Lambda
- Logs estruturados com CloudWatch
- Versionamento de código
- Testes locais antes do deploy

***
