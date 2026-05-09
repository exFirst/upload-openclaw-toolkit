#!/bin/bash
# OpenRouter API helper script
# Использует централизованное хранилище ~/.secrets.env

set -a; source "$HOME/.secrets.env"; set +a

# ---- Вспомогательные функции ----

usage() {
    cat <<EOF
Usage: $0 {balance|key|activity|watch|models|generation|cost}

  balance                       — Баланс аккаунта (любой ключ)
  key [key]                     — Информация о ключе
  activity [limit=10]           — История запросов (требует management key)
  watch [hours=1] [threshold=]  — Поиск аномалий: дорогие запросы и всплески
  models                        — Список моделей с ценами
  generation <id>               — Детали конкретного запроса
  cost <id>                     — Стоимость конкретного запроса

Требуется management key для activity и watch.

EOF
    exit 1
}

# ---- Команды ----

api_key="$OPENROUTER_API_KEY"
mgmt_key="$OPENROUTER_MANAGEMENT_KEY"

case "${1:-help}" in
    balance)
        echo "=== Баланс OpenRouter ==="
        curl -s -H "Authorization: Bearer $api_key" \
            https://openrouter.ai/api/v1/credits | python3 -c "
import json, sys
d = json.load(sys.stdin)['data']
bal = round(d['total_credits'] - d['total_usage'], 2)
print(f'Остаток: {bal} USD')
print(f'Куплено всего: {d[\"total_credits\"]} USD')
print(f'Использовано: {round(d[\"total_usage\"], 4)} USD')
"

        # Самый дорогой запрос за последние сутки
        if [[ -n "$mgmt_key" ]]; then
            curl -s -H "Authorization: Bearer $mgmt_key" \
                "https://openrouter.ai/api/v1/activity?limit=100" | python3 -c "
import json, sys
from datetime import datetime, timedelta, timezone

data = json.load(sys.stdin).get('data', [])
if not data:
    print(f'')
    print(f'📭 За последние 12ч активности не было')
    sys.exit(0)

now = datetime.now(timezone.utc)
cutoff = now - timedelta(hours=12)

recent = [(e, datetime.strptime(e['date'][:19], '%Y-%m-%d %H:%M:%S').replace(tzinfo=timezone.utc))
    for e in data if e['usage'] > 0]
recent = [(e, dt) for e, dt in recent if dt >= cutoff]

print(f'')
if not recent:
    print(f'📭 За последние 12ч активности не было')
else:
    top = max(recent, key=lambda x: x[0]['usage'])[0]
    model = top.get('model', '?')
    cost = round(top['usage'], 4)
    pt = top['prompt_tokens']
    ct = top['completion_tokens']
    reqs = top['requests']
    provider = top.get('provider_name', '?')
    date = top['date'][:16]

    print(f'🏆 Самый дорогой запрос за 12ч:')
    print(f'   {date} | {model} ({provider})')
    print(f'   {reqs} reqs | токены: {pt:,}→{ct:,} | \${cost}')
"
        fi
        ;;

    key)
        [[ -n "$2" ]] && use_key="$2" || use_key="$api_key"
        echo "=== Информация о ключе ==="
        curl -s -H "Authorization: Bearer $use_key" \
            https://openrouter.ai/api/v1/auth/key | python3 -c "
import json, sys
d = json.load(sys.stdin)['data']
print(f'Метка: {d[\"label\"]}')
print(f'Management: {\"✅ да\" if d[\"is_management_key\"] else \"❌ нет\"}')
print(f'Provisioning: {\"✅ да\" if d[\"is_provisioning_key\"] else \"❌ нет\"}')
print(f'Free tier: {\"✅ да\" if d[\"is_free_tier\"] else \"❌ нет\"}')
print(f'Лимит: {d[\"limit\"] or \"безлимит\"}')
print(f'Истёк: {d[\"expires_at\"] or \"никогда\"}')
print(f'')
print(f'Использовано за сегодня: {d[\"usage_daily\"]} USD')
print(f'Использовано за неделю: {d[\"usage_weekly\"]} USD')
print(f'Использовано за месяц: {d[\"usage_monthly\"]} USD')
"
        ;;

    activity)
        limit="${2:-10}"
        if [[ -z "$mgmt_key" ]]; then
            echo "❌ Management key не найден в ~/.secrets.env"
            exit 1
        fi
        echo "=== Активность (последние $limit записей) ==="
        curl -s -H "Authorization: Bearer $mgmt_key" \
            "https://openrouter.ai/api/v1/activity?limit=$limit" | python3 -c "
import json, sys
data = json.load(sys.stdin).get('data', [])
if not data:
    print('Нет данных')
    sys.exit(0)

total = 0
for e in data:
    date = e['date'][:10]
    model = e.get('model', '?')
    cost = round(e['usage'], 4)
    reqs = e['requests']
    ptokens = e['prompt_tokens']
    ctokens = e['completion_tokens']
    provider = e.get('provider_name', '?')
    print(f'{date} | {model} | {provider}')
    print(f'      {reqs} reqs | tokens: {ptokens}→{ctokens} | cost: \${cost}')
    total += cost

print()
print(f'📊 Итого за период: \${round(total, 4)}')
"
        ;;

    models)
        echo "=== Модели OpenRouter ==="
        curl -s https://openrouter.ai/api/v1/models | python3 -c "
import json, sys
data = json.load(sys.stdin).get('data', [])
if not data:
    data = json.load(sys.stdin)
print(f'Всего моделей: {len(data)}')
print()
# Топ-20 по популярности (сортируем по контексту)
models = sorted(data, key=lambda m: m.get('context_length', 0), reverse=True)[:20]
for m in models:
    name = m.get('id', '?')
    ctx = m.get('context_length', '?')
    pricing = m.get('pricing', {})
    prompt_cost = pricing.get('prompt', '?')
    comp_cost = pricing.get('completion', '?')
    print(f'{name}')
    print(f'  контекст: {ctx} токенов | prompt: \${prompt_cost}/1k | completion: \${comp_cost}/1k')
" 2>/dev/null || curl -s https://openrouter.ai/api/v1/models | python3 -c "
import json, sys
data = json.load(sys.stdin)
if isinstance(data, list):
    print(f'Всего моделей: {len(data)}')
else:
    d = data.get('data', [])
    print(f'Всего моделей: {len(d)}')
keys = list(data.keys()) if isinstance(data, dict) else ['unknown']
print(f'Ключи ответа: {keys}')
"
        ;;

    generation)
        id="$2"
        if [[ -z "$id" ]]; then
            echo "❌ Укажи ID генерации: $0 generation <id>"
            exit 1
        fi
        echo "=== Генерация $id ==="
        curl -s -H "Authorization: Bearer $api_key" \
            "https://openrouter.ai/api/v1/generation?id=$id" | python3 -c "
import json, sys
d = json.load(sys.stdin)
if 'data' in d:
    d = d['data']
print(json.dumps(d, indent=2, ensure_ascii=False)[:3000])
"
        ;;

    cost)
        id="$2"
        if [[ -z "$id" ]]; then
            echo "❌ Укажи ID генерации: $0 cost <id>"
            exit 1
        fi
        echo "=== Стоимость генерации $id ==="
        curl -s -H "Authorization: Bearer $api_key" \
            "https://openrouter.ai/api/v1/generation?id=$id" | python3 -c "
import json, sys
d = json.load(sys.stdin)
if 'data' in d:
    d = d['data']
total = d.get('total_cost', d.get('usage', d.get('cost', '?')))
model = d.get('model', '?')
tokens_in = d.get('prompt_tokens', '?')
tokens_out = d.get('completion_tokens', '?')
print(f'Модель: {model}')
print(f'Токенов: {tokens_in} → {tokens_out}')
print(f'Стоимость: \${total}')
"
        ;;

    watch)
        hours="${2:-1}"
        cost_threshold="${3:-0.50}"
        if [[ -z "$mgmt_key" ]]; then
            echo "❌ Management key не найден в ~/.secrets.env"
            exit 1
        fi
        
        # Берём activity с запасом
        curl -s -H "Authorization: Bearer $mgmt_key" \
            "https://openrouter.ai/api/v1/activity?limit=200" | python3 -c "
import json, sys
from datetime import datetime, timedelta, timezone

data = json.load(sys.stdin).get('data', [])
if not data:
    print('Нет данных')
    sys.exit(0)

now = datetime.now(timezone.utc)
hours = $hours
cutoff = now - timedelta(hours=hours)

# Фильтруем по времени
recent = []
for e in data:
    try:
        dt = datetime.strptime(e['date'][:19], '%Y-%m-%d %H:%M:%S').replace(tzinfo=timezone.utc)
        if dt > cutoff:
            recent.append(e)
    except:
        pass

cost_threshold = $cost_threshold

print(f'🔍 Анализ за последние {hours} ч.')
print()

# --- Сводка ---
total_cost = 0
total_pt = 0
total_ct = 0
total_reqs = 0
by_model = {}
for e in recent:
    total_cost += e['usage']
    total_pt += e['prompt_tokens']
    total_ct += e['completion_tokens']
    total_reqs += e['requests']
    m = e.get('model', '?')
    by_model[m] = by_model.get(m, 0) + e['usage']

print(f'📊 Сводка')
print(f'   Запросов: {total_reqs}')
print(f'   Промпт-токенов: {total_pt:,}')
print(f'   Ответ-токенов: {total_ct:,}')
print(f'   Потрачено: \${round(total_cost, 4)}')
print()

# --- Аномалии ---
alerts = []
for e in recent:
    cost = e['usage']
    pt = e['prompt_tokens']
    ct = e['completion_tokens']
    
    if cost >= cost_threshold:
        alerts.append(('💰 ДОРОГО', cost, e))
    if pt >= 100000:
        alerts.append(('📥 МНОГО ПРОМПТ', pt, e))
    if ct >= 20000:
        alerts.append(('📤 МНОГО ОТВЕТ', ct, e))

if alerts:
    # Сортируем по severity
    alerts.sort(key=lambda x: -x[1])
    print(f'🚨 Найдено {len(alerts)} аномалий')
    print()
    for tag, val, e in alerts[:15]:
        date = e['date'][:16]
        model = e.get('model', '?')
        prov = e.get('provider_name', '?')
        reqs = e['requests']
        pt = e['prompt_tokens']
        ct = e['completion_tokens']
        cost = round(e['usage'], 4)
        print(f'{tag} \${cost}')
        print(f'   {date} | {model} | {prov}')
        print(f'   {reqs} reqs | токены: {pt:,}→{ct:,}')
        print()
else:
    print('✅ Аномалий не обнаружено')
    print()

# --- По моделям ---
print('📈 По моделям:')
for m, c in sorted(by_model.items(), key=lambda x: -x[1]):
    bar = '█' * max(1, int(c * 20 / max(by_model.values())))
    print(f'   {bar} {m}: \${round(c, 4)}')
"
        ;;

    help|--help|-h)
        usage
        ;;

    *)
        usage
        ;;
esac
