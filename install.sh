#!/bin/bash

# Battery Charge Limiter - Install Script for Apple Silicon
# This script builds and installs the bclm tool

set -e

echo "======================================"
echo "Battery Charge Limiter - Install"
echo "For Apple Silicon Macs (M1/M2/M3/M4)"
echo "======================================"
echo ""

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Step 1: Checking Swift...${NC}"
if command -v swift &> /dev/null; then
    swift --version
    echo -e "${GREEN}✓ Swift is available${NC}"
else
    echo -e "${RED}✗ Swift not found. Please install Xcode or Command Line Tools.${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 2: Building release version...${NC}"
swift build -c release
if [ -f ".build/release/bclm" ]; then
    echo -e "${GREEN}✓ Build successful${NC}"
else
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 3: Installing bclm to /usr/local/bin...${NC}"
sudo cp .build/release/bclm /usr/local/bin/
sudo chmod 755 /usr/local/bin/bclm
if [ -f "/usr/local/bin/bclm" ]; then
    echo -e "${GREEN}✓ Installed to /usr/local/bin/bclm${NC}"
else
    echo -e "${RED}✗ Installation failed${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Step 4: Testing installation...${NC}"
bclm --version
echo -e "${GREEN}✓ bclm is now available globally${NC}"

echo ""
echo "======================================"
echo -e "${GREEN}Installation Complete!${NC}"
echo "======================================"
echo ""
echo "Usage:"
echo "  bclm status           # Check current battery limit"
echo "  sudo bclm write 80    # Set 80% charge limit"
echo "  sudo bclm write 100   # Remove charge limit"
echo "  sudo bclm persist     # Keep limit after reboot"
echo "  sudo bclm unpersist   # Remove persistence"
echo ""
echo -e "${YELLOW}To enable 80% battery limit now, run:${NC}"
echo "  sudo bclm write 80"
echo ""
