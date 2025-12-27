#!/bin/bash

# Battery Charge Limiter - Status Script

echo "======================================"
echo "Battery Charge Limiter - Status"
echo "======================================"
echo ""

# Check if service is running
if launchctl list | grep -q com.battery.limiter; then
    echo "✓ Service is running"
else
    echo "✗ Service is not running"
fi

echo ""
echo "Battery Information:"
pmset -g batt

echo ""
echo "SMC Charging Status:"
if command -v smc &> /dev/null; then
    smc -k CH0B -r 2>/dev/null || echo "Cannot read SMC status"
elif [ -f ~/bin/smc ]; then
    ~/bin/smc -k CH0B -r 2>/dev/null || echo "Cannot read SMC status"
else
    echo "SMC tool not installed"
fi

echo ""
echo "Recent logs (last 10 lines):"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -f "$SCRIPT_DIR/battery_limiter.log" ]; then
    tail -n 10 "$SCRIPT_DIR/battery_limiter.log"
else
    echo "No logs found"
fi

echo ""
