import telebot
import sqlite3
from telebot import types

# --- НАЛАШТУВАННЯ ---
API_TOKEN = '8721185581:AAENWANJby4ZhhVa97ppTAJ0MBAJwT7ILIE'
bot = telebot.TeleBot(API_TOKEN)

# --- БАЗА ДАНИХ ---
def get_db():
    conn = sqlite3.connect('neznay_bot.db', check_same_thread=False)
    return conn, conn.cursor()

conn, cursor = get_db()
cursor.execute('''CREATE TABLE IF NOT EXISTS users 
                  (user_id INTEGER PRIMARY KEY, name TEXT, age INTEGER, 
                   photo_id TEXT, who_am_i INTEGER DEFAULT 0, partner_id INTEGER DEFAULT 0)''')
cursor.execute('''CREATE TABLE IF NOT EXISTS queue (user_id INTEGER PRIMARY KEY)''')
conn.commit()

# --- КЛАВІАТУРИ ---
def main_menu():
    markup = types.ReplyKeyboardMarkup(resize_keyboard=True)
    markup.row("🔍 Знайти людину")
    markup.row("⚙️ Налаштування", "👤 Мій профіль")
    return markup

def stop_menu():
    markup = types.ReplyKeyboardMarkup(resize_keyboard=True)
    markup.add("🛑 Зупинити")
    return markup

def settings_menu(user_id):
    cursor.execute("SELECT who_am_i FROM users WHERE user_id=?", (user_id,))
    who_am_i = cursor.fetchone()[0]
    mode_text = "Включити 'Хто я'" if not who_am_i else "Вимкнути 'Хто я'"
    
    markup = types.ReplyKeyboardMarkup(resize_keyboard=True)
    markup.row("📸 Оновити фото")
    markup.row("✏️ Змінити ім'я", "🔢 Змінити вік")
    markup.row(mode_text)
    markup.row("⬅️ Назад")
    return markup

# --- ОБРОБКА КОМАНД ---

@bot.message_handler(commands=['start'])
def start(message):
    cursor.execute("SELECT * FROM users WHERE user_id=?", (message.from_user.id,))
    user = cursor.fetchone()
    if not user:
        msg = bot.send_message(message.chat.id, "Вітаю! Введіть ваше ім'я для реєстрації:")
        bot.register_next_step_handler(msg, reg_name)
    else:
        bot.send_message(message.chat.id, "Ти в меню!", reply_markup=main_menu())

def reg_name(message):
    name = message.text
    msg = bot.send_message(message.chat.id, f"Приємно познайомитись, {name}! Скільки тобі років?")
    bot.register_next_step_handler(msg, reg_age, name)

def reg_age(message, name):
    age = message.text
    cursor.execute("INSERT OR REPLACE INTO users (user_id, name, age) VALUES (?, ?, ?)", 
                   (message.from_user.id, name, age))
    conn.commit()
    bot.send_message(message.chat.id, "Реєстрація завершена!", reply_markup=main_menu())

# --- НАЛАШТУВАННЯ ТА ПРОФІЛЬ ---

@bot.message_handler(func=lambda m: m.text == "👤 Мій профіль")
def show_profile(message):
    cursor.execute("SELECT name, age, photo_id, who_am_i FROM users WHERE user_id=?", (message.from_user.id,))
    u = cursor.fetchone()
    txt = f"Твій профіль:\n👤 Ім'я: {u[0]}\n🔢 Вік: {u[1]}\n🎭 Анонімність: {'Так' if u[3] else 'Ні'}"
    if u[2]: bot.send_photo(message.chat.id, u[2], caption=txt)
    else: bot.send_message(message.chat.id, txt)

@bot.message_handler(func=lambda m: m.text == "⚙️ Налаштування")
def settings(message):
    bot.send_message(message.chat.id, "Налаштування:", reply_markup=settings_menu(message.from_user.id))

@bot.message_handler(func=lambda m: "Хто я" in m.text)
def toggle_anon(message):
    cursor.execute("SELECT who_am_i FROM users WHERE user_id=?", (message.from_user.id,))
    curr = cursor.fetchone()[0]
    new_val = 0 if curr else 1
    cursor.execute("UPDATE users SET who_am_i=? WHERE user_id=?", (new_val, message.from_user.id))
    conn.commit()
    bot.send_message(message.chat.id, "Режим змінено!", reply_markup=settings_menu(message.from_user.id))

@bot.message_handler(func=lambda m: m.text == "✏️ Змінити ім'я")
def change_name_step(message):
    msg = bot.send_message(message.chat.id, "Введіть нове ім'я:", reply_markup=types.ReplyKeyboardRemove())
    bot.register_next_step_handler(msg, save_name)

def save_name(message):
    cursor.execute("UPDATE users SET name=? WHERE user_id=?", (message.text, message.from_user.id))
    conn.commit()
    bot.send_message(message.chat.id, "Ім'я оновлено!", reply_markup=main_menu())

@bot.message_handler(func=lambda m: m.text == "🔢 Змінити вік")
def change_age_step(message):
    msg = bot.send_message(message.chat.id, "Введіть новий вік:", reply_markup=types.ReplyKeyboardRemove())
    bot.register_next_step_handler(msg, save_age)

def save_age(message):
    cursor.execute("UPDATE users SET age=? WHERE user_id=?", (message.text, message.from_user.id))
    conn.commit()
    bot.send_message(message.chat.id, "Вік оновлено!", reply_markup=main_menu())

@bot.message_handler(func=lambda m: m.text == "📸 Оновити фото")
def change_photo_step(message):
    msg = bot.send_message(message.chat.id, "Надішліть фото:")
    bot.register_next_step_handler(msg, save_photo)

def save_photo(message):
    if message.content_type == 'photo':
        cursor.execute("UPDATE users SET photo_id=? WHERE user_id=?", (message.photo[-1].file_id, message.from_user.id))
        conn.commit()
        bot.send_message(message.chat.id, "Фото збережено!", reply_markup=main_menu())
    else:
        bot.send_message(message.chat.id, "Це не фото. Спробуйте ще раз у налаштуваннях.")

# --- ПОШУК ТА ЧАТ ---

@bot.message_handler(func=lambda m: m.text == "🔍 Знайти людину")
def find(message):
    uid = message.from_user.id
    # Перевірка на чат
    cursor.execute("SELECT partner_id FROM users WHERE user_id=?", (uid,))
    if cursor.fetchone()[0] != 0:
        bot.send_message(message.chat.id, "Ви вже в чаті!", reply_markup=stop_menu())
        return

    # Шукаємо партнера
    cursor.execute("SELECT user_id FROM queue WHERE user_id != ? LIMIT 1", (uid,))
    partner = cursor.fetchone()

    if partner:
        pid = partner[0]
        cursor.execute("DELETE FROM queue WHERE user_id=?", (pid,))
        cursor.execute("UPDATE users SET partner_id=? WHERE user_id=?", (pid, uid))
        cursor.execute("UPDATE users SET partner_id=? WHERE user_id=?", (uid, pid))
        conn.commit()

        for user, target in [(uid, pid), (pid, uid)]:
            cursor.execute("SELECT name, age, photo_id, who_am_i FROM users WHERE user_id=?", (target,))
            data = cursor.fetchone()
            if data[3]:
                bot.send_message(user, "Знайдено аноніма! Пиши ✅", reply_markup=stop_menu())
            else:
                cap = f"Знайдено! 👤\nІм'я: {data[0]}, Вік: {data[1]}"
                if data[2]: bot.send_photo(user, data[2], caption=cap, reply_markup=stop_menu())
                else: bot.send_message(user, cap, reply_markup=stop_menu())
    else:
        cursor.execute("INSERT OR IGNORE INTO queue (user_id) VALUES (?)", (uid,))
        conn.commit()
        bot.send_message(message.chat.id, "Шукаю партнера... 🔍", reply_markup=stop_menu())

@bot.message_handler(func=lambda m: m.text == "🛑 Зупинити")
def stop(message):
    uid = message.from_user.id
    cursor.execute("DELETE FROM queue WHERE user_id=?", (uid,))
    cursor.execute("SELECT partner_id FROM users WHERE user_id=?", (uid,))
    partner = cursor.fetchone()
    
    if partner and partner[0] != 0:
        pid = partner[0]
        cursor.execute("UPDATE users SET partner_id=0 WHERE user_id IN (?, ?)", (uid, pid))
        conn.commit()
        bot.send_message(uid, "Чат зупинено. 🛑", reply_markup=main_menu())
        bot.send_message(pid, "Партнер зупинив чат. 🛑", reply_markup=main_menu())
    else:
        conn.commit()
        bot.send_message(message.chat.id, "Пошук скасовано.", reply_markup=main_menu())

@bot.message_handler(func=lambda m: m.text == "⬅️ Назад")
def back(message):
    bot.send_message(message.chat.id, "Головне меню", reply_markup=main_menu())

# --- ПЕРЕСИЛАННЯ ---
@bot.message_handler(content_types=['text', 'photo', 'video', 'sticker', 'voice'])
def forward(message):
    cursor.execute("SELECT partner_id FROM users WHERE user_id=?", (message.from_user.id,))
    partner = cursor.fetchone()
    if partner and partner[0] != 0:
        try:
            if message.text: bot.send_message(partner[0], message.text)
            elif message.photo: bot.send_photo(partner[0], message.photo[-1].file_id, caption=message.caption)
            elif message.sticker: bot.send_sticker(partner[0], message.sticker.file_id)
            elif message.voice: bot.send_voice(partner[0], message.voice.file_id)
            elif message.video: bot.send_video(partner[0], message.video.file_id, caption=message.caption)
        except:
            bot.send_message(message.chat.id, "Помилка відправки.")
    else:
        if message.text not in ["🔍 Знайти людину", "⚙️ Налаштування", "👤 Мій профіль"]:
            bot.send_message(message.chat.id, "Натисніть 'Пошук', щоб почати спілкування.")

bot.polling(none_stop=True)
