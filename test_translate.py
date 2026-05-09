#!/usr/bin/env python3

import requests
import json

def translate_text(text, target_lang='ru'):
    """
    Простой перевод через LibreTranslate (открытый сервис)
    Используем публичный инстанс libretranslate.com
    """
    try:
        url = "https://libretranslate.com/translate"
        payload = {
            'q': text,
            'source': 'auto',
            'target': target_lang,
            'format': 'text'
        }
        headers = {'Content-Type': 'application/json'}
        
        # Упрощённый запрос
        response = requests.post(url, data=json.dumps(payload), headers=headers, timeout=10)
        if response.status_code == 200:
            data = response.json()
            return data.get('translatedText', text)
        else:
            return text
    except Exception as e:
        print(f"Translation error: {e}")
        return text

# Тест
if __name__ == '__main__':
    test_text = "DNS records have changed or been updated for sssss.su"
    translated = translate_text(test_text)
    print(f"Original: {test_text}")
    print(f"Translated: {translated}")