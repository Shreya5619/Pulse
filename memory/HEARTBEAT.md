```jsonc
{
  // Interval in milliseconds for normal heartbeat
  "heartbeat_interval_ms": 300000,
  // Interval at night (screen off, low activity)
  "night_heartbeat_interval_ms": 900000,
  // Max auto actions per hour
  "max_auto_actions_per_hour": 3,
  // Whether guardian is allowed to auto-act on safe actions
  "allow_auto_safe_actions": true
}
```

# Heartbeat Modes
- **Day Mode**: Active monitoring every 5 minutes.
- **Night Mode**: Reduced frequency (every 15 minutes) to conserve resources.

# Escalation Rules
- If any risk > 0.8, run an immediate extra heartbeat.
- If battery < 15%, force Night Mode regardless of time.
- If user is in "Focus Path", escalate all communication risks.
