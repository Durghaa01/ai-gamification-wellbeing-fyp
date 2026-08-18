#!/bin/bash
# MindWell Clinic - End-to-End Deployment Script
# Deploys backend, frontend, and Ollama for companion module

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
DEPLOYMENT_MODE="${DEPLOYMENT_MODE:-local}"  # local, docker, production
OLLAMA_MODEL="${OLLAMA_MODEL:-gpt-oss:20b}"
ENABLE_MONGO="${ENABLE_MONGO:-false}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  MindWell Clinic - Deployment${NC}"
echo -e "${BLUE}  Mode: ${DEPLOYMENT_MODE}${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to check command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for service
wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=30
    local attempt=1
    
    echo -n "Waiting for ${service_name}..."
    while [ $attempt -le $max_attempts ]; do
        if curl -sf "$url" > /dev/null 2>&1; then
            echo -e " ${GREEN}✓${NC}"
            return 0
        fi
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    echo -e " ${RED}✗${NC}"
    return 1
}

# ========================================
# Step 1: Pre-deployment Checks
# ========================================
echo -e "${BLUE}[1/7]${NC} Running pre-deployment checks..."

if [ "$DEPLOYMENT_MODE" = "docker" ]; then
    if ! command_exists docker; then
        echo -e "${RED}Error: Docker is not installed${NC}"
        exit 1
    fi
    if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
        echo -e "${RED}Error: Docker Compose is not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} Docker and Docker Compose are available"
fi

if [ "$DEPLOYMENT_MODE" = "local" ]; then
    if ! command_exists flutter; then
        echo -e "${YELLOW}Warning: Flutter not found. Frontend won't be built.${NC}"
    fi
    if ! command_exists python3; then
        echo -e "${RED}Error: Python 3 is required${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓${NC} Local development tools available"
fi

echo ""

# ========================================
# Step 2: Backend Deployment
# ========================================
echo -e "${BLUE}[2/7]${NC} Deploying backend services..."

cd backend

if [ "$DEPLOYMENT_MODE" = "docker" ]; then
    echo "Starting backend services with Docker Compose..."
    
    # Start core services (db, mongo, api)
    if docker compose version >/dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
    else
        COMPOSE_CMD="docker-compose"
    fi
    
    $COMPOSE_CMD up -d db mongo api
    
    echo -e "${GREEN}✓${NC} Backend services starting"
    
elif [ "$DEPLOYMENT_MODE" = "local" ]; then
    echo "Setting up local Python environment..."
    
    # Create virtual environment if doesn't exist
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi
    
    # Activate and install dependencies
    source venv/bin/activate
    pip install -q -r requirements.txt
    
    # Start PostgreSQL via Docker (required)
    if docker compose version >/dev/null 2>&1; then
        docker compose up -d db mongo
    else
        docker-compose up -d db mongo
    fi
    
    echo -e "${GREEN}✓${NC} Database services started"
    
    # Run migrations
    sleep 5  # Wait for DB
    alembic upgrade head
    
    echo -e "${GREEN}✓${NC} Database migrations applied"
fi

cd ..
echo ""

# ========================================
# Step 3: Wait for Backend Health
# ========================================
echo -e "${BLUE}[3/7]${NC} Checking backend health..."

if [ "$DEPLOYMENT_MODE" = "docker" ]; then
    if wait_for_service "http://localhost:8000/health" "Backend API"; then
        echo -e "${GREEN}✓${NC} Backend is healthy"
    else
        echo -e "${RED}Error: Backend failed to start${NC}"
        cd backend && docker compose logs api
        exit 1
    fi
elif [ "$DEPLOYMENT_MODE" = "local" ]; then
    # Start backend in background
    cd backend
    source venv/bin/activate
    nohup uvicorn app.main:app --host 0.0.0.0 --port 8000 > ../backend.log 2>&1 &
    BACKEND_PID=$!
    echo $BACKEND_PID > ../backend.pid
    cd ..
    
    if wait_for_service "http://localhost:8000/health" "Backend API"; then
        echo -e "${GREEN}✓${NC} Backend started (PID: $BACKEND_PID)"
    else
        echo -e "${RED}Error: Backend failed to start${NC}"
        tail -n 50 backend.log
        exit 1
    fi
fi

echo ""

# ========================================
# Step 4: Ollama Deployment
# ========================================
echo -e "${BLUE}[4/7]${NC} Deploying Ollama (AI service)..."

if [ "$DEPLOYMENT_MODE" = "docker" ]; then
    cd backend
    
    # Start Ollama with profile
    if docker compose version >/dev/null 2>&1; then
        docker compose --profile llm up -d ollama
    else
        docker-compose --profile llm up -d ollama
    fi
    
    cd ..
    
    if wait_for_service "http://localhost:11434/api/tags" "Ollama"; then
        echo -e "${GREEN}✓${NC} Ollama is running"
        
        # Pull model
        echo "Pulling Ollama model: ${OLLAMA_MODEL}..."
        if docker exec backend-ollama-1 ollama pull ${OLLAMA_MODEL} 2>/dev/null || \
           docker exec backend_ollama_1 ollama pull ${OLLAMA_MODEL} 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Model ${OLLAMA_MODEL} ready"
        else
            echo -e "${YELLOW}Warning: Could not pull model. You may need to pull manually.${NC}"
            echo "  Run: docker exec -it <ollama-container> ollama pull ${OLLAMA_MODEL}"
        fi
    else
        echo -e "${YELLOW}Warning: Ollama not available. AI features will not work.${NC}"
    fi
    
elif [ "$DEPLOYMENT_MODE" = "local" ]; then
    # Check if Ollama is already running
    if curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Ollama is already running"
        
        # Check if model exists
        if curl -s http://localhost:11434/api/tags | grep -q "${OLLAMA_MODEL}"; then
            echo -e "${GREEN}✓${NC} Model ${OLLAMA_MODEL} is available"
        else
            echo "Pulling model ${OLLAMA_MODEL}..."
            ollama pull ${OLLAMA_MODEL} || echo -e "${YELLOW}Warning: Could not pull model${NC}"
        fi
    else
        echo -e "${YELLOW}Warning: Ollama not running. Please start it manually:${NC}"
        echo "  macOS: Start Ollama app or run 'ollama serve'"
        echo "  Linux: Run 'ollama serve' in another terminal"
        echo "  Then: ollama pull gpt-oss:20b"
    fi
fi

echo ""

# ========================================
# Step 5: Frontend Deployment
# ========================================
echo -e "${BLUE}[5/7]${NC} Deploying frontend..."

if [ "$DEPLOYMENT_MODE" = "docker" ]; then
    cd backend
    
    if docker compose version >/dev/null 2>&1; then
        docker compose up -d frontend
    else
        docker-compose up -d frontend
    fi
    
    cd ..
    
    if wait_for_service "http://localhost:8080" "Frontend"; then
        echo -e "${GREEN}✓${NC} Frontend deployed"
    else
        echo -e "${YELLOW}Warning: Frontend build may take a few minutes${NC}"
    fi
    
elif [ "$DEPLOYMENT_MODE" = "local" ]; then
    if command_exists flutter; then
        echo "Building Flutter web app..."
        flutter build web --release \
            --dart-define=USE_REMOTE_BACKEND=true \
            --dart-define=JOURNAL_API_BASE=http://localhost:8000
        
        echo -e "${GREEN}✓${NC} Frontend built (build/web/)"
        echo "  Serve with: flutter run -d chrome --dart-define=USE_REMOTE_BACKEND=true"
    else
        echo -e "${YELLOW}Skipping frontend build (Flutter not installed)${NC}"
    fi
fi

echo ""

# ========================================
# Step 6: Verification
# ========================================
echo -e "${BLUE}[6/7]${NC} Running integration tests..."

if [ -f "backend/tests/verify_companion_ollama.sh" ]; then
    chmod +x backend/tests/verify_companion_ollama.sh
    
    # Run verification
    if bash backend/tests/verify_companion_ollama.sh; then
        echo -e "${GREEN}✓${NC} Integration tests passed"
    else
        echo -e "${YELLOW}Warning: Some integration tests failed${NC}"
    fi
else
    echo -e "${YELLOW}Skipping tests (verify_companion_ollama.sh not found)${NC}"
fi

echo ""

# ========================================
# Step 7: Summary
# ========================================
echo -e "${BLUE}[7/7]${NC} Deployment Summary"
echo -e "${BLUE}========================================${NC}"
echo ""

echo -e "${GREEN}✓${NC} Backend API:    http://localhost:8000"
echo -e "  - Health:       http://localhost:8000/health"
echo -e "  - API Docs:     http://localhost:8000/docs"
echo -e "  - Companions:   http://localhost:8000/api/v1/companions/"
echo ""

if curl -sf http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Ollama Service: http://localhost:11434"
    echo -e "  - Model:        ${OLLAMA_MODEL}"
else
    echo -e "${YELLOW}!${NC} Ollama Service: Not running"
fi
echo ""

if [ "$DEPLOYMENT_MODE" = "docker" ]; then
    echo -e "${GREEN}✓${NC} Frontend:       http://localhost:8080"
    echo ""
fi

echo -e "${GREEN}✓${NC} PostgreSQL:     localhost:5432"
echo -e "${GREEN}✓${NC} MongoDB:        localhost:27017 (enabled: ${ENABLE_MONGO})"
echo ""

# Create .env.deployed marker
cat > .env.deployed <<EOF
DEPLOYED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DEPLOYMENT_MODE=${DEPLOYMENT_MODE}
OLLAMA_MODEL=${OLLAMA_MODEL}
BACKEND_URL=http://localhost:8000
FRONTEND_URL=http://localhost:8080
OLLAMA_URL=http://localhost:11434
EOF

echo -e "${BLUE}Next Steps:${NC}"
echo ""
echo "1. Test the companion chat:"
echo "   curl -X POST http://localhost:8000/api/v1/companions/chat \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"session_id\":\"test\",\"user_id\":\"user1\",\"message\":\"Hello\",\"stream\":false}'"
echo ""
echo "2. Access Flutter app:"
if [ "$DEPLOYMENT_MODE" = "docker" ]; then
    echo "   Open http://localhost:8080 in browser"
else
    echo "   flutter run -d chrome --dart-define=USE_REMOTE_BACKEND=true"
fi
echo ""
echo "3. View logs:"
if [ "$DEPLOYMENT_MODE" = "docker" ]; then
    echo "   cd backend && docker compose logs -f api"
else
    echo "   tail -f backend.log"
fi
echo ""
echo "4. Stop services:"
if [ "$DEPLOYMENT_MODE" = "docker" ]; then
    echo "   cd backend && docker compose down"
else
    echo "   kill \$(cat backend.pid) && docker compose -f backend/docker-compose.yml down"
fi
echo ""

echo -e "${GREEN}Deployment complete! 🚀${NC}"
