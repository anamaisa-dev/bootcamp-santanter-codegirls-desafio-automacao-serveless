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
