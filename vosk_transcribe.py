#!/usr/bin/env python3
"""
Transcribe audio file using Vosk (Russian model).
Usage: python vosk_transcribe.py <audio_file>
"""

import os
import sys
import json
import subprocess
import tempfile
from vosk import Model, KaldiRecognizer, SetLogLevel

# Set Vosk log level to 0 (silent)
SetLogLevel(0)

MODEL_PATH = "/home/thar/vosk_models/vosk-model-small-ru-0.22"

def transcribe_audio(audio_path: str) -> str:
    """Transcribe audio file to text using Vosk."""
    # Load model
    model = Model(MODEL_PATH)
    
    # Check if audio is in correct format (16kHz mono WAV)
    # If not, convert using ffmpeg
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as wav_file:
        wav_path = wav_file.name
    
    try:
        # Convert to 16kHz mono WAV using ffmpeg
        subprocess.run([
            "ffmpeg", "-i", audio_path,
            "-ar", "16000", "-ac", "1",
            "-f", "wav", wav_path,
            "-y"
        ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        
        # Recognize speech
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
            res_dict = json.loads(result)
            if "text" in res_dict:
                text_parts.append(res_dict["text"])
        
        text = " ".join(text_parts).strip()
        return text
        
    finally:
        # Clean up temp file
        if os.path.exists(wav_path):
            os.unlink(wav_path)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python vosk_transcribe.py <audio_file>")
        sys.exit(1)
    
    audio_file = sys.argv[1]
    if not os.path.exists(audio_file):
        print(f"Error: File '{audio_file}' not found")
        sys.exit(1)
    
    try:
        transcript = transcribe_audio(audio_file)
        print(transcript)
    except Exception as e:
        print(f"Error: {str(e)}", file=sys.stderr)
        sys.exit(1)