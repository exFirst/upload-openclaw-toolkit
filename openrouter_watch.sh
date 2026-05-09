#!/bin/bash
# OpenRouter anomaly watch script
# Проверяет активность и уведомляет в Telegram о подозрительных расходах

set -a; source "$HOME/.secrets.env"; set +a

# Configuration
TELEGRAM_BOT_TOKEN="$TELEGRAM_THARCLAW_BOT"
TELEGRAM_CHAT_ID="101379704"
STATE_FILE="/home/thar/.openclaw/workspace/.openrouter_watch_state"
LOG_FILE="/home/thar/.openclaw/workspace/openrouter_watch.log"
LOOKBACK_HOURS=2

# Пороги аномалий
COST_THRESHOLD=0.10
PROMPT_THRESHOLD=60000
COMPLETION_THRESHOLD=60000
DAILY_THRESHOLD=3.0

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
logf() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

send_telegram() {
    curl -s -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="$1" \
        -d parse_mode="HTML" \
        -d disable_web_page_preview=true > /dev/null
}

main() {
    logf "Checking OpenRouter activity..."

    mgmt_key="$OPENROUTER_MANAGEMENT_KEY"
    if [[ -z "$mgmt_key" ]]; then
        logf "ERROR: Management key not found"
        exit 1
    fi

    response=$(curl -s -H "Authorization: Bearer $mgmt_key" \
        "https://openrouter.ai/api/v1/activity?limit=100")

    result=$(echo "$response" | python3 -c "
import json, sys
from datetime import datetime, timedelta, timezone

data = json.load(sys.stdin).get('data', [])
if not data:
    print('NO_DATA')
    sys.exit(0)

now = datetime.now(timezone.utc)
cutoff = now - timedelta(hours=$LOOKBACK_HOURS)
today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)

recent = []
for e in data:
    try:
        dt = datetime.strptime(e['date'][:19], '%Y-%m-%d %H:%M:%S').replace(tzinfo=timezone.utc)
        if dt > cutoff:
            recent.append(e)
    except:
        pass

alerts = []
total_cost = 0
total_pt = 0
total_ct = 0
total_reqs = 0

for e in recent:
    cost = e['usage']
    pt = e['prompt_tokens']
    ct = e['completion_tokens']
    total_cost += cost
    total_pt += pt
    total_ct += ct
    total_reqs += e['requests']
    
    anom_id = f\"{e['date']}|{e.get('model','?')}|{e.get('provider_name','?')}\"
    
    if cost >= $COST_THRESHOLD:
        alerts.append(('cost', anom_id, cost, pt, ct, e))
    if pt >= $PROMPT_THRESHOLD and cost >= 0.01:
        alerts.append(('prompt', anom_id, pt, pt, ct, e))
    if ct >= $COMPLETION_THRESHOLD:
        alerts.append(('completion', anom_id, ct, pt, ct, e))

total_cost_rounded = round(total_cost, 4)

print(f'STATS|{total_reqs}|{total_pt}|{total_ct}|{total_cost_rounded}')

for tag, anom_id, val, pt, ct, e in alerts:
    anom_key = anom_id.replace(' ', '_').replace('|', '_')
    cost_r = round(e['usage'], 4)
    print(f'ALERT|{tag}|{cost_r}|{pt}|{ct}|{e[\"requests\"]}|{e[\"date\"][:16]}|{e.get(\"model\",\"?\")}|{e.get(\"provider_name\",\"?\")}|{anom_key}')
")

    if [ "$result" = "NO_DATA" ]; then
        logf "No activity data"
        exit 0
    fi

    stats_line=$(echo "$result" | grep "^STATS|")
    alerts_text=$(echo "$result" | grep "^ALERT|")

    if [ -z "$stats_line" ]; then
        logf "Failed to parse activity"
        exit 1
    fi

    IFS='|' read -r _ total_reqs total_pt total_ct total_cost_v <<< "$stats_line"
    total_cost_v=$(echo "$total_cost_v" | tr -d ' ')

    declare -A sent_alerts
    if [ -f "$STATE_FILE" ]; then
        while IFS='=' read -r key val; do
            sent_alerts["$key"]="$val"
        done < "$STATE_FILE"
    fi

    # Проверяем аномалии
    new_alerts=()
    if [ -n "$alerts_text" ]; then
        while IFS='|' read -r _ tag cost_val pt_val ct_val reqs date_str model provider anom_key; do
            if [ "${sent_alerts[$anom_key]}" != "1" ]; then
                new_alerts+=("$tag|$cost_val|$pt_val|$ct_val|$reqs|$date_str|$model|$provider|$anom_key")
            fi
        done <<< "$alerts_text"
    fi

    if [ ${#new_alerts[@]} -gt 0 ]; then
        msg="<b>🚨 OpenRouter: обнаружены аномалии</b>\n\n"
        msg+="📊 За последние ${LOOKBACK_HOURS}ч: \$<code>${total_cost_v}</code> | ${total_reqs} запросов\n"
        msg+="   токенов: <code>${total_pt}</code>→<code>${total_ct}</code>\n\n"

        for alert in "${new_alerts[@]}"; do
            IFS='|' read -r tag cost_val pt_val ct_val reqs date_str model provider anom_key <<< "$alert"
            case "$tag" in
                cost) icon="💰" ;;
                prompt) icon="📥" ;;
                completion) icon="📤" ;;
                *) icon="⚠️" ;;
            esac
            msg+="${icon} <b>\$${cost_val}</b> | ${date_str}\n"
            msg+="   ${model} (${provider})\n"
            msg+="   ${reqs} reqs | токены: <code>${pt_val}</code>→<code>${ct_val}</code>\n\n"
        done

        send_telegram "$msg"
        logf "Sent alert: ${#new_alerts[@]} anomalies found"

        for alert in "${new_alerts[@]}"; do
            IFS='|' read -r tag cost_val pt_val ct_val reqs date_str model provider anom_key <<< "$alert"
            sent_alerts["$anom_key"]="1"
        done
    else
        logf "OK: no new anomalies (total: $total_cost_v)"
    fi

    # Проверка дневного расхода
    today_cost=$(echo "$response" | python3 -c "
import json, sys
from datetime import datetime, timezone
data = json.load(sys.stdin).get('data', [])
now = datetime.now(timezone.utc)
today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
total = sum(e['usage'] for e in data if 
    datetime.strptime(e['date'][:19], '%Y-%m-%d %H:%M:%S').replace(tzinfo=timezone.utc) >= today_start
) if data else 0
print(round(total, 4))
" 2>/dev/null || echo "0")

    if (( $(echo "$today_cost > $DAILY_THRESHOLD" | bc -l 2>/dev/null) )); then
        daily_sent="${sent_alerts[daily_alert]:-0}"
        if [ "$daily_sent" -eq 0 ]; then
            msg="<b>⚠️ OpenRouter: дневной расход превысил \$${DAILY_THRESHOLD}</b>\n\n"
            msg+="💰 Потрачено сегодня: <b>\$${today_cost}</b>\n"
            msg+="📉 Порог: \$${DAILY_THRESHOLD}\n\n"
            msg+="Проверить: <a href='https://openrouter.ai/activity'>OpenRouter Activity</a>"
            send_telegram "$msg"
            logf "Daily alert: today_cost=$today_cost > threshold=$DAILY_THRESHOLD"
            sent_alerts["daily_alert"]="1"
        fi
    else
        sent_alerts["daily_alert"]="0"
    fi

    # Сохраняем состояние
    > "$STATE_FILE"
    for key in "${!sent_alerts[@]}"; do
        echo "$key=${sent_alerts[$key]}" >> "$STATE_FILE"
    done

    logf "Check complete (today: $today_cost)"
}

main
