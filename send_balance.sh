#!/bin/bash
# Send formatted balance message to Telegram

# Config
TELEGRAM_BOT_TOKEN="BOT_TOKEN_REVOKED"
TELEGRAM_CHAT_ID="101379704"

# Get balance
balance_json=$(curl -s -H "Authorization: Bearer $(cat ~/.openrouter_key)" \
    https://openrouter.ai/api/v1/credits)
total_credits=$(echo "$balance_json" | jq -r '.data.total_credits // .total_credits // 0')
total_usage=$(echo "$balance_json" | jq -r '.data.total_usage // 0')
balance=$(echo "$total_credits - $total_usage" | bc -l)

# Get exchange rate
usd_rub_rate=$(curl -s "https://www.cbr-xml-daily.ru/daily_json.js" | jq -r '.Valute.USD.Value')
if [ -z "$usd_rub_rate" ] || [ "$usd_rub_rate" = "null" ]; then
    usd_rub_rate="74.69"
fi

# Calculate rubles
rubles=$(echo "scale=2; $balance * $usd_rub_rate" | bc -l)

# Format message with HTML
message="<b>📊 Баланс OpenRouter</b>

💰 Остаток: <code>$balance USD</code> (<code>$rubles RUB</code>)
📈 Курс USD/RUB: <code>$usd_rub_rate</code> (ЦБ РФ)

📊 Статистика:
├─ 📥 Куплено: <code>$total_credits USD</code>
├─ 📤 Использовано: <code>$total_usage USD</code>
└─ 💳 Осталось: <code>$balance USD</code>

🔗 Управление: <a href=\"https://openrouter.ai/settings/credits\">OpenRouter</a>"

# Send via Telegram API
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    -d text="${message}" \
    -d parse_mode="HTML" \
    -d disable_web_page_preview=true
