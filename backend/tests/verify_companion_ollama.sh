#!/bin/bash
# Companion Module Ollama Integration Verification Script

set -e

echo "==================================="
echo "Companion Module Verification"
echo "==================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BACKEND_URL="${BACKEND_URL:-http://localhost:8000}"
OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
API_PREFIX="/api/v1"

# Step 1: Check if Ollama is running
echo "1. Checking Ollama service..."
if curl -sf "${OLLAMA_URL}/api/tags" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Ollama is running at ${OLLAMA_URL}"
    
    # List available models
    echo "   Available models:"
    curl -s "${OLLAMA_URL}/api/tags" | python3 -m json.tool | grep '"name"' || echo "   (Could not parse models)"
else
    echo -e "${RED}✗${NC} Ollama is NOT running at ${OLLAMA_URL}"
    echo -e "${YELLOW}!${NC} To start Ollama:"
    echo "   - macOS: Download from https://ollama.ai"
    echo "   - Linux: curl https://ollama.ai/install.sh | sh"
    echo "   - Then run: ollama pull gpt-oss:20b"
    OLLAMA_RUNNING=false
fi
echo ""

# Step 2: Check if backend is running
echo "2. Checking backend service..."
if curl -sf "${BACKEND_URL}/health" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Backend is running at ${BACKEND_URL}"
else
    echo -e "${RED}✗${NC} Backend is NOT running at ${BACKEND_URL}"
    echo -e "${YELLOW}!${NC} To start backend:"
    echo "   cd backend && docker compose up"
    exit 1
fi
echo ""

# Step 3: List available companions
echo "3. Fetching available companions..."
COMPANIONS=$(curl -sf "${BACKEND_URL}${API_PREFIX}/companions/" | python3 -m json.tool)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Companions endpoint responding"
    echo "   Available companions:"
    echo "$COMPANIONS" | grep '"name"' | head -5
    
    # Extract first companion ID
    COMPANION_ID=$(echo "$COMPANIONS" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data[0]['id'] if data else '')" 2>/dev/null || echo "")
else
    echo -e "${RED}✗${NC} Failed to fetch companions"
    exit 1
fi
echo ""

# Step 4: Create a test session
echo "4. Creating test companion session..."
TEST_USER_ID="test_user_$(date +%s)"
TEST_SESSION_ID="test_session_$(date +%s)"

if [ -n "$COMPANION_ID" ]; then
    SESSION_RESPONSE=$(curl -sf -X POST "${BACKEND_URL}${API_PREFIX}/companions/users/${TEST_USER_ID}/sessions" \
        -H "Content-Type: application/json" \
        -H "X-User-Id: ${TEST_USER_ID}" \
        -d "{\"companion_id\": \"${COMPANION_ID}\", \"session_id\": \"${TEST_SESSION_ID}\"}")
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Test session created: ${TEST_SESSION_ID}"
    else
        echo -e "${RED}✗${NC} Failed to create session"
        exit 1
    fi
else
    echo -e "${RED}✗${NC} No companion ID found"
    exit 1
fi
echo ""

# Step 5: Send a test message (non-streaming)
echo "5. Testing AI response (non-streaming)..."
if [ "${OLLAMA_RUNNING}" != "false" ]; then
    MESSAGE_PAYLOAD=$(cat <<EOF
{
    "session_id": "${TEST_SESSION_ID}",
    "user_id": "${TEST_USER_ID}",
    "message": "Hello, I'm testing the integration. Please respond briefly.",
    "stream": false,
    "model": "gpt-oss:20b"
}
EOF
)
    
    echo "   Sending message to /chat endpoint..."
    CHAT_RESPONSE=$(curl -sf -X POST "${BACKEND_URL}${API_PREFIX}/companions/chat" \
        -H "Content-Type: application/json" \
        -d "$MESSAGE_PAYLOAD" 2>&1)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Chat endpoint responded"
        echo "   Response preview:"
        echo "$CHAT_RESPONSE" | python3 -m json.tool | grep '"response"' | head -c 200
        echo "..."
    else
        echo -e "${YELLOW}!${NC} Chat endpoint may not be configured or Ollama model not available"
        echo "   Error: $CHAT_RESPONSE"
    fi
else
    echo -e "${YELLOW}!${NC} Skipping chat test (Ollama not running)"
fi
echo ""

# Step 6: Test message persistence
echo "6. Testing message persistence..."
USER_MESSAGE=$(cat <<EOF
{
    "companion_id": "${COMPANION_ID}",
    "companion_name": "Test Companion",
    "role": "user",
    "content": "This is a test message for persistence verification"
}
EOF
)

MSG_RESPONSE=$(curl -sf -X POST "${BACKEND_URL}${API_PREFIX}/companions/users/${TEST_USER_ID}/sessions/${TEST_SESSION_ID}/messages" \
    -H "Content-Type: application/json" \
    -H "X-User-Id: ${TEST_USER_ID}" \
    -d "$USER_MESSAGE")

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Message persisted successfully"
    MESSAGE_COUNT=$(echo "$MSG_RESPONSE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['session']['message_count'])" 2>/dev/null || echo "0")
    echo "   Session message count: ${MESSAGE_COUNT}"
else
    echo -e "${RED}✗${NC} Failed to persist message"
fi
echo ""

# Step 7: Fetch session details
echo "7. Fetching session details with messages..."
SESSION_DETAIL=$(curl -sf "${BACKEND_URL}${API_PREFIX}/companions/sessions/${TEST_SESSION_ID}" \
    -H "X-User-Id: ${TEST_USER_ID}")

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Session details retrieved"
    MSG_COUNT=$(echo "$SESSION_DETAIL" | python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data.get('messages', [])))" 2>/dev/null || echo "0")
    echo "   Messages in session: ${MSG_COUNT}"
else
    echo -e "${RED}✗${NC} Failed to fetch session details"
fi
echo ""

# Summary
echo "==================================="
echo "Verification Summary"
echo "==================================="
echo -e "Backend API:       ${GREEN}✓ Running${NC}"
echo -e "Companions Module: ${GREEN}✓ Functional${NC}"
if [ "${OLLAMA_RUNNING}" != "false" ]; then
    echo -e "Ollama Integration:${GREEN}✓ Available${NC}"
else
    echo -e "Ollama Integration:${YELLOW}! Not Running${NC}"
fi
echo ""
echo "Next steps:"
echo "  1. Ensure Ollama is running with a model loaded"
echo "  2. Test from Flutter app with USE_REMOTE_BACKEND=true"
echo "  3. Run backend tests: cd backend && pytest tests/"
echo ""
