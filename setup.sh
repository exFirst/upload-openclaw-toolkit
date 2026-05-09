#!/bin/bash
# Zipline first-time setup script
# Run after "docker compose up -d" to create admin account
# Usage: ./setup.sh

set -e

ZIPLINE_URL="${ZIPLINE_URL:-http://localhost:3000}"
ADMIN_USER="${ADMIN_USER:-admin}"
ADMIN_PASS="${ADMIN_PASS:-$(openssl rand -base64 12)}"

echo "=== Zipline Setup ==="
echo "URL:     $ZIPLINE_URL"
echo "User:    $ADMIN_USER"
echo ""

# Wait for Zipline to be ready
echo "⏳ Waiting for Zipline..."
for i in $(seq 1 30); do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" "$ZIPLINE_URL/api/healthcheck" 2>/dev/null)
  if [ "$CODE" = "200" ] || [ "$CODE" = "204" ]; then
    echo "   ✅ Ready (HTTP $CODE)"
    break
  fi
  if [ "$i" = "30" ]; then
    echo "   ❌ Timed out waiting for Zipline"
    exit 1
  fi
  sleep 2
done

# Check if already set up
EXISTING=$(curl -s "$ZIPLINE_URL/api/setup" 2>/dev/null)
IS_FIRST=$(echo "$EXISTING" | python3 -c "import sys,json; print(json.load(sys.stdin).get('firstSetup',False))" 2>/dev/null)

if [ "$IS_FIRST" = "False" ]; then
  echo "⚠️  Zipline already has an admin user."
  echo "   Login at $ZIPLINE_URL/auth/login"
  exit 0
fi

# Create admin user
echo "👤 Creating admin user..."
RESULT=$(curl -s -X POST "$ZIPLINE_URL/api/setup" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$ADMIN_USER\",\"password\":\"$ADMIN_PASS\"}")

USER_ID=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('user',{}).get('id',''))" 2>/dev/null)
ROLE=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('user',{}).get('role',''))" 2>/dev/null)

if [ -n "$USER_ID" ]; then
  echo "   ✅ Admin user created!"
  echo "   ID:   $USER_ID"
  echo "   Role: $ROLE"
  echo ""
  echo "   ┌─────────────────────────────────────────────┐"
  echo "   │  URL:   $ZIPLINE_URL"
  echo "   │  Login: $ADMIN_USER"
  echo "   │  Pass:  $ADMIN_PASS"
  echo "   └─────────────────────────────────────────────┘"
  echo ""
  echo "Save these credentials securely!"
else
  echo "   ❌ Failed: $(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('error','unknown'))" 2>/dev/null)"
  exit 1
fi
