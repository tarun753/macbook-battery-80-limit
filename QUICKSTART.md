# Quick Start Guide

## Get Started in 3 Steps

### Step 1: Test Everything
```bash
cd ~/battery-charge-limiter
./test.sh
```

### Step 2: Install
```bash
./install.sh
```

This will:
- Install Homebrew (if needed)
- Install SMC tool
- Set up the background service
- Start protecting your battery

### Step 3: Verify It's Working
```bash
./status.sh
```

## That's It!

Your MacBook will now stop charging at 80% automatically.

---

## What Happens Now?

- Battery charges normally up to 80%
- At 80%, charging stops automatically
- You'll get a notification when limit is reached
- If battery drops below 75%, charging resumes
- Service runs automatically on startup

## Quick Commands

```bash
# Check status
./status.sh

# View logs
tail -f battery_limiter.log

# Stop service
launchctl unload ~/Library/LaunchAgents/com.battery.limiter.plist

# Start service
launchctl load ~/Library/LaunchAgents/com.battery.limiter.plist

# Uninstall everything
./uninstall.sh
```

## Current Battery Status

Run this anytime to see your battery:
```bash
pmset -g batt
```

## Need Help?

See the full [README.md](README.md) for:
- Detailed documentation
- Troubleshooting
- FAQ
- Safety information
- How it works

---

## Important Notes

**Safety**: This tool is completely safe and reversible. It uses official macOS SMC commands.

**Warranty**: No hardware modifications, software-only solution.

**Compatibility**: Works on all MacBooks (Intel and Apple Silicon).

**Battery Health**: Keeping battery at 80% can significantly extend its lifespan!

