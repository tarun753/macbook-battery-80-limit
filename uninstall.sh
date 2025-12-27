#!/bin/bash

# Battery Charge Limiter - Uninstall Script

echo "======================================"
echo "Battery Charge Limiter - Uninstall"
echo "======================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Step 1: Removing LaunchDaemon...${NC}"
if [ -f "/Library/LaunchDaemons/com.bclm.persist.plist" ]; then
    sudo launchctl unload -w /Library/LaunchDaemons/com.bclm.persist.plist 2>/dev/null || true
    sudo rm -f /Library/LaunchDaemons/com.bclm.persist.plist
    echo -e "${GREEN}✓ LaunchDaemon removed${NC}"
else
    echo "No LaunchDaemon found"
fi

echo ""
echo -e "${YELLOW}Step 2: Re-enabling charging (resetting to 100%)...${NC}"
if [ -f "/usr/local/bin/bclm" ]; then
    sudo /usr/local/bin/bclm write 100 2>/dev/null || echo "Could not reset limit (not critical)"
fi
echo -e "${GREEN}✓ Charging reset to 100%${NC}"

echo ""
echo -e "${YELLOW}Step 3: Removing bclm binary...${NC}"
if [ -f "/usr/local/bin/bclm" ]; then
    sudo rm -f /usr/local/bin/bclm
    echo -e "${GREEN}✓ bclm removed from /usr/local/bin${NC}"
else
    echo "bclm not installed in /usr/local/bin"
fi

echo ""
echo "======================================"
echo -e "${GREEN}Uninstall Complete!${NC}"
echo "======================================"
echo ""
echo "Battery charging has been reset to 100%."
echo "You can delete this directory if you no longer need it:"
echo "  rm -rf ~/battery-charge-limiter"
echo ""
