import os
import sys
import subprocess
import threading
import time
import ctypes
import win32service
import win32serviceutil
from PIL import Image, ImageDraw
import pystray
import tkinter as tk
from tkinter import messagebox

class ZapretTrayApp:
    def __init__(self):
        self.script_dir = os.path.dirname(os.path.abspath(__file__))
        self.is_admin = self.check_admin()
        self.icon = None
        self.setup_tray_icon()
        
    def check_admin(self):
        """Проверяем права администратора"""
        try:
            return ctypes.windll.shell32.IsUserAnAdmin()
        except:
            return False

    def get_service_status(self):
        """Получаем статус службы zapret"""
        try:
            status = win32serviceutil.QueryServiceStatus('zapret')
            if status[1] == win32service.SERVICE_RUNNING:
                return "running", "🟢 Запущена"
            elif status[1] == win32service.SERVICE_STOPPED:
                return "stopped", "🔴 Остановлена"
        except:
            pass
        
        # Fallback через sc query
        try:
            result = subprocess.run('sc query zapret', capture_output=True, text=True, shell=True)
            if "RUNNING" in result.stdout:
                return "running", "🟢 Запущена"
            elif "STOPPED" in result.stdout:
                return "stopped", "🔴 Остановлена"
        except:
            pass
            
        return "not_found", "⚫ Не установлена"

    def run_cmd(self, command, wait=True):
        """Выполняет команду"""
        try:
            if wait:
                result = subprocess.run(command, shell=True, capture_output=True, text=True, 
                                      cwd=self.script_dir, encoding='utf-8')
                return result.returncode == 0, result.stdout, result.stderr
            else:
                subprocess.Popen(command, shell=True, cwd=self.script_dir)
                return True, "", ""
        except Exception as e:
            return False, "", str(e)

    def start_service(self):
        """Запускает службу"""
        def task():
            success, stdout, stderr = self.run_cmd('net start zapret')
            if success:
                self.show_notification("Zapret", "Служба запущена ✅")
            else:
                if "уже запущена" in stderr or "already running" in stderr:
                    self.show_notification("Zapret", "Служба уже запущена")
                else:
                    self.show_error("Ошибка запуска", stderr)
            self.update_icon_menu()
            
        threading.Thread(target=task, daemon=True).start()

    def stop_service(self):
        """Останавливает службу"""
        def task():
            success, stdout, stderr = self.run_cmd('net stop zapret')
            if success:
                self.show_notification("Zapret", "Служба остановлена ⏹️")
            else:
                if "не запущена" in stderr or "not started" in stderr:
                    self.show_notification("Zapret", "Служба уже остановлена")
                else:
                    self.show_error("Ошибка остановки", stderr)
            self.update_icon_menu()
            
        threading.Thread(target=task, daemon=True).start()

    def restart_service(self):
        """Перезапускает службу"""
        def task():
            self.run_cmd('net stop zapret')
            time.sleep(2)
            self.run_cmd('net start zapret')
            self.show_notification("Zapret", "Служба перезапущена 🔄")
            self.update_icon_menu()
            
        threading.Thread(target=task, daemon=True).start()

    def run_updater(self):
        """Запускает обновление"""
        updater_path = os.path.join(self.script_dir, "auto_updater.bat")
        if os.path.exists(updater_path):
            self.run_cmd(f'"{updater_path}"', wait=False)
            self.show_notification("Zapret", "Запущено обновление...")
        else:
            self.show_error("Ошибка", "auto_updater.bat не найден")

    def show_status(self):
        """Показывает статус"""
        status, status_text = self.get_service_status()
        admin_text = "✅ Есть" if self.is_admin else "❌ Нет"
        
        messagebox.showinfo("Статус Zapret", 
                          f"{status_text}\n\n"
                          f"Права администратора: {admin_text}\n"
                          f"Папка: {self.script_dir}")

    def show_notification(self, title, message):
        """Показывает уведомление"""
        try:
            # Простое уведомление через иконку
            if self.icon:
                self.icon.notify(message, title)
        except:
            pass

    def show_error(self, title, message):
        """Показывает ошибку"""
        try:
            # Создаем временное окно для messagebox
            root = tk.Tk()
            root.withdraw()
            messagebox.showerror(title, message)
            root.destroy()
        except:
            pass

    def create_icon_image(self, status):
        """Создает иконку в зависимости от статуса"""
        width = 64
        height = 64
        image = Image.new('RGB', (width, height), color='white')
        draw = ImageDraw.Draw(image)
        
        # Разные цвета в зависимости от статуса
        if status == "running":
            color = "green"
        elif status == "stopped":
            color = "red"
        else:
            color = "gray"
            
        # Рисуем простой значок щита
        draw.rectangle([16, 12, 48, 44], fill=color, outline="black", width=2)
        draw.rectangle([20, 16, 44, 40], fill="white")
        draw.rectangle([24, 20, 40, 36], fill=color)
        
        return image

    def setup_tray_icon(self):
        """Настраивает иконку в трее"""
        status, status_text = self.get_service_status()
        image = self.create_icon_image(status)
        
        # Создаем меню
        menu_items = []
        
        # Статус
        admin_text = " (Админ)" if self.is_admin else ""
        menu_items.append(pystray.MenuItem(f"Zapret{admin_text}", None, enabled=False))
        menu_items.append(pystray.MenuItem(f"Статус: {status_text}", None, enabled=False))
        menu_items.append(pystray.MenuItem("---", None, enabled=False))
        
        # Управление службой
        menu_items.append(pystray.MenuItem("▶ Запустить", self.start_service))
        menu_items.append(pystray.MenuItem("⏹ Остановить", self.stop_service))
        menu_items.append(pystray.MenuItem("🔄 Перезапустить", self.restart_service))
        menu_items.append(pystray.MenuItem("---", None, enabled=False))
        
        # Дополнительные функции
        menu_items.append(pystray.MenuItem("📊 Показать статус", self.show_status))
        menu_items.append(pystray.MenuItem("🔄 Проверить обновления", self.run_updater))
        menu_items.append(pystray.MenuItem("---", None, enabled=False))
        
        # Выход
        menu_items.append(pystray.MenuItem("❌ Выход", self.exit_app))
        
        menu = pystray.Menu(*menu_items)
        
        # Создаем иконку
        self.icon = pystray.Icon("zapret_tray", image, "Zapret Controller", menu)
        
        # Запускаем в отдельном потоке
        thread = threading.Thread(target=self.icon.run, daemon=True)
        thread.start()

    def update_icon_menu(self):
        """Обновляет меню иконки"""
        if self.icon:
            # Пересоздаем иконку с обновленным статусом
            self.icon.stop()
            self.setup_tray_icon()

    def exit_app(self):
        """Выход из приложения"""
        if self.icon:
            self.icon.stop()
        os._exit(0)

def main():
    # Скрытое окно для работы messagebox
    root = tk.Tk()
    root.withdraw()
    
    # Проверяем зависимости
    try:
        import pystray
        from PIL import Image
        import win32service
    except ImportError as e:
        messagebox.showerror("Ошибка", 
                           f"Не установлены зависимости:\n{e}\n\n"
                           "Запустите install_requirements_fixed.bat")
        return
    
    # Запускаем приложение
    app = ZapretTrayApp()
    
    # Уведомление о запуске
    app.show_notification("Zapret", "Контроллер запущен в трее")
    
    # Главный цикл
    try:
        root.mainloop()
    except KeyboardInterrupt:
        app.exit_app()

if __name__ == "__main__":
    main()