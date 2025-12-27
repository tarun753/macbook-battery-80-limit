//
// main.swift
// Battery Charge Level Max (BCLM) - Apple Silicon
//
// A CLI tool to limit MacBook battery charging to 80%
// Specifically designed for Apple Silicon (M1/M2/M3/M4) Macs
//
// SMC Keys discovered by community:
// - macOS Tahoe (26.x): CHTE - UInt32 - 01000000 = disable charging, 00000000 = enable
// - Legacy (pre-Tahoe): CH0B - UInt8 - 02 = disable, 00 = enable
//
// IMPORTANT: CHTE is an ON/OFF switch, not a percentage limit!
// We need a daemon to monitor battery level and toggle charging.
//

import ArgumentParser
import Foundation

// SMC Keys for different macOS versions
let TAHOE_KEY = "CHTE"      // macOS Tahoe (26.x) - UInt32
let LEGACY_KEY = "CH0B"     // Pre-Tahoe - UInt8
let LEGACY_KEY2 = "CH0C"    // Some Macs need both

struct BCLM: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Battery Charge Level Max (BCLM) Utility for Apple Silicon.",
        version: "1.2.0",
        subcommands: [Read.self, Write.self, Maintain.self, Persist.self, Unpersist.self, Status.self])
    
    // MARK: - Helper Functions
    
    static func enableCharging() -> Bool {
        do {
            try SMCKit.open()
            defer { SMCKit.close() }
            
            // Try Tahoe key first
            let tahoeKey = SMCKit.getKey(TAHOE_KEY, type: DataTypes.UInt32)
            let bytes: SMCBytes = (
                UInt8(0x00), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0)
            )
            
            do {
                _ = try SMCKit.readData(tahoeKey)
                try SMCKit.writeData(tahoeKey, data: bytes)
                return true
            } catch {
                // Try legacy
                let legacyBytes: SMCBytes = (
                    UInt8(0x00), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                    UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                    UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                    UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                    UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                    UInt8(0), UInt8(0)
                )
                let legacyKey = SMCKit.getKey(LEGACY_KEY, type: DataTypes.UInt8)
                try SMCKit.writeData(legacyKey, data: legacyBytes)
                return true
            }
        } catch {
            return false
        }
    }
    
    static func disableCharging() -> Bool {
        do {
            try SMCKit.open()
            defer { SMCKit.close() }
            
            // Try Tahoe key first
            let tahoeKey = SMCKit.getKey(TAHOE_KEY, type: DataTypes.UInt32)
            let bytes: SMCBytes = (
                UInt8(0x01), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                UInt8(0), UInt8(0), UInt8(0), UInt8(0)
            )
            
            do {
                _ = try SMCKit.readData(tahoeKey)
                try SMCKit.writeData(tahoeKey, data: bytes)
                return true
            } catch {
                // Try legacy
                let legacyBytes: SMCBytes = (
                    UInt8(0x02), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                    UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                    UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                    UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                    UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                    UInt8(0), UInt8(0)
                )
                let legacyKey = SMCKit.getKey(LEGACY_KEY, type: DataTypes.UInt8)
                try SMCKit.writeData(legacyKey, data: legacyBytes)
                return true
            }
        } catch {
            return false
        }
    }
    
    static func getBatteryPercentage() -> Int? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["-g", "batt"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // Parse percentage from output like "50%"
                let pattern = #"(\d+)%"#
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
                   let range = Range(match.range(at: 1), in: output) {
                    return Int(output[range])
                }
            }
        } catch {}
        
        return nil
    }
    
    static func isOnACPower() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["-g", "batt"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return output.contains("AC Power")
            }
        } catch {}
        
        return false
    }
    
    // MARK: - Read Command
    struct Read: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Reads the current charging state (enabled/disabled).")
        
        func run() {
            do {
                try SMCKit.open()
            } catch {
                print("Error: \(error)")
                BCLM.exit(withError: ExitCode.failure)
            }
            
            // Try Tahoe key first (CHTE)
            let tahoeKey = SMCKit.getKey(TAHOE_KEY, type: DataTypes.UInt32)
            do {
                let bytes = try SMCKit.readData(tahoeKey)
                let chargingDisabled = bytes.0 != 0
                print(chargingDisabled ? "disabled" : "enabled")
                SMCKit.close()
                return
            } catch {}
            
            // Try legacy key (CH0B)
            let legacyKey = SMCKit.getKey(LEGACY_KEY, type: DataTypes.UInt8)
            do {
                let bytes = try SMCKit.readData(legacyKey)
                let chargingDisabled = bytes.0 != 0
                print(chargingDisabled ? "disabled" : "enabled")
            } catch {
                print("Error: Could not read charging state.")
                BCLM.exit(withError: ExitCode.failure)
            }
            
            SMCKit.close()
        }
    }
    
    // MARK: - Write Command
    struct Write: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Enables or disables charging (80 = disable, 100 = enable).")
        
        @Argument(help: "The value to set (80 = disable charging, 100 = enable)")
        var value: Int
        
        func validate() throws {
            guard getuid() == 0 else {
                throw ValidationError("Must run as root. Use: sudo bclm write \(value)")
            }
            
            guard value == 80 || value == 100 else {
                throw ValidationError("Value must be either 80 or 100.")
            }
        }
        
        func run() {
            let disableCharging = (value == 80)
            
            if disableCharging {
                if BCLM.disableCharging() {
                    print("✓ Charging disabled")
                } else {
                    print("Error: Could not disable charging")
                    BCLM.exit(withError: ExitCode.failure)
                }
            } else {
                if BCLM.enableCharging() {
                    print("✓ Charging enabled")
                } else {
                    print("Error: Could not enable charging")
                    BCLM.exit(withError: ExitCode.failure)
                }
            }
        }
    }
    
    // MARK: - Maintain Command (Background Daemon)
    struct Maintain: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Maintains battery at 80% by monitoring and toggling charging.")
        
        @Argument(help: "Target battery percentage (default: 80)")
        var target: Int = 80
        
        @Option(name: .shortAndLong, help: "Check interval in seconds (default: 60)")
        var interval: Int = 60
        
        @Flag(name: .shortAndLong, help: "Run once and exit (for launchd)")
        var once: Bool = false
        
        func validate() throws {
            guard getuid() == 0 else {
                throw ValidationError("Must run as root. Use: sudo bclm maintain")
            }
            
            guard target >= 20 && target <= 100 else {
                throw ValidationError("Target must be between 20 and 100.")
            }
        }
        
        func run() {
            let lowerThreshold = target - 5  // Start charging when below this
            let upperThreshold = target      // Stop charging when at or above this
            
            print("=== Battery Maintain Mode ===")
            print("Target: \(target)%")
            print("Charge when below: \(lowerThreshold)%")
            print("Stop charging at: \(upperThreshold)%")
            print("Check interval: \(interval) seconds")
            if once {
                print("Mode: Single check")
            } else {
                print("Mode: Continuous monitoring (Ctrl+C to stop)")
            }
            print("=============================\n")
            
            func checkAndAdjust() {
                guard let percentage = BCLM.getBatteryPercentage() else {
                    print("[\(timestamp())] Could not read battery percentage")
                    return
                }
                
                let onAC = BCLM.isOnACPower()
                
                if !onAC {
                    // Not on AC, make sure charging is enabled for when plugged in
                    print("[\(timestamp())] Battery: \(percentage)% | Not on AC power")
                    return
                }
                
                if percentage >= upperThreshold {
                    // At or above target, disable charging
                    if BCLM.disableCharging() {
                        print("[\(timestamp())] Battery: \(percentage)% | ⏸ Charging DISABLED (at target)")
                    }
                } else if percentage < lowerThreshold {
                    // Below lower threshold, enable charging
                    if BCLM.enableCharging() {
                        print("[\(timestamp())] Battery: \(percentage)% | ▶ Charging ENABLED (below \(lowerThreshold)%)")
                    }
                } else {
                    // In between, maintain current state
                    print("[\(timestamp())] Battery: \(percentage)% | Maintaining current state")
                }
            }
            
            func timestamp() -> String {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                return formatter.string(from: Date())
            }
            
            // Run check
            checkAndAdjust()
            
            if once {
                return
            }
            
            // Continuous mode
            while true {
                sleep(UInt32(interval))
                checkAndAdjust()
            }
        }
    }
    
    // MARK: - Persist Command
    struct Persist: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Creates a LaunchDaemon to maintain 80% limit across reboots.")
        
        func validate() throws {
            guard getuid() == 0 else {
                throw ValidationError("Must run as root. Use: sudo bclm persist")
            }
        }
        
        func run() {
            let plistPath = "/Library/LaunchDaemons/com.bclm.maintain.plist"
            let bclmPath = "/usr/local/bin/bclm"
            
            // Check if bclm is installed
            guard FileManager.default.fileExists(atPath: bclmPath) else {
                print("Error: bclm not found at \(bclmPath)")
                print("Please install bclm first: sudo cp .build/release/bclm /usr/local/bin/")
                BCLM.exit(withError: ExitCode.failure)
            }
            
            // Create a LaunchDaemon that runs maintain --once every 60 seconds
            let plistContent = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.bclm.maintain</string>
    <key>ProgramArguments</key>
    <array>
        <string>\(bclmPath)</string>
        <string>maintain</string>
        <string>80</string>
        <string>--once</string>
    </array>
    <key>StartInterval</key>
    <integer>60</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/log/bclm.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/bclm.log</string>
</dict>
</plist>
"""
            
            // Remove old simple persist daemon if exists
            let oldPlistPath = "/Library/LaunchDaemons/com.bclm.persist.plist"
            if FileManager.default.fileExists(atPath: oldPlistPath) {
                let unloadTask = Process()
                unloadTask.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                unloadTask.arguments = ["unload", "-w", oldPlistPath]
                try? unloadTask.run()
                unloadTask.waitUntilExit()
                try? FileManager.default.removeItem(atPath: oldPlistPath)
            }
            
            do {
                try plistContent.write(toFile: plistPath, atomically: true, encoding: .utf8)
                
                // Load the LaunchDaemon
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                task.arguments = ["load", "-w", plistPath]
                try task.run()
                task.waitUntilExit()
                
                print("✓ Battery maintain daemon installed!")
                print("  - Checks battery every 60 seconds")
                print("  - Enables charging below 75%")
                print("  - Disables charging at 80%")
                print("  - Log file: /var/log/bclm.log")
                print("")
                print("  Your battery will now stay between 75-80% automatically!")
            } catch {
                print("Error creating daemon: \(error)")
                BCLM.exit(withError: ExitCode.failure)
            }
        }
    }
    
    // MARK: - Unpersist Command
    struct Unpersist: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Removes the battery maintain daemon and enables charging.")
        
        func validate() throws {
            guard getuid() == 0 else {
                throw ValidationError("Must run as root. Use: sudo bclm unpersist")
            }
        }
        
        func run() {
            // Remove new daemon
            let plistPath = "/Library/LaunchDaemons/com.bclm.maintain.plist"
            let unloadTask = Process()
            unloadTask.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            unloadTask.arguments = ["unload", "-w", plistPath]
            try? unloadTask.run()
            unloadTask.waitUntilExit()
            try? FileManager.default.removeItem(atPath: plistPath)
            
            // Remove old daemon too if exists
            let oldPlistPath = "/Library/LaunchDaemons/com.bclm.persist.plist"
            let unloadOldTask = Process()
            unloadOldTask.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            unloadOldTask.arguments = ["unload", "-w", oldPlistPath]
            try? unloadOldTask.run()
            unloadOldTask.waitUntilExit()
            try? FileManager.default.removeItem(atPath: oldPlistPath)
            
            // Enable charging
            if BCLM.enableCharging() {
                print("✓ Daemon removed and charging enabled.")
            } else {
                print("✓ Daemon removed. Charging state unchanged.")
            }
        }
    }
    
    // MARK: - Status Command
    struct Status: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Shows current battery status and charging state.")
        
        func run() {
            print("=== Battery Charge Limiter Status ===\n")
            
            // Get current charging state from SMC
            do {
                try SMCKit.open()
                
                var chargingDisabled = false
                var keyUsed = "unknown"
                
                // Try Tahoe key first
                let tahoeKey = SMCKit.getKey(TAHOE_KEY, type: DataTypes.UInt32)
                do {
                    let bytes = try SMCKit.readData(tahoeKey)
                    chargingDisabled = bytes.0 != 0
                    keyUsed = TAHOE_KEY
                } catch {
                    // Try legacy key
                    let legacyKey = SMCKit.getKey(LEGACY_KEY, type: DataTypes.UInt8)
                    do {
                        let bytes = try SMCKit.readData(legacyKey)
                        chargingDisabled = bytes.0 != 0
                        keyUsed = LEGACY_KEY
                    } catch {
                        print("Could not read SMC (try with sudo)")
                    }
                }
                
                print("Charging State: \(chargingDisabled ? "DISABLED" : "ENABLED") (via \(keyUsed))")
                SMCKit.close()
            } catch {
                print("Could not read SMC: \(error)")
                print("(Try running with sudo for full access)")
            }
            
            // Get current battery info from pmset
            print("\n--- Current Battery Info ---")
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            task.arguments = ["-g", "batt"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    print(output)
                }
            } catch {
                print("Could not get battery info: \(error)")
            }
            
            // Check for maintain daemon
            let maintainPlist = "/Library/LaunchDaemons/com.bclm.maintain.plist"
            let oldPlist = "/Library/LaunchDaemons/com.bclm.persist.plist"
            
            if FileManager.default.fileExists(atPath: maintainPlist) {
                print("Daemon: ✓ Maintain daemon active (checks every 60s)")
            } else if FileManager.default.fileExists(atPath: oldPlist) {
                print("Daemon: ⚠ Old persist daemon (run 'sudo bclm persist' to upgrade)")
            } else {
                print("Daemon: Not installed (run 'sudo bclm persist' to enable)")
            }
        }
    }
}

BCLM.main()
