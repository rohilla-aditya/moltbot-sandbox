#!/bin/bash
# validate-config.sh
# Run this locally before deploying to catch config errors early.
# Usage: TELEGRAM_BOT_TOKEN=xxx TELEGRAM_DM_POLICY=allowlist TELEGRAM_ALLOWED_USERS=123 ./validate-config.sh

set -e

DEV_CONFIG_DIR="$HOME/.clawdbot-dev"
DEV_CONFIG_FILE="$DEV_CONFIG_DIR/clawdbot.json"
mkdir -p "$DEV_CONFIG_DIR"

echo "=== Moltbot Config Validator ==="
echo "Generating config from environment variables..."

node << 'EOFNODE'
const fs = require('fs');
const configPath = process.env.HOME + '/.clawdbot-dev/clawdbot.json';

let config = {};
try { config = JSON.parse(fs.readFileSync(configPath, 'utf8')); } catch {}

config.agents = config.agents || {};
config.agents.defaults = config.agents.defaults || {};
config.agents.defaults.model = config.agents.defaults.model || {};
config.gateway = config.gateway || {};
config.channels = config.channels || {};

// Same logic as start-moltbot.sh
config.gateway.port = 19001; // dev port
config.gateway.mode = 'local';

// Clean up known bad fields
if (config.channels?.telegram) {
    delete config.channels.telegram.dm;
    delete config.channels.telegram.allowlist;
}
if (config.channels?.discord) {
    delete config.channels.discord.dm;
    delete config.channels.discord.allowlist;
}

// Telegram
if (process.env.TELEGRAM_BOT_TOKEN) {
    const dmPolicy = process.env.TELEGRAM_DM_POLICY || 'allowlist';
    const tg = {
        botToken: process.env.TELEGRAM_BOT_TOKEN,
        enabled: true,
        dmPolicy,
    };
    if (dmPolicy === 'open') {
        tg.allowFrom = ['*'];
    } else if (dmPolicy === 'allowlist' && process.env.TELEGRAM_ALLOWED_USERS) {
        tg.allowFrom = process.env.TELEGRAM_ALLOWED_USERS.split(',').map(id => `tg:${id.trim()}`);
    }
    config.channels.telegram = tg;
}

// Discord
if (process.env.DISCORD_BOT_TOKEN) {
    config.channels.discord = {
        token: process.env.DISCORD_BOT_TOKEN,
        enabled: true,
        dmPolicy: process.env.DISCORD_DM_POLICY || 'pairing',
    };
}

config.agents.defaults.model.primary = 'anthropic/claude-opus-4-5';

fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
console.log('Generated config:');
console.log(JSON.stringify(config, null, 2));
EOFNODE

echo ""
echo "=== Running clawdbot doctor (dev profile) ==="
clawdbot --dev doctor --non-interactive 2>&1 || true

echo ""
echo "=== Attempting gateway dry-run (will start then stop) ==="
clawdbot --dev gateway --port 19001 &
GW_PID=$!
sleep 5

if kill -0 $GW_PID 2>/dev/null; then
    echo "✓ Gateway started successfully on port 19001"
    kill $GW_PID
    wait $GW_PID 2>/dev/null
    echo "✓ Config is valid - safe to deploy!"
else
    echo "✗ Gateway exited early - config has errors. Check output above."
    exit 1
fi
