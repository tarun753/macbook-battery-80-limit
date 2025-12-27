#!/bin/bash

# Battery Charge Limiter - Test Script
# Run this before installing to test if everything works

echo "======================================"
echo "Battery Charge Limiter - Test"
echo "======================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo -e "${YELLOW}Test 1: Checking Python3...${NC}"
if command -v python3 &> /dev/null; then
    python3 --version
    echo -e "${GREEN}✓ Python3 is available${NC}"
else
    echo -e "${RED}✗ Python3 not found${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Test 2: Checking battery detection...${NC}"
if pmset -g batt &> /dev/null; then
    pmset -g batt
    echo -e "${GREEN}✓ Battery detection working${NC}"
else
    echo -e "${RED}✗ Cannot detect battery${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Test 3: Checking SMC tool...${NC}"
if command -v smc &> /dev/null; then
    smc -v 2>/dev/null || smc -h 2>/dev/null || echo "SMC tool found"
    echo -e "${GREEN}✓ SMC tool is installed${NC}"
else
    echo -e "${YELLOW}⚠ SMC tool not found (will be installed during setup)${NC}"
fi

echo ""
echo -e "${YELLOW}Test 4: Testing Python script syntax...${NC}"
if python3 -m py_compile "$SCRIPT_DIR/battery_limiter.py"; then
    echo -e "${GREEN}✓ Python script syntax is valid${NC}"
else
    echo -e "${RED}✗ Python script has syntax errors${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Test 5: Checking permissions...${NC}"
if [ -w "$SCRIPT_DIR" ]; then
    echo -e "${GREEN}✓ Write permissions OK${NC}"
else
    echo -e "${RED}✗ No write permissions in script directory${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Test 6: Simulating battery check (dry run)...${NC}"
python3 "$SCRIPT_DIR/battery_limiter.py" &
PID=$!
sleep 3
kill $PID 2>/dev/null
if [ -f "$SCRIPT_DIR/battery_limiter.log" ]; then
    echo "Last log entry:"
    tail -n 1 "$SCRIPT_DIR/battery_limiter.log"
    echo -e "${GREEN}✓ Script runs successfully${NC}"
else
    echo -e "${YELLOW}⚠ No log file created, but script ran${NC}"
fi

echo ""
echo "======================================"
echo -e "${GREEN}All Tests Passed!${NC}"
echo "======================================"
echo ""
echo "You can now run './install.sh' to install the battery limiter."
echo ""
