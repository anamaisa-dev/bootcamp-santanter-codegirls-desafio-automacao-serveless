# ============================================================
# ID: LAMBDA-001
# Nome: Processador de Notas Fiscais
# Descrição: Função Lambda que processa arquivos JSON do S3
#            e grava dados no DynamoDB
# Versão: 1.0
# Autor: Santander Code Girls
# Data: Novembro 2025
# ============================================================

import json
import boto3
import logging
from datetime import datetime
from botocore.exceptions import ClientError

# Configurar logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Inicializar clientes AWS
s3_client = boto3.client('s3', endpoint_url='http://localhost:4566')
dynamodb = boto3.resource('dynamodb', endpoint_url='http://localhost:4566')
table = dynamodb.Table('NotasFiscais')

def lambda_handler(event, context):
    """
    Handler principal da função Lambda.
    
    Processa eventos do S3, lê arquivos JSON e grava no DynamoDB.
    
    Args:
        event (dict): Evento disparado pelo S3
        context (object): Contexto da execução Lambda
    
    Returns:
        dict: Resposta com statusCode e mensagem
    """
    
    try:
        logger.info(f"Evento recebido: {json.dumps(event)}")
        
        # PROC-001: Extrair informações do evento S3
        for record in event.get('Records', []):
            bucket = record['s3']['bucket']['name']
            key = record['s3']['object']['key']
            
            logger.info(f"Processando arquivo: s3://{bucket}/{key}")
            
            # PROC-002: Ler arquivo do S3
            try:
                response = s3_client.get_object(Bucket=bucket, Key=key)
                content = response['Body'].read().decode('utf-8')
                nota_fiscal = json.loads(content)
                
            except json.JSONDecodeError as e:
                logger.error(f"Erro ao decodificar JSON: {str(e)}")
                return {
                    'statusCode': 400,
                    'body': json.dumps(f'Arquivo JSON inválido: {str(e)}')
   
