#!/usr/bin/env python3
"""
Battery Charge Limiter for MacBook
Safely limits battery charging to 80% to preserve battery health
"""

import subprocess
import time
import os
import sys
from datetime import datetime
import json

class BatteryLimiter:
    def __init__(self, charge_limit=80, check_interval=60):
        """
        Initialize the battery limiter

        Args:
            charge_limit: Maximum battery percentage (default: 80%)
            check_interval: How often to check battery status in seconds (default: 60)
        """
        self.charge_limit = charge_limit
        self.check_interval = check_interval
        self.log_file = os.path.expanduser("~/battery-charge-limiter/battery_limiter.log")
        self.state_file = os.path.expanduser("~/battery-charge-limiter/state.json")
        self.charging_enabled = True

        # Create log directory if it doesn't exist
        os.makedirs(os.path.dirname(self.log_file), exist_ok=True)

    def log(self, message):
        """Log message to file and console"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_message = f"[{timestamp}] {message}"
        print(log_message)

        try:
            with open(self.log_file, 'a') as f:
                f.write(log_message + '\n')
        except Exception as e:
            print(f"Error writing to log: {e}")

    def get_battery_info(self):
        """Get current battery information using pmset"""
        try:
            result = subprocess.run(['pmset', '-g', 'batt'],
                                  capture_output=True, text=True, check=True)
            output = result.stdout

            # Parse battery percentage
            battery_info = {}
            for line in output.split('\n'):
                if 'InternalBattery' in line:
                    # Extract percentage
                    parts = line.split('\t')[1] if '\t' in line else line
                    if '%' in parts:
                        percentage_str = parts.split('%')[0].strip()
                        battery_info['percentage'] = int(percentage_str)

                    # Check if charging
                    battery_info['charging'] = 'charging' in parts.lower()
                    battery_info['ac_connected'] = 'AC Power' in output

            return battery_info
        except Exception as e:
            self.log(f"Error getting battery info: {e}")
            return None

    def enable_charging(self):
        """Enable battery charging via SMC"""
        try:
            # Use smc tool to enable charging
            result = subprocess.run(['smc', '-k', 'CH0B', '-w', '00'],
                                  capture_output=True, text=True)

            if result.returncode == 0:
                self.charging_enabled = True
                self.log("✓ Charging enabled")
                self.save_state()
                return True
            else:
                self.log(f"Failed to enable charging: {result.stderr}")
                return False
        except FileNotFoundError:
            self.log("ERROR: SMC tool not found. Please install it first.")
            return False
        except Exception as e:
            self.log(f"Error enabling charging: {e}")
            return False

    def disable_charging(self):
        """Disable battery charging via SMC"""
        try:
            # Use smc tool to disable charging
            result = subprocess.run(['smc', '-k', 'CH0B', '-w', '01'],
                                  capture_output=True, text=True)

            if result.returncode == 0:
                self.charging_enabled = False
                self.log("✓ Charging disabled (battery protection active)")
                self.save_state()
                self.send_notification("Battery limit reached",
                                     f"Charging stopped at {self.charge_limit}%")
                return True
            else:
                self.log(f"Failed to disable charging: {result.stderr}")
                return False
        except FileNotFoundError:
            self.log("ERROR: SMC tool not found. Please install it first.")
            return False
        except Exception as e:
            self.log(f"Error disabling charging: {e}")
            return False

    def send_notification(self, title, message):
        """Send macOS notification"""
        try:
            script = f'display notification "{message}" with title "{title}"'
            subprocess.run(['osascript', '-e', script], check=True)
        except Exception as e:
            self.log(f"Error sending notification: {e}")

    def save_state(self):
        """Save current state to file"""
        try:
            state = {
                'charging_enabled': self.charging_enabled,
                'last_update': datetime.now().isoformat()
            }
            with open(self.state_file, 'w') as f:
                json.dump(state, f, indent=2)
        except Exception as e:
            self.log(f"Error saving state: {e}")

    def load_state(self):
        """Load state from file"""
        try:
            if os.path.exists(self.state_file):
                with open(self.state_file, 'r') as f:
                    state = json.load(f)
                    self.charging_enabled = state.get('charging_enabled', True)
                    self.log(f"Loaded previous state: charging_enabled={self.charging_enabled}")
        except Exception as e:
            self.log(f"Error loading state: {e}")

    def check_and_control_charging(self):
        """Main logic to check battery and control charging"""
        battery_info = self.get_battery_info()

        if not battery_info:
            self.log("Could not get battery information")
            return

        percentage = battery_info.get('percentage', 0)
        charging = battery_info.get('charging', False)
        ac_connected = battery_info.get('ac_connected', False)

        self.log(f"Battery: {percentage}% | Charging: {charging} | AC: {ac_connected} | Limit: {self.charging_enabled}")

        # Logic to control charging
        if ac_connected:
            if percentage >= self.charge_limit and self.charging_enabled:
                # Battery reached limit, disable charging
                self.log(f"Battery at {percentage}% (limit: {self.charge_limit}%), disabling charging...")
                self.disable_charging()

            elif percentage < (self.charge_limit - 5) and not self.charging_enabled:
                # Battery dropped below limit with hysteresis, enable charging
                self.log(f"Battery at {percentage}% (below {self.charge_limit - 5}%), enabling charging...")
                self.enable_charging()
        else:
            # No AC power, ensure charging is enabled for when AC is connected
            if not self.charging_enabled:
                self.log("AC disconnected, resetting charging state...")
                self.charging_enabled = True
                self.save_state()

    def run(self):
        """Main loop to continuously monitor battery"""
        self.log("="*60)
        self.log(f"Battery Charge Limiter Started")
        self.log(f"Charge limit: {self.charge_limit}%")
        self.log(f"Check interval: {self.check_interval} seconds")
        self.log("="*60)

        # Load previous state
        self.load_state()

        # Initial check
        self.check_and_control_charging()

        try:
            while True:
                time.sleep(self.check_interval)
                self.check_and_control_charging()
        except KeyboardInterrupt:
            self.log("\nStopping Battery Charge Limiter...")
            # Re-enable charging when stopped
            if not self.charging_enabled:
                self.log("Re-enabling charging before exit...")
                self.enable_charging()
            sys.exit(0)

def main():
    """Main entry point"""
    # Parse command line arguments
    charge_limit = 80
    check_interval = 60

    if len(sys.argv) > 1:
        try:
            charge_limit = int(sys.argv[1])
            if charge_limit < 20 or charge_limit > 100:
                print("Charge limit must be between 20 and 100")
                sys.exit(1)
        except ValueError:
            print("Invalid charge limit. Using default 80%")

    if len(sys.argv) > 2:
        try:
            check_interval = int(sys.argv[2])
        except ValueError:
            print("Invalid check interval. Using default 60 seconds")

    limiter = BatteryLimiter(charge_limit=charge_limit, check_interval=check_interval)
    limiter.run()

if __name__ == "__main__":
    main()
