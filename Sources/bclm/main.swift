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
// v1.3.0: Fixed sleep mode issue - now disables charging when at target
//         even if screen is off or sleeping
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
        version: "1.3.0",
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
    
    static func isChargingDisabled() -> Bool? {
        do {
            try SMCKit.open()
            defer { SMCKit.close() }
            
            // Try Tahoe key first
            let tahoeKey = SMCKit.getKey(TAHOE_KEY, type: DataTypes.UInt32)
            do {
                let bytes = try SMCKit.readData(tahoeKey)
                return bytes.0 != 0
            } catch {
                // Try legacy key
                let legacyKey = SMCKit.getKey(LEGACY_KEY, type: DataTypes.UInt8)
                let bytes = try SMCKit.readData(legacyKey)
                return bytes.0 != 0
            }
        } catch {
            return nil
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
            if let disabled = BCLM.isChargingDisabled() {
                print(disabled ? "disabled" : "enabled")
            } else {
                print("Error: Could not read charging state.")
                BCLM.exit(withError: ExitCode.failure)
            }
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
            abstract: "Maintains battery at target% by monitoring and toggling charging.")
        
        @Argument(help: "Target battery percentage (default: 80)")
        var target: Int = 80
        
        @Option(name: .shortAndLong, help: "Check interval in seconds (default: 30)")
        var interval: Int = 30
        
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
            
            if !once {
                print("=== Battery Maintain Mode ===")
                print("Target: \(target)%")
                print("Charge when below: \(lowerThreshold)%")
                print("Stop charging at: \(upperThreshold)%")
                print("Check interval: \(interval) seconds")
                print("Mode: Continuous monitoring (Ctrl+C to stop)")
                print("=============================\n")
            }
            
            func checkAndAdjust() {
                guard let percentage = BCLM.getBatteryPercentage() else {
                    log("Could not read battery percentage")
                    return
                }
                
                let onAC = BCLM.isOnACPower()
                let chargingDisabled = BCLM.isChargingDisabled() ?? false
                
                // KEY FIX: If battery is at or above target, ALWAYS disable charging
                // This ensures charging stays disabled even during sleep
                if percentage >= upperThreshold {
                    if !chargingDisabled {
                        if BCLM.disableCharging() {
                            log("Battery: \(percentage)% | ⏸ Charging DISABLED (at/above \(upperThreshold)%)")
                        }
                    } else {
                        log("Battery: \(percentage)% | Charging already disabled")
                    }
                    return
                }
                
                // If not on AC power, just report status but keep charging state
                // This ensures if we're at 80% and go to sleep, charging stays disabled
                if !onAC {
                    if percentage >= upperThreshold && !chargingDisabled {
                        // Even on battery, if we're at target, disable charging for when plugged in
                        if BCLM.disableCharging() {
                            log("Battery: \(percentage)% | ⏸ Charging DISABLED (preparing for AC)")
                        }
                    } else {
                        log("Battery: \(percentage)% | Not on AC power (charging: \(chargingDisabled ? "disabled" : "enabled"))")
                    }
                    return
                }
                
                // On AC and below target
                if percentage < lowerThreshold {
                    // Below lower threshold, enable charging
                    if chargingDisabled {
                        if BCLM.enableCharging() {
                            log("Battery: \(percentage)% | ▶ Charging ENABLED (below \(lowerThreshold)%)")
                        }
                    } else {
                        log("Battery: \(percentage)% | Charging (below \(lowerThreshold)%)")
                    }
                } else {
                    // Between thresholds, maintain current state
                    log("Battery: \(percentage)% | In range \(lowerThreshold)-\(upperThreshold)% (charging: \(chargingDisabled ? "disabled" : "enabled"))")
                }
            }
            
            func log(_ message: String) {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                let timestamp = formatter.string(from: Date())
                print("[\(timestamp)] \(message)")
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
            abstract: "Creates a LaunchDaemon to maintain 80% limit across reboots and sleep.")
        
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
            
            // Create a LaunchDaemon that:
            // 1. Runs every 30 seconds (more frequent than before)
            // 2. Runs on power state changes (AC connect/disconnect)
            // 3. Runs on wake from sleep
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
    <integer>30</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>StandardOutPath</key>
    <string>/var/log/bclm.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/bclm.log</string>
    <key>ProcessType</key>
    <string>Background</string>
</dict>
</plist>
"""
            
            // Remove old daemons
            let oldPlistPath = "/Library/LaunchDaemons/com.bclm.persist.plist"
            if FileManager.default.fileExists(atPath: oldPlistPath) {
                let unloadTask = Process()
                unloadTask.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                unloadTask.arguments = ["unload", "-w", oldPlistPath]
                try? unloadTask.run()
                unloadTask.waitUntilExit()
                try? FileManager.default.removeItem(atPath: oldPlistPath)
            }
            
            // Unload existing daemon if any
            let unloadTask = Process()
            unloadTask.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            unloadTask.arguments = ["unload", "-w", plistPath]
            try? unloadTask.run()
            unloadTask.waitUntilExit()
            
            do {
                try plistContent.write(toFile: plistPath, atomically: true, encoding: .utf8)
                
                // Load the LaunchDaemon
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                task.arguments = ["load", "-w", plistPath]
                try task.run()
                task.waitUntilExit()
                
                // Also disable charging NOW if above 80%
                if let percentage = BCLM.getBatteryPercentage(), percentage >= 80 {
                    _ = BCLM.disableCharging()
                    print("✓ Battery at \(percentage)% - charging disabled immediately")
                }
                
                print("✓ Battery maintain daemon installed!")
                print("  - Checks battery every 30 seconds")
                print("  - Enables charging below 75%")  
                print("  - Disables charging at 80%")
                print("  - Works during sleep (charging stays disabled)")
                print("  - Log file: /var/log/bclm.log")
                print("")
                print("  Your battery will now stay at 80% automatically!")
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
            if let disabled = BCLM.isChargingDisabled() {
                print("Charging State: \(disabled ? "DISABLED" : "ENABLED") (via CHTE)")
            } else {
                print("Charging State: Could not read (try with sudo)")
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
                print("Daemon: ✓ Maintain daemon active (checks every 30s)")
            } else if FileManager.default.fileExists(atPath: oldPlist) {
                print("Daemon: ⚠ Old persist daemon (run 'sudo bclm persist' to upgrade)")
            } else {
                print("Daemon: Not installed (run 'sudo bclm persist' to enable)")
            }
        }
    }
}

BCLM.main()
