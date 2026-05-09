#!/usr/bin/env python3
"""
Modified mail-analyze with:
1. Global numbering based on position in entire mailbox
2. Translated subject in brackets
"""

import os
import sys
import imaplib
import email
from email.header import decode_header
from email.utils import parsedate_to_datetime
import datetime
import json
import argparse
import requests
import urllib.parse

# Telegram bot settings (to be configured)
TELEGRAM_BOT_TOKEN = ""
TELEGRAM_CHAT_ID = ""

STATE_FILE = os.path.expanduser("~/.config/mail-check-state.json")

def translate_subject(subject):
    """
    Simple translation using MyMemory Translation API
    Free tier: 1000 chars/day, no key needed
    """
    if not subject or len(subject.strip()) == 0:
        return subject
    
    # If subject already looks like Russian or mixed, skip translation
    # Very basic detection
    russian_chars = sum(1 for c in subject if '\u0400' <= c <= '\u04FF')
    if russian_chars > 2:  # If more than 2 Russian characters
        return subject  # Already in Russian
    
    try:
        # URL encode the text
        encoded = urllib.parse.quote(subject)
        url = f"https://api.mymemory.translated.net/get?q={encoded}&langpair=en|ru"
        
        response = requests.get(url, timeout=5)
        if response.status_code == 200:
            data = response.json()
            translated = data.get('responseData', {}).get('translatedText', '')
            if translated and translated != subject:
                return translated
    except Exception as e:
        print(f"Translation failed: {e}", file=sys.stderr)
    
    return subject  # Return original if translation fails

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

def get_email_body(msg):
    """Extract plain text body from email"""
    body = ""
    if msg.is_multipart():
        for part in msg.walk():
            content_type = part.get_content_type()
            content_disposition = str(part.get("Content-Disposition"))
            if content_type == "text/plain" and "attachment" not in content_disposition:
                try:
                    body = part.get_payload(decode=True).decode('utf-8', errors='ignore')
                except:
                    pass
                if body:
                    break
    else:
        try:
            body = msg.get_payload(decode=True).decode('utf-8', errors='ignore')
        except:
            pass
    return body[:1000]  # Limit for analysis

def categorize_email(subject, from_, body):
    """Categorize email based on content with irony"""
    subject_lower = subject.lower()
    from_lower = from_.lower()
    body_lower = body.lower()
    
    # Расширенные ключевые слова
    keywords_important = ["urgent", "important", "срочно", "важно", "требует внимания", 
                         "подтверждение", "активация", "инвойс", "счёт", "invoice", 
                         "payment", "оплата", "заказ", "order", "подтвердите", 
                         "требуется ответ", "response required"]
    
    keywords_personal = ["привет", "здравствуй", "дорогой", "уважаемый", "личное", 
                        "private", "семья", "друг", "friend", "родные", "коллега"]
    
    keywords_notification = ["уведомление", "notification", "alert", "напоминание", 
                           "reminder", "напоминаем", "информационное", "info", 
                           "системное", "system", "автоматическое"]
    
    keywords_marketing = ["распродажа", "скидка", "купи сейчас", "buy now", "предложение", 
                         "реклама", "promo", "newsletter", "акция", "специальное", 
                         "limited time", "только сегодня", "last chance", "sale", 
                         "discount", "offer", "deal", "предлагаем", "успей", 
                         "бесплатно", "free", "получите", "get your", "подпишитесь", 
                         "subscribe", "рассылка", "рассылки", "маркетинг", "marketing"]
    
    # Определяем по домену отправителя
    marketing_domains = ["appsumo.com", "mailchimp", "constantcontact", "getresponse", 
                        "sendinblue", "hubspot", "marketing", "promo", "sale", "deal"]
    
    for domain in marketing_domains:
        if domain in from_lower:
            return "marketing"
    
    # Проверяем важные
    for kw in keywords_important:
        if kw in subject_lower or kw in body_lower:
            return "important"
    
    # Личные
    for kw in keywords_personal:
        if kw in subject_lower or kw in body_lower:
            return "personal"
    
    # Уведомления
    for kw in keywords_notification:
        if kw in subject_lower or kw in from_lower or kw in body_lower:
            return "notification"
    
    # Маркетинговый мусор
    for kw in keywords_marketing:
        if kw in subject_lower or kw in body_lower:
            return "marketing"
    
    # Если не определили — помечаем как "прочее", но с иронией
    return "other"

def load_state():
    """Load last check state"""
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE, 'r') as f:
            return json.load(f)
    return {}

def save_state(mailbox, last_uid):
    """Save last UID for mailbox"""
    state = load_state()
    state[mailbox] = last_uid
    with open(STATE_FILE, 'w') as f:
        json.dump(state, f)

def get_last_uid(mailbox):
    """Get last processed UID for mailbox"""
    state = load_state()
    return state.get(mailbox, 0)

def get_all_uids(imap):
    """Get all UIDs in the mailbox and return sorted list"""
    status, data = imap.uid('search', None, 'ALL')
    if status != 'OK':
        return []
    
    if not data or not data[0]:
        return []
    
    # Convert to integers and sort
    uids = [int(uid) for uid in data[0].split()]
    return sorted(uids)

def analyze_mailbox(mailbox, since_days=1):
    """Main analysis function with global numbering"""
    env = load_env(mailbox)
    imap = connect_imap(env)
    
    imap.select('INBOX')
    
    # Get ALL UIDs in mailbox for global numbering
    all_uids = get_all_uids(imap)
    print(f"DEBUG: Total emails in mailbox: {len(all_uids)}", file=sys.stderr)
    
    # Create mapping from UID to position (1-based)
    uid_to_position = {uid: idx + 1 for idx, uid in enumerate(all_uids)}
    
    # Get last UID from state
    last_uid = get_last_uid(mailbox)
    
    # Search for new emails (since last UID or by date)
    if last_uid:
        _, data = imap.uid('search', None, f'UID {last_uid}:*')
    else:
        # Fallback: last 24 hours
        date_since = (datetime.datetime.now() - datetime.timedelta(days=since_days)).strftime('%d-%b-%Y')
        _, data = imap.uid('search', None, f'(SINCE {date_since})')
    
    uids = data[0].split()
    if not uids:
        print("No new emails")
        imap.logout()
        return []
    
    emails = []
    max_uid = 0
    
    for uid_str in uids[-20:]:  # Limit to recent 20
        uid = int(uid_str)
        if uid > max_uid:
            max_uid = uid
        
        # Get global position
        position = uid_to_position.get(uid, 0)
        if position == 0:
            print(f"DEBUG: UID {uid} not found in all_uids list", file=sys.stderr)
            continue
        
        # Получаем письмо с флагами, используя BODY.PEEK чтобы не менять статус \Seen
        _, msg_data = imap.uid('fetch', uid_str, '(BODY.PEEK[] FLAGS)')
        if not msg_data or msg_data[0] is None:
            continue
        
        # Проверяем, было ли письмо непрочитанным
        flags = msg_data[0][0].decode() if isinstance(msg_data[0][0], bytes) else msg_data[0][0]
        was_unseen = '\\Seen' not in flags
        
        raw_email = msg_data[0][1]
        msg = email.message_from_bytes(raw_email)
        
        subject = decode_mime_header(msg.get('Subject', '(без темы)'))
        from_ = decode_mime_header(msg.get('From', '(неизвестно)'))
        date_str = msg.get('Date', '')
        
        try:
            date = parsedate_to_datetime(date_str)
        except:
            date = datetime.datetime.now()
        
        body = get_email_body(msg)
        category = categorize_email(subject, from_, body)
        
        emails.append({
            'uid': uid,
            'position': position,  # Global position in mailbox
            'subject': subject,
            'from': from_,
            'date': date.strftime('%Y-%m-%d %H:%M'),
            'category': category,
            'body_preview': body[:200] + '...' if len(body) > 200 else body,
            'was_unseen': was_unseen
        })
    
    # Sort by position (ascending)
    emails.sort(key=lambda x: x['position'])
    
    if max_uid > last_uid:
        save_state(mailbox, max_uid)
    
    imap.logout()
    return emails

def format_summary(emails, mailbox):
    """Format summary with global numbering and translated subjects"""
    if not emails:
        return "📭 Отчёт по почте " + mailbox + "\nНет новых писем с момента последней проверки."
    
    by_category = {}
    for e in emails:
        cat = e['category']
        by_category.setdefault(cat, []).append(e)
    
    # Ироничные названия категорий
    cat_names = {
        'important': '🚨 Важные (надо глянуть)',
        'personal': '💬 Личные (люди пишут)',
        'notification': '🔔 Уведомления (системы шлют)',
        'marketing': '🗑️ Маркетинговый мусор',
        'other': '📧 Что-то ещё',
        'spam': '📭 Откровенный спам'
    }
    
    lines = ["📭 Отчёт по почте " + mailbox, ""]
    
    # Выводим только те категории, где есть письма
    for cat in ['important', 'personal', 'notification', 'marketing', 'other', 'spam']:
        if cat not in by_category:
            continue
        
        cat_rus = cat_names.get(cat, cat)
        lines.append(f"{cat_rus}:")
        
        # Нумеруем письма глобальной позицией
        for e in by_category[cat]:
            position = e['position']
            subject = e['subject']
            from_ = e['from']
            
            # Получаем перевод темы
            translated = translate_subject(subject)
            
            # Формируем строку
            if translated != subject:
                # Если перевод успешен, показываем оба варианта
                lines.append(f"{position}. {from_} тема \"{subject}\" ({translated})")
            else:
                # Если перевод не удался или тема уже на русском
                lines.append(f"{position}. {from_} тема \"{subject}\"")
        
        lines.append("")  # Пустая строка между категориями
    
    # Общее количество писем в отчёте
    total_emails = len(emails)
    lines.append(f"\nОбщее количество писем в отчёте: {total_emails}")
    
    return "\n".join(lines)

def main():
    parser = argparse.ArgumentParser(description="Analyze new emails and send summary")
    parser.add_argument('mailbox', help='Mailbox name (folder under ~/.config/)')
    parser.add_argument('--since-days', type=int, default=1, help='Days to look back if no state')
    
    args = parser.parse_args()
    
    try:
        emails = analyze_mailbox(args.mailbox, args.since_days)
        summary = format_summary(emails, args.mailbox)
        
        print(summary)
        
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()