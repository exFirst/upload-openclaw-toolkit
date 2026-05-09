# OpenClaw Toolkit 🛠️

Полезные скрипты и инструменты для [OpenClaw](https://github.com/openclaw/openclaw).

## Состав

| Файл | Назначение |
|------|-----------|
| `stt_bot.py` | Speech-to-Text бот на Vosk (русский) для Telegram |
| `vosk_transcribe.py` | Транскрибация аудио через Vosk |
| `start_stt_bot.sh` | Скрипт запуска STT-бота |
| `stt-bot.service` | systemd unit для STT-бота |
| `mail-analyze-*.py` | Анализ почты с IMAP |
| `mark_as_read.py` | Пометка писем прочитанными |
| `openrouter_api.sh` | API-запросы к OpenRouter |
| `openrouter_alarm.sh` | Мониторинг баланса OpenRouter |
| `openrouter_watch.sh` | Наблюдение за балансом OpenRouter |
| `send_balance.sh` | Отправка баланса в Telegram |
| `check_gender.py` | Проверка склонений |
| `models.json` | Данные о моделях |

## Использование

Скрипты рассчитаны на Linux-окружение с Python 3 и Bash.

### STT-бот

```bash
./start_stt_bot.sh
```

### OpenRouter баланс

```bash
export OPENROUTER_API_KEY="sk-or-v1-..."
./openrouter_api.sh balance
```

## Лицензия

MIT — делайте что хотите.
