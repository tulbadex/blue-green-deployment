#!/usr/bin/env python3
import os
import re
import time
import json
import requests
from collections import deque, defaultdict
from datetime import datetime, timezone, timedelta

class LogWatcher:
    def __init__(self):
        self.webhook_url = os.getenv('SLACK_WEBHOOK_URL')
        self.error_threshold = float(os.getenv('ERROR_RATE_THRESHOLD', 2))
        self.window_size = int(os.getenv('WINDOW_SIZE', 200))
        self.cooldown = int(os.getenv('ALERT_COOLDOWN_SEC', 300))
        
        self.request_window = deque(maxlen=self.window_size)
        self.last_pool = None
        self.last_alerts = defaultdict(float)
        
        print(f"=== Blue/Green Log Watcher Started ===", flush=True)
        print(f"Error threshold: {self.error_threshold}%", flush=True)
        print(f"Window size: {self.window_size} requests", flush=True)
        print(f"Alert cooldown: {self.cooldown} seconds", flush=True)
        print(f"Slack webhook: {'Configured' if self.webhook_url else 'NOT CONFIGURED'}", flush=True)
        print(f"=======================================", flush=True)

    def parse_log_line(self, line):
        try:
            pattern = r'pool="([^"]*)" release="([^"]*)" upstream_status="([^"]*)" upstream="([^"]*)"'
            match = re.search(pattern, line)
            if match:
                pool = match.group(1) or 'unknown'
                upstream_status = match.group(3) or '200'
                
                # Check if any upstream status is 5xx (handle multiple statuses like "500, 200")
                has_5xx = any(status.strip().startswith('5') for status in upstream_status.split(','))
                
                return {
                    'pool': pool,
                    'release': match.group(2) or 'unknown',
                    'upstream_status': upstream_status,
                    'has_5xx': has_5xx,
                    'timestamp': datetime.now(timezone(timedelta(hours=1)))
                }
        except Exception as e:
            print(f"Error parsing log line: {e}")
        return None

    def send_slack_alert(self, message, alert_type, details=None):
        if not self.webhook_url:
            print(f"No webhook URL configured. Alert: {message}", flush=True)
            return
            
        now = time.time()
        if now - self.last_alerts[alert_type] < self.cooldown:
            print(f"Alert cooldown active for {alert_type}. Skipping. ({int(self.cooldown - (now - self.last_alerts[alert_type]))}s remaining)", flush=True)
            return
            
        # Nigeria time (UTC+1)
        nigeria_tz = timezone(timedelta(hours=1))
        timestamp = datetime.now(nigeria_tz).strftime('%Y-%m-%d %H:%M:%S WAT')
        
        if "failover" in alert_type:
            # Determine colors based on pools involved
            if "blue_to_green" in alert_type:
                border_color = "#0066CC"  # Blue
                pool_info = "🔵 BLUE POOL → 🟢 GREEN POOL"
                failed_pool = "BLUE"
                active_pool = "GREEN"
            elif "green_to_blue" in alert_type:
                border_color = "#00CC66"  # Green  
                pool_info = "🟢 GREEN POOL → 🔵 BLUE POOL"
                failed_pool = "GREEN"
                active_pool = "BLUE"
            else:
                border_color = "#FF8C00"  # Orange fallback
                pool_info = "Pool Switch"
                failed_pool = "UNKNOWN"
                active_pool = "UNKNOWN"
                
            payload = {
                "text": f"🔄 *FAILOVER DETECTED* {pool_info}",
                "username": "Blue-Green Monitor",
                "icon_emoji": ":arrows_counterclockwise:",
                "attachments": [{
                    "color": border_color,
                    "fields": [
                        {"title": "Alert Type", "value": "Failover Event", "short": True},
                        {"title": "Time", "value": timestamp, "short": True},
                        {"title": "Failed Pool", "value": f"🔴 {failed_pool}", "short": True},
                        {"title": "Active Pool", "value": f"✅ {active_pool}", "short": True},
                        {"title": "Traffic Flow", "value": pool_info, "short": False},
                        {"title": "Action Required", "value": details or "Check container health", "short": False}
                    ],
                    "footer": "Blue/Green Deployment Monitor"
                }]
            }
        elif alert_type == "error_rate":
            payload = {
                "text": "🚨 *HIGH ERROR RATE ALERT*",
                "username": "Blue-Green Monitor", 
                "icon_emoji": ":exclamation:",
                "attachments": [{
                    "color": "#FF0000",  # Red for errors
                    "fields": [
                        {"title": "Alert Type", "value": "High Error Rate", "short": True},
                        {"title": "Time", "value": timestamp, "short": True},
                        {"title": "Details", "value": message, "short": False},
                        {"title": "Action Required", "value": details or "Check upstream health", "short": False}
                    ],
                    "footer": "Blue/Green Deployment Monitor"
                }]
            }
        else:
            payload = {
                "text": f"🚨 *Blue/Green Alert: {message}*",
                "username": "Blue-Green Monitor",
                "icon_emoji": ":warning:",
                "attachments": [{
                    "color": "#FFFF00",  # Yellow for other alerts
                    "fields": [
                        {"title": "Time", "value": timestamp, "short": True},
                        {"title": "Details", "value": details or "No additional details", "short": False}
                    ]
                }]
            }
        
        try:
            response = requests.post(self.webhook_url, json=payload, timeout=10)
            if response.status_code == 200:
                self.last_alerts[alert_type] = now
                print(f"✅ Alert sent successfully: {alert_type}", flush=True)
            else:
                print(f"❌ Failed to send alert: {response.status_code}", flush=True)
        except Exception as e:
            print(f"❌ Error sending alert: {e}", flush=True)

    def check_failover(self, pool):
        if self.last_pool and self.last_pool != pool:
            # Create unique alert type for each direction to avoid cooldown conflicts
            alert_key = f"failover_{self.last_pool}_to_{pool}"
            message = f"Traffic failover from {self.last_pool.upper()} to {pool.upper()} pool"
            details = f"Previous pool ({self.last_pool.upper()}) likely experiencing issues. Check container health and logs immediately."
            self.send_slack_alert(message, alert_key, details)
            print(f"🔄 FAILOVER DETECTED: {self.last_pool} -> {pool}", flush=True)
        self.last_pool = pool

    def check_error_rate(self):
        if len(self.request_window) < 50:  # Need minimum requests
            return
            
        error_count = sum(1 for req in self.request_window if req.get('has_5xx', False))
        error_rate = (error_count / len(self.request_window)) * 100
        
        if error_rate > self.error_threshold:
            message = f"High upstream error rate detected: {error_rate:.1f}% (threshold: {self.error_threshold}%)"
            details = f"Analyzed {len(self.request_window)} requests, found {error_count} with 5xx errors. Check upstream application health and consider manual pool toggle."
            self.send_slack_alert(message, "error_rate", details)
            print(f"🚨 ERROR RATE ALERT: {error_rate:.1f}% over {len(self.request_window)} requests", flush=True)

    def tail_logs(self):
        log_file = '/var/log/nginx/access.log'
        
        # Wait for log file
        while not os.path.exists(log_file):
            print("Waiting for nginx log file...", flush=True)
            time.sleep(5)
            
        print(f"Tailing {log_file}", flush=True)
        
        try:
            # Read existing logs first, then follow new ones
            with open(log_file, 'r') as f:
                # Read existing content
                for line in f:
                    try:
                        parsed = self.parse_log_line(line.strip())
                        if parsed:
                            self.request_window.append(parsed)
                            self.check_failover(parsed['pool'])
                    except Exception as e:
                        print(f"Error processing existing line: {e}", flush=True)
                
                # Now follow new logs
                while True:
                    try:
                        line = f.readline()
                        if line:
                            parsed = self.parse_log_line(line.strip())
                            if parsed:
                                print(f"Parsed: pool={parsed['pool']}, has_5xx={parsed['has_5xx']}, window_size={len(self.request_window)}", flush=True)
                                self.request_window.append(parsed)
                                self.check_failover(parsed['pool'])
                                self.check_error_rate()
                        else:
                            time.sleep(0.1)
                    except Exception as e:
                        print(f"Error processing new line: {e}", flush=True)
                        time.sleep(1)
        except Exception as e:
            print(f"Fatal error in tail_logs: {e}", flush=True)
            time.sleep(5)
            self.tail_logs()  # Restart

if __name__ == "__main__":
    watcher = LogWatcher()
    watcher.tail_logs()