#!/bin/bash

# Battery Charge Limiter - Toggle Script
# Quickly enable/disable the 80% limit

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "======================================"
echo "Battery Limiter - Quick Toggle"
echo "======================================"
echo ""

# Check if service is running
if launchctl list | grep -q com.battery.limiter; then
    echo -e "${YELLOW}Status: 80% limit is ACTIVE${NC}"
    echo ""
    echo "Disabling limiter to allow 100% charging..."
    launchctl unload ~/Library/LaunchAgents/com.battery.limiter.plist

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Limiter DISABLED${NC}"
        echo ""
        echo "Your battery will now charge to 100%"
        echo ""
        echo "To re-enable the 80% limit, run this script again:"
        echo "  ./toggle.sh"
    else
        echo -e "${RED}✗ Failed to disable limiter${NC}"
    fi
else
    echo -e "${YELLOW}Status: 80% limit is DISABLED${NC}"
    echo ""
    echo "Enabling limiter to protect battery at 80%..."
    launchctl load ~/Library/LaunchAgents/com.battery.limiter.plist

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Limiter ENABLED${NC}"
        echo ""
        echo "Your battery will stop charging at 80%"
        echo ""
        echo "Current battery status:"
        pmset -g batt | grep -o '[0-9]*%'
    else
        echo -e "${RED}✗ Failed to enable limiter${NC}"
    fi
fi

echo ""
echo "======================================"
