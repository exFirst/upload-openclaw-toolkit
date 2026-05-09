#!/usr/bin/env python3

import os
import imaplib
import email
from email.header import decode_header

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

def main():
    mailbox = "thar@thar.su"
    
    try:
        env = load_env(mailbox)
        imap = connect_imap(env)
        
        imap.select('INBOX')
        
        # Получаем все UID писем в ящике
        status, data = imap.uid('search', None, 'ALL')
        if status != 'OK':
            print("Ошибка при поиске писем")
            imap.logout()
            return
        
        all_uids = data[0].split()
        total_emails = len(all_uids)
        
        print(f"Всего писем в ящике: {total_emails}")
        
        if all_uids:
            # Конвертируем в числа и сортируем
            sorted_uids = sorted([int(uid) for uid in all_uids])
            print(f"UID от {sorted_uids[0]} до {sorted_uids[-1]}")
            
            # Получаем последние 5 писем для примера
            last_uids = sorted_uids[-5:] if len(sorted_uids) >= 5 else sorted_uids
            
            for uid in last_uids:
                # Находим позицию этого письма в общем списке
                position = sorted_uids.index(uid) + 1  # +1 потому что нумерация с 1
                
                # Получаем информацию о письме
                _, msg_data = imap.uid('fetch', str(uid), '(BODY.PEEK[HEADER.FIELDS (SUBJECT FROM)])')
                if msg_data and msg_data[0] is not None:
                    raw_headers = msg_data[0][1]
                    msg = email.message_from_bytes(raw_headers)
                    
                    subject = decode_mime_header(msg.get('Subject', '(без темы)'))
                    from_ = decode_mime_header(msg.get('From', '(неизвестно)'))
                    
                    print(f"{position}. {from_} - {subject[:50]}...")
        
        imap.logout()
        
    except Exception as e:
        print(f"Ошибка: {e}")

if __name__ == '__main__':
    main()