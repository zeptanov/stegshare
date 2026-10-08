import tkinter as tk
from tkinter import messagebox
from pathlib import Path
import pyperclip


# ============================================================
# Создание файла
# ============================================================

def create_file():
    try:
        # Получаем путь
        path_text = path_entry.get().strip()

        if not path_text:
            messagebox.showwarning(
                "Нет пути",
                "Укажи путь к файлу."
            )
            return

        # Получаем содержимое буфера обмена
        try:
            content = pyperclip.paste().replace("\r\n", "\n")
        except Exception as e:
            messagebox.showerror(
                "Ошибка буфера",
                f"Не удалось получить содержимое буфера:\n\n{e}"
            )
            return

        if not content:
            messagebox.showwarning(
                "Буфер пуст",
                "В буфере обмена нет текста."
            )
            return

        if path_text.startswith("mobile/"):
            path_text = f"app/{path_text[7:]}"  # Удаляем "mobile/" из начала строки


        # Создаём объект пути
        file_path = Path(path_text)

        # Папка, в которой должен находиться файл
        parent_folder = file_path.parent

        # Если указана папка — создаём её
        if str(parent_folder) not in ("", "."):
            parent_folder.mkdir(
                parents=True,
                exist_ok=True
            )

        # Создаём / перезаписываем файл
        file_path.write_text(
            content,
            encoding="utf-8"
        )

        # Показываем результат
        status_label.config(
            text=f"✓ Создан: {file_path.resolve()}",
            fg="#3f6544"
        )

    except Exception as e:
        messagebox.showerror(
            "Ошибка",
            f"Не удалось создать файл:\n\n{e}"
        )

        status_label.config(
            text="✕ Ошибка создания файла",
            fg="#a94442"
        )


# ============================================================
# Интерфейс
# ============================================================

root = tk.Tk()

root.title("Clipboard → File")
root.geometry("680x270")
root.resizable(False, False)

BG = "#f3f0e8"
TEXT = "#252522"
MUTED = "#77746c"
ACCENT = "#596b4f"
ACCENT_HOVER = "#4d6045"
INPUT_BG = "#ffffff"

root.configure(bg=BG)


# Заголовок
tk.Label(
    root,
    text="Clipboard → File",
    font=("Segoe UI", 21, "bold"),
    bg=BG,
    fg=TEXT
).pack(
    anchor="w",
    padx=30,
    pady=(25, 2)
)


tk.Label(
    root,
    text="Скопируй код → укажи путь → нажми кнопку",
    font=("Segoe UI", 10),
    bg=BG,
    fg=MUTED
).pack(
    anchor="w",
    padx=32,
    pady=(0, 20)
)


# ============================================================
# Поле пути
# ============================================================

path_frame = tk.Frame(
    root,
    bg=BG
)

path_frame.pack(
    fill="x",
    padx=30
)


path_entry = tk.Entry(
    path_frame,
    font=("Segoe UI", 11),
    bg=INPUT_BG,
    fg=TEXT,
    relief="flat",
    bd=0,
    insertbackground=TEXT
)

path_entry.pack(
    side="left",
    fill="x",
    expand=True,
    ipady=11,
    padx=12
)

path_entry.insert(
    0,
    "backend/pyproject.toml"
)


# ============================================================
# Кнопка создания
# ============================================================

create_button = tk.Button(
    root,
    text="Создать файл из буфера",
    command=create_file,
    font=("Segoe UI", 11, "bold"),
    bg=ACCENT,
    fg="white",
    activebackground=ACCENT_HOVER,
    activeforeground="white",
    relief="flat",
    bd=0,
    cursor="hand2"
)

create_button.pack(
    fill="x",
    padx=30,
    pady=(20, 12),
    ipady=11
)


# ============================================================
# Статус
# ============================================================

status_label = tk.Label(
    root,
    text="Готово",
    font=("Segoe UI", 9),
    bg=BG,
    fg=MUTED,
    anchor="w"
)

status_label.pack(
    fill="x",
    padx=32
)


# Enter = создать файл
root.bind(
    "<Return>",
    lambda event: create_file()
)


path_entry.focus()

root.mainloop()