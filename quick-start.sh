#!/bin/bash
# Quick Start Script for MindWell Clinic with gpt-oss:20b

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  MindWell Clinic - Quick Start${NC}"
echo -e "${BLUE}  Model: gpt-oss:20b${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Start services
echo -e "${BLUE}[1/4]${NC} Starting backend services..."
cd backend
docker compose --profile llm up -d
cd ..

# Step 2: Wait for services
echo -e "${BLUE}[2/4]${NC} Waiting for services to be ready..."
sleep 10

# Check backend health
echo -n "Checking backend health..."
for i in {1..30}; do
    if curl -sf http://localhost:8000/health > /dev/null 2>&1; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    sleep 2
    echo -n "."
done

# Check Ollama
echo -n "Checking Ollama service..."
for i in {1..30}; do
    if curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo -e " ${GREEN}✓${NC}"
        break
    fi
    sleep 2
    echo -n "."
done

# Step 3: Pull Ollama model
echo -e "${BLUE}[3/4]${NC} Pulling Ollama model (gpt-oss:20b)..."
echo -e "${YELLOW}Note: This may take several minutes depending on your connection${NC}"

# Try to pull the model
if docker exec backend-ollama-1 ollama pull gpt-oss:20b 2>/dev/null || \
   docker exec backend_ollama_1 ollama pull gpt-oss:20b 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Model gpt-oss:20b ready"
else
    echo -e "${YELLOW}Warning: Could not pull model automatically${NC}"
    echo "Please run manually:"
    echo "  docker exec -it \$(docker ps -q -f name=ollama) ollama pull gpt-oss:20b"
fi

# Step 4: Verify
echo -e "${BLUE}[4/4]${NC} Running verification tests..."
if [ -f "backend/tests/verify_companion_ollama.sh" ]; then
    bash backend/tests/verify_companion_ollama.sh
else
    echo -e "${YELLOW}Skipping verification (script not found)${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Quick Start Complete! 🚀${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Services running:"
echo -e "  ${GREEN}✓${NC} Backend API:  http://localhost:8000"
echo -e "  ${GREEN}✓${NC} API Docs:     http://localhost:8000/docs"
echo -e "  ${GREEN}✓${NC} Ollama:       http://localhost:11434"
echo -e "  ${GREEN}✓${NC} Frontend:     http://localhost:8080"
echo -e "  ${GREEN}✓${NC} PostgreSQL:   localhost:5432"
echo -e "  ${GREEN}✓${NC} MongoDB:      localhost:27017"
echo ""
echo "Next steps:"
echo "  1. Test companion chat:"
echo "     curl -X POST http://localhost:8000/api/v1/companions/chat \\"
echo "       -H 'Content-Type: application/json' \\"
echo "       -d '{\"session_id\":\"test\",\"user_id\":\"user1\",\"message\":\"Hello\",\"stream\":false}'"
echo ""
echo "  2. Access frontend: http://localhost:8080"
echo ""
echo "  3. View logs: cd backend && docker compose logs -f"
echo ""
echo "  4. Stop services: cd backend && docker compose down"
echo ""
