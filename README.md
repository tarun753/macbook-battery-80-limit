# Battery Charge Limiter for Apple Silicon

A native Swift CLI tool to limit MacBook battery charging to 80% on **Apple Silicon Macs (M1/M2/M3/M4)** running **macOS Tahoe (26.x)** and later.

## Why Use This?

- 🔋 **Extends battery lifespan** by keeping charge between 75-80%
- ⚡ **Hardware-level control** via SMC (System Management Controller)
- 🤖 **Background daemon** that monitors and adjusts automatically
- 🍎 **Native Swift** - no Python, no dependencies
- 💻 **macOS Tahoe compatible** - uses the new `CHTE` SMC key

## Quick Start

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/battery-charge-limiter.git
cd battery-charge-limiter

# Build and install
./install.sh

# Enable 80% limit (with auto-monitoring daemon)
sudo bclm persist

# Check status
bclm status
```

## Commands

| Command | Description |
|---------|-------------|
| `bclm status` | Show current battery and charging state |
| `bclm read` | Read current charging state (enabled/disabled) |
| `sudo bclm write 80` | Disable charging immediately |
| `sudo bclm write 100` | Enable charging immediately |
| `sudo bclm maintain 80` | Run monitoring daemon (foreground) |
| `sudo bclm persist` | Install background daemon (survives reboots) |
| `sudo bclm unpersist` | Remove daemon and enable charging |

## How It Works

### SMC Keys

| macOS Version | SMC Key | Disable Charging | Enable Charging |
|---------------|---------|------------------|-----------------|
| Tahoe (26.x)+ | `CHTE` | `01000000` | `00000000` |
| Legacy (<15) | `CH0B` | `02` | `00` |

### The Daemon

The `persist` command installs a LaunchDaemon that:
1. Checks battery every 60 seconds
2. **Enables** charging when battery < 75%
3. **Disables** charging when battery ≥ 80%
4. Logs activity to `/var/log/bclm.log`

This prevents the battery from constantly toggling between charging states.

## Requirements

- macOS Tahoe (26.x) or later (also works on Sequoia 15.x)
- Apple Silicon Mac (M1, M2, M3, M4)
- Xcode Command Line Tools (for Swift)

## Building from Source

```bash
# Build debug version
swift build

# Build release version
swift build -c release

# The binary will be at .build/release/bclm
```

## Uninstalling

```bash
./uninstall.sh
```

This removes the daemon and re-enables full charging.

## Technical Details

The tool communicates with the SMC (System Management Controller) via IOKit:

```
bclm → IOKit → AppleSMC.kext → SMC Chip → Battery
```

When charging is disabled:
- Mac runs directly from charger power
- Battery is electrically isolated
- No current flows to/from battery

## Credits

- SMC communication based on [SMCKit](https://github.com/beltex/SMCKit) by beltex
- CHTE key discovery from [actuallymentor/battery](https://github.com/actuallymentor/battery)
- Inspired by [zackelia/bclm](https://github.com/zackelia/bclm)

## License

MIT License - Feel free to use, modify, and distribute!

## Contributing

Pull requests welcome! Especially for:
- Testing on different Mac models
- Menu bar app integration
- Proper time-to-80% display
