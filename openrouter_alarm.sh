#!/bin/bash
# OpenRouter credit alarm script

# Configuration
ALARM_THRESHOLDS=(10 5 4 3 2 1)  # Dollar thresholds
STATE_FILE="/home/thar/.openclaw/workspace/.openrouter_balance_state"
TELEGRAM_BOT_TOKEN="BOT_TOKEN_REVOKED"
TELEGRAM_CHAT_ID="101379704"

# Get OpenRouter balance (in credits)
get_balance() {
    local key_file="$HOME/.openrouter_key"
    if [ ! -f "$key_file" ]; then
        echo "Error: $key_file not found" >&2
        return 1
    fi
    local api_key=$(cat "$key_file")
    local response=$(curl -s -H "Authorization: Bearer $api_key" \
        https://openrouter.ai/api/v1/credits)
    echo "$response"
}

# Get USD to RUB exchange rate (using CBR API)
get_usd_rub_rate() {
    local rate=$(curl -s "https://www.cbr-xml-daily.ru/daily_json.js" | \
        jq -r '.Valute.USD.Value')
    if [ -z "$rate" ] || [ "$rate" = "null" ]; then
        # Fallback rate if API fails
        rate="90.0"
    fi
    echo "$rate"
}

# Format balance message
format_balance_message() {
    local balance="$1"
    local usd_rub_rate="$2"
    local threshold="$3"
    local mode="$4"  # "alarm" or "normal"
    local total_credits="$5"
    local total_usage="$6"
    
    local rubles=$(echo "scale=2; $balance * $usd_rub_rate" | bc -l)
    
    if [ "$mode" = "alarm" ]; then
        cat <<EOF
⚠️ <b>Внимание! Низкий баланс OpenRouter</b>

💰 Остаток: <code>$balance USD</code> (<code>$rubles RUB</code>)
📉 Ниже порога: <code>$threshold USD</code>

📈 Курс USD/RUB: <code>$usd_rub_rate</code> (ЦБ РФ)

🔗 Проверьте аккаунт: <a href="https://openrouter.ai/settings/credits">OpenRouter</a>
EOF
    else
        cat <<EOF
📊 <b>Баланс OpenRouter</b>

💰 Остаток: <code>$balance USD</code> (<code>$rubles RUB</code>)
📈 Курс USD/RUB: <code>$usd_rub_rate</code> (ЦБ РФ)

📊 Статистика:
├─ 📥 Куплено: <code>$total_credits USD</code>
├─ 📤 Использовано: <code>$total_usage USD</code>
└─ 💳 Осталось: <code>$balance USD</code>

🔗 Управление: <a href="https://openrouter.ai/settings/credits">OpenRouter</a>
EOF
    fi
}

# Send Telegram message
send_telegram_message() {
    local message="$1"
    curl -s -X POST \
        "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="${message}" \
        -d parse_mode="HTML"
}

# Main function
main() {
    # Get balance
    balance_json=$(get_balance)
    if [ -z "$balance_json" ]; then
        echo "Failed to get balance" >&2
        exit 1
    fi

    # Parse balance (remaining credits)
    total_credits=$(echo "$balance_json" | jq -r '.data.total_credits // .total_credits // 0')
    total_usage=$(echo "$balance_json" | jq -r '.data.total_usage // 0')
    balance=$(echo "$total_credits - $total_usage" | bc -l)
    if [ -z "$balance" ] || [ "$balance" = "null" ]; then
        echo "Failed to parse balance" >&2
        exit 1
    fi

    # Get exchange rate
    usd_rub_rate=$(get_usd_rub_rate)
    echo "Balance: $balance credits, USD/RUB rate: $usd_rub_rate"

    # Load previous state
    declare -A prev_state
    if [ -f "$STATE_FILE" ]; then
        while IFS='=' read -r key value; do
            prev_state["$key"]="$value"
        done < "$STATE_FILE"
    fi

    # Check thresholds
    changed=false
    for threshold in "${ALARM_THRESHOLDS[@]}"; do
        # Check if balance is below threshold and was above or equal before
        if (( $(echo "$balance < $threshold" | bc -l) )); then
            # Check previous state for this threshold
            prev_key="below_${threshold}"
            prev_below=${prev_state[$prev_key]:-0}
            if [ "$prev_below" -ne 1 ]; then
                # Format and send alarm
                message=$(format_balance_message "$balance" "$usd_rub_rate" "$threshold" "alarm" "$total_credits" "$total_usage")
                send_telegram_message "$message"
                echo "Sent alarm for threshold $threshold"
                prev_state[$prev_key]=1
                changed=true
            fi
        else
            # Reset state if balance is above threshold
            prev_key="below_${threshold}"
            prev_state[$prev_key]=0
        fi
    done

    # Save state if changed
    if [ "$changed" = true ]; then
        > "$STATE_FILE"
        for key in "${!prev_state[@]}"; do
            echo "$key=${prev_state[$key]}" >> "$STATE_FILE"
        done
    fi

    echo "Check completed"
}

# Run main
main
