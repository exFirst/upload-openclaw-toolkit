#!/usr/bin/env python3

import os
import sys
import imaplib
import email
from email.header import decode_header
import json

def load_env(mailbox):
    """Load IMAP environment from ~/.config/{mailbox}/imap.env"""
    env_path = os.path.expanduser(f"~/.config/{mailbox}/imap.env")
    if not os.path.exists(env_path):
        raise FileNotFoundError(f"Config not found: {env_path}")
    
    env = {}
    with open(env_path, 'r') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#'):
                if '=' in line:
                    key, val = line.split('=', 1)
                    env[key.strip()] = val.strip().strip('"\'')
    return env

def connect_imap(env):
    """Connect to IMAP server"""
    server = env.get('IMAP_SERVER', '')
    port = int(env.get('IMAP_PORT', '143'))
    user = env.get('IMAP_USER', '')
    password = env.get('IMAP_PASSWORD', '')
    
    if not server or not user or not password:
        raise ValueError("IMAP credentials incomplete")
    
    if port == 143:
        imap = imaplib.IMAP4(server, port)
        imap.starttls()
    else:
        imap = imaplib.IMAP4_SSL(server, port)
    
    imap.login(user, password)
    return imap

def decode_mime_header(header):
    """Decode MIME encoded header"""
    if header is None:
        return ''
    decoded_parts = decode_header(header)
    result = ''
    for part, encoding in decoded_parts:
        if isinstance(part, bytes):
            try:
                if encoding:
                    result += part.decode(encoding)
                else:
                    result += part.decode('utf-8', errors='ignore')
            except:
                result += part.decode('utf-8', errors='ignore')
        else:
            result += part
    return result

def mark_all_as_read(mailbox="thar@thar.su"):
    try:
        env = load_env(mailbox)
        imap = connect_imap(env)
        
        imap.select('INBOX')
        
        # Ищем непрочитанные письма
        status, data = imap.search(None, 'UNSEEN')
        if status != 'OK' or not data[0]:
            print("Нет непрочитанных писем.")
            imap.logout()
            return
        
        unseen_ids = data[0].split()
        print(f"Найдено непрочитанных писем: {len(unseen_ids)}")
        
        if not unseen_ids:
            print("Нет непрочитанных писем для отметки.")
            imap.logout()
            return
        
        # Пометка всех как прочитанных
        for msg_id in unseen_ids:
            imap.store(msg_id, '+FLAGS', '\\Seen')
        
        print(f"Помечено как прочитанных: {len(unseen_ids)} писем.")
        imap.logout()
        
    except Exception as e:
        print(f"Ошибка: {e}")
        sys.exit(1)

if __name__ == '__main__':
    mark_all_as_read()