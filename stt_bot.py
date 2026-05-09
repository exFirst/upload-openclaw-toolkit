#!/usr/bin/env python3
# STT bot for Telegram using Vosk
# Usage: python stt_bot.py

import os
import subprocess
import tempfile
from vosk import Model, KaldiRecognizer, SetLogLevel
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters, ContextTypes

# Set Vosk log level to 0 (silent)
SetLogLevel(0)

# Telegram bot token (replace with your own)
BOT_TOKEN = "BOT_TOKEN_REVOKED"

# Path to Vosk model (small Russian model)
MODEL_PATH = "/home/thar/vosk_models/vosk-model-small-ru-0.22"

# Initialize Vosk model
print("Loading Vosk model...")
model = Model(MODEL_PATH)
print("Model loaded.")

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Send a message when the command /start is issued."""
    await update.message.reply_text(
        "Привет! Я бот для распознавания речи. "
        "Отправь мне голосовое сообщение, и я верну текст."
    )

async def handle_voice(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """Handle voice messages."""
    try:
        # Get voice file
        voice = update.message.voice
        file = await context.bot.get_file(voice.file_id)
        
        # Download voice file (OGG format)
        with tempfile.NamedTemporaryFile(delete=False, suffix=".ogg") as ogg_file:
            ogg_path = ogg_file.name
            await file.download_to_drive(ogg_path)
        
        # Convert OGG to WAV (16kHz, mono, PCM)
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as wav_file:
            wav_path = wav_file.name
        
        # Use ffmpeg to convert
        subprocess.run([
            "ffmpeg", "-i", ogg_path, "-ar", "16000", "-ac", "1", "-f", "wav", wav_path, "-y"
        ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        # Recognize speech with Vosk
        wf = open(wav_path, "rb")
        rec = KaldiRecognizer(model, 16000)
        rec.SetWords(True)
        
        results = []
        while True:
            data = wf.read(4000)
            if len(data) == 0:
                break
            if rec.AcceptWaveform(data):
                result = rec.Result()
                if result:
                    results.append(result)
        
        # Get final result
        final = rec.FinalResult()
        if final:
            results.append(final)
        
        wf.close()
        
        # Parse results
        text_parts = []
        for result in results:
            import json
            res_dict = json.loads(result)
            if "text" in res_dict:
                text_parts.append(res_dict["text"])
        
        text = " ".join(text_parts).strip()
        
        # Clean up temp files
        os.unlink(ogg_path)
        os.unlink(wav_path)
        
        if text:
            await update.message.reply_text(f"Распознано: {text}")
        else:
            await update.message.reply_text("Не удалось распознать речь. Попробуйте еще раз.")
    
    except Exception as e:
        await update.message.reply_text(f"Ошибка: {str(e)}")
        print(f"Error: {e}")

def main():
    """Start the bot."""
    # Create the Application with concurrent updates
    application = Application.builder().token(BOT_TOKEN).concurrent_updates(True).build()
    
    # Add handlers
    application.add_handler(CommandHandler("start", start))
    application.add_handler(MessageHandler(filters.VOICE, handle_voice))
    
    # Start the bot
    print("Bot started...")
    application.run_polling(
        allowed_updates=Update.ALL_TYPES,
        drop_pending_updates=True
    )

if __name__ == "__main__":
    main()