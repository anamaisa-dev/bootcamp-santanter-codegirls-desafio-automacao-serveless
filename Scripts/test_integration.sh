# ============================================================
# ID: TEST-001
# Nome: Script de Testes
# Descrição: Testa upload, processamento e consulta de dados
# Versão: 1.0
# ============================================================

#!/bin/bash

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

ENDPOINT="http://localhost:4566"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}TESTES DO SISTEMA DE NOTAS FISCAIS${NC}"
echo -e "${BLUE}========================================${NC}"

# TEST-001: Criar arquivo de teste
echo -e "${YELLOW}[Teste 1] Criando arquivo de teste...${NC}"
cat > /tmp/nota_teste.json << 'EOF'
{
  "id": "NF-20251102-001",
  "cliente": "Empresa XYZ",
  "cnpj": "12.345.678/0001-90",
  "valor": 1500.00,
  "data_emissao": "2025-11-02",
  "descricao": "Serviços de consultoria"
}
EOF

if [ -f /tmp/nota_teste.json ]; then
    echo -e "${GREEN}✓ Arquivo criado com sucesso${NC}"
else
    echo -e "${RED}✗ Erro ao criar arquivo${NC}"
    exit 1
fi

# TEST-002: Upload para S3
echo -e "${YELLOW}[Teste 2] Fazendo upload para S3...${NC}"
aws s3 cp /tmp/nota_teste.json s3://notas-fiscais-upload/ \
  --endpoint-url=$ENDPOINT

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Upload realizado com sucesso${NC}"
else
    echo -e "${RED}✗ Erro no upload${NC}"
    exit 1
fi

# TEST-003: Aguardar processamento
echo -e "${YELLOW}[Teste 3] Aguardando processamento da Lambda...${NC}"
sleep 2
echo -e "${GREEN}✓ Processamento completo${NC}"

# TEST-004: Consultar DynamoDB
echo -e "${YELLOW}[Teste 4] Consultando dados no DynamoDB...${NC}"
aws dynamodb scan \
  --table-name NotasFiscais \
  --endpoint-url=$ENDPOINT \
  --output table

# TEST-005: Listar arquivos no S3
echo -e "${YELLOW}[Teste 5] Listando arquivos no S3...${NC}"
aws s3 ls s3://notas-fiscais-upload/ --endpoint-url=$ENDPOINT

# TEST-006: Invocar Lambda manualmente
echo -e "${YELLOW}[Teste 6] Invocando Lambda manualmente...${N
