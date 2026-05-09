# OpenClaw Toolkit 🛠️

A collection of practical scripts, utilities, and tools for [OpenClaw](https://github.com/openclaw/openclaw) — an open-source AI assistant gateway.

This toolkit grew out of real daily use: voice recognition, email analysis, API credit monitoring, and various quality-of-life automations. Everything is designed for Linux (Ubuntu/Debian) environments with Python 3 and Bash.

---

## 📦 Contents

### 🎤 Speech-to-Text (Vosk)

#### `stt_bot.py`
**Telegram bot for Russian speech recognition.** Uses the Vosk offline ASR engine (small Russian model, ~46 MB).

- Listens for voice messages in Telegram
- Downloads OGG audio, converts to 16 kHz mono WAV via ffmpeg
- Runs inference with `vosk.Model` and `KaldiRecognizer`
- Replies with recognized text
- Built with `python-telegram-bot` (v20+), supports concurrent updates

**Dependencies:** `vosk`, `python-telegram-bot`, `ffmpeg`

#### `vosk_transcribe.py`
**Command-line audio transcription tool.** Transcribes any audio file to text using the same Vosk model.

```bash
python vosk_transcribe.py recording.ogg
```

- Accepts any audio format ffmpeg can handle
- Auto-converts to 16 kHz mono PCM WAV
- Returns recognized text to stdout

#### `start_stt_bot.sh`
Shell launcher that activates the Python virtual environment (`vosk_env`) and starts the STT bot.

#### `stt-bot.service`
Systemd user service unit for running the STT bot as a persistent daemon with auto-restart on failure.

```bash
systemctl --user enable --now stt-bot.service
```

---

### 📧 Email Utilities

A family of scripts for IMAP email analysis and reporting. Designed for self-hosted mail servers with STARTTLS.

#### `mail-analyze-modified.py`
**Full-featured email analysis tool.** Connects to IMAP, fetches new emails, categorizes them, translates English subjects to Russian, and outputs a formatted summary.

Key features:
- Reads IMAP credentials from `~/.config/<mailbox>/imap.env`
- Supports both STARTTLS (port 143) and SSL (port 993)
- Tracks last processed UID in `~/.config/mail-check-state.json`
- Categorizes emails into: 🚨 Important, 💬 Personal, 🔔 Notifications, 🗑️ Marketing, 📧 Other
- Translates English subjects to Russian via MyMemory API
- Global sequential numbering across categories
- Limits to last 20 new emails per run

Usage:
```bash
python mail-analyze-modified.py thar@thar.su
```

#### `mail-analyze-global-num.py`
Similar to above but with global numbering based on absolute position in the mailbox (not category-relative). Useful when you need to reference emails by their position.

#### `mark_as_read.py`
**Quick IMAP connection test and mail counter.** Connects to a mailbox, counts total messages, scans UID range, and prints the last 5 emails with sender and subject. Useful for debugging IMAP connectivity.

#### `test_translate.py`
**Standalone translation test script** using LibreTranslate public API. Demonstrates the translation pipeline used by the mail analyzers.

```bash
python test_translate.py
```

#### `test_total.py`
**Lightweight email counter** that connects to IMAP, counts total messages, and shows the last 5 with sender info. Minimal dependencies — just `imaplib` and `email` from stdlib.

---

### 📊 OpenRouter API Tools

A set of Bash scripts for monitoring and managing [OpenRouter.ai](https://openrouter.ai) API credits and usage.

#### `openrouter_api.sh`
**Multi-function OpenRouter CLI.** Supports several commands:

```bash
./openrouter_api.sh balance          # Account balance
./openrouter_api.sh key [key]        # API key info
./openrouter_api.sh activity [n]     # Last N requests (requires management key)
./openrouter_api.sh watch [hours]    # Anomaly detection: expensive queries, spikes
./openrouter_api.sh models           # List models with pricing
./openrouter_api.sh generation <id>  # Details of a specific request
./openrouter_api.sh cost <id>        # Cost of a specific request
```

Reads `OPENROUTER_API_KEY` and `OPENROUTER_MANAGEMENT_KEY` from `~/.secrets.env`.

#### `openrouter_alarm.sh`
**Credit threshold alarm.** Runs periodically (e.g., via cron every 60 minutes) and sends a Telegram notification when the OpenRouter balance drops below predefined thresholds: $10, $5, $4, $3, $2, $1.

- Tracks which thresholds have been triggered in `.openrouter_balance_state`
- Fetches USD/RUB exchange rate from ЦБ РФ (Central Bank of Russia)
- Sends formatted messages with balance in both USD and RUB
- Sends each threshold alert only once (until balance recovers above it)

Designed to run via crontab:
```bash
*/60 * * * * /home/thar/.openclaw/workspace/openrouter_alarm.sh
```

#### `openrouter_watch.sh`
**Anomaly watch script.** Monitors recent OpenRouter activity and alerts via Telegram if it detects:
- Individual requests costing > $0.10
- Prompts or completions exceeding 60,000 tokens
- Total daily spend exceeding $3.00

Stores state in `.openrouter_watch_state`, logs to `openrouter_watch.log`.

#### `send_balance.sh`
**Single-shot balance reporter.** Fetches current OpenRouter balance and USD/RUB rate, formats a pretty HTML message, and sends it to Telegram. This is what runs when you ask "баланс".

```bash
./send_balance.sh
```

#### `models.json`
**Full OpenRouter model catalog** (417 KB) — a dump of all available models with pricing, context lengths, and capabilities.

---

### 🔧 Quality-of-Life Tools

#### `check_gender.py`
**Russian gender agreement checker.** Scans text for masculine past-tense verb endings (`-л`, `-ил`, `-ел`, `-лся`) and suggests feminine alternatives (`-ла`, `-ила`, `-ела`, `-лась`). Used as a pre-flight check before sending messages in Russian to ensure consistent feminine grammatical gender.

```bash
echo "я сделал это" | python check_gender.py
# ⚠️  ОБНАРУЖЕНЫ МУЖСКИЕ ОКОНЧАНИЯ!
# ❌ Мужской глагол: 'сделал'
#    ✅ Замени на: 'сделала'
```

Covers 80+ verb pairs including reflexive forms.

#### `CHECK.md`
Personal pre-flight checklist for Telegram messaging: gender checks, formatting rules (no markdown tables, use middle dots), style guidelines, and a 4-point final verification.

---

## 🚀 Installation

### Prerequisites

- Python 3.8+
- Bash 4+
- ffmpeg (for audio processing)
- Git

### Setup

1. **Clone the repo:**
   ```bash
   git clone https://github.com/exFirst/upload-openclaw-toolkit.git
   cd upload-openclaw-toolkit
   ```

2. **Install Python dependencies:**
   ```bash
   pip install vosk python-telegram-bot requests
   ```

3. **Download Vosk model** (for STT features):
   ```bash
   wget https://alphacephei.com/vosk/models/vosk-model-small-ru-0.22.zip
   unzip vosk-model-small-ru-0.22.zip -d ~/vosk_models/
   ```

4. **Set up IMAP credentials** (for email tools):
   Create `~/.config/<mailbox>/imap.env`:
   ```
   IMAP_SERVER=mail.example.com
   IMAP_PORT=143
   IMAP_USER=user@example.com
   IMAP_PASSWORD=yourpassword
   ```

5. **Set up OpenRouter API key:**
   ```bash
   echo "sk-or-v1-your-key-here" > ~/.openrouter_key
   ```

### Running as Services

**STT Bot (systemd user service):**
```bash
cp stt-bot.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now stt-bot.service
```

**OpenRouter alarm (cron):**
```bash
crontab -e
# Add:
*/60 * * * * /path/to/openrouter_alarm.sh
```

---

## 📁 File Overview

```
├── stt_bot.py                  # Telegram voice-to-text bot (Vosk)
├── vosk_transcribe.py          # CLI audio transcription
├── start_stt_bot.sh            # STT bot launcher
├── stt-bot.service             # systemd user service unit
├── mail-analyze-modified.py    # Full email analysis (categorized + translated)
├── mail-analyze-global-num.py  # Email analysis with global numbering
├── mark_as_read.py             # IMAP connection test & counter
├── test_translate.py           # Translation API test
├── test_total.py               # Lightweight email counter
├── openrouter_api.sh           # Multi-function OpenRouter CLI
├── openrouter_alarm.sh         # Credit threshold alerts → Telegram
├── openrouter_watch.sh         # Anomaly detection for API usage
├── send_balance.sh             # Balance reporter → Telegram
├── models.json                 # OpenRouter model catalog
├── check_gender.py             # Russian gender agreement checker
├── CHECK.md                    # Messaging pre-flight checklist
├── .gitignore                  # Excludes personal/identity files
└── README.md                   # This file
```

---

## 📜 License

MIT — do whatever you want with it. Contributions welcome.

---

## 🙏 Acknowledgments

- **[Vosk](https://alphacephei.com/vosk/)** by Alpha Cephei — offline speech recognition that actually works on modest hardware
- **[OpenRouter](https://openrouter.ai/)** — unified API gateway for 200+ LLMs with transparent pricing
- **[python-telegram-bot](https://github.com/python-telegram-bot/python-telegram-bot)** — the most solid Telegram Bot framework for Python
- **[ffmpeg](https://ffmpeg.org/)** — the Swiss Army knife of audio/video processing
- **[MyMemory](https://mymemory.translated.net/)** and **[LibreTranslate](https://libretranslate.com/)** — free translation APIs that make the mail tools bilingual
- **[ЦБ РФ](https://www.cbr.ru/)** — for the reliable USD/RUB exchange rate API

Built for personal use, shared in case it's useful to someone else. Pull requests and issues welcome! ✨
