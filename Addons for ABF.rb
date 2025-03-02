require 'sketchup.rb'
require 'extensions.rb'
require 'net/http'
require 'json'
require 'open-uri'

module ABFAddons

  # --- Константы ---
  CURRENT_VERSION = "1.3.2"  # !!! Текущая версия вашего плагина !!!
  VERSION_JSON_URL = "https://raw.githubusercontent.com/4ernish8/Addons_for_abf/main/version.json" # URL вашего version.json
  PLUGIN_FOLDER = File.join(Sketchup.find_support_file("Plugins"))

  # --- Список файлов, которые НЕ нужно обновлять ---
  FILES_TO_SKIP = [
    "Addons for ABF/settings.json",  # Пример. Добавьте СЮДА пути ко всем вашим JSON, если они есть.
    "Addons for ABF/prices.json"  
  ].freeze

  # --- Startup Observer (Перенесен наверх) ---
  class StartupObserver < Sketchup::AppObserver
    def onStartupCompleted
      ABFAddons.check_for_updates  # Вызываем метод класса, а не модуля
    end
  end

  # --- Функция проверки обновлений ---
  def self.check_for_updates
    begin
      # Загружаем version.json
      uri = URI.parse(VERSION_JSON_URL)
      response = Net::HTTP.get_response(uri)

      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)
        remote_version = data['version']

        # Сравниваем версии
        if Gem::Version.new(remote_version) > Gem::Version.new(CURRENT_VERSION)
          show_update_dialog(remote_version, data)
        end
      else
        UI.messagebox("Помилка при перевірці оновленнь: #{response.code} - #{response.message}", MB_OK, "Addons for ABF")
      end

    rescue StandardError => e
      UI.messagebox("Помилка при перевірці оновленнь: #{e.message}", MB_OK, "Addons for ABF")
    end
  end

    # --- Функция показа диалога обновления (HTML) ---
    def self.show_update_dialog(new_version, data)
        dialog = UI::HtmlDialog.new(
          {
            :dialog_title => "Оновлення Addons for ABF",
            :preferences_key => "com.example.plugin.updatedialog", # Уникальный ключ
            :scrollable => false,
            :resizable => false,
            :width => 300,
            :height => 150,
            :left => 100,
            :top => 100,
            :min_width => 50,
            :min_height => 50,
            :max_width =>1000,
            :max_height => 1000,
            :style => UI::HtmlDialog::STYLE_DIALOG
          }
        )

        html = <<-HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>Оновлення плагіну</title>
          <style>
            body { font-family: sans-serif; }
            .container {
              display: flex;
              flex-direction: column;
              align-items: center; /* Центрируем содержимое по горизонтали */
              justify-content: center; /* Центрируем содержимое по вертикали */
              height: 100%;
              text-align: center; /* Выравниваем текст по центру */
            }
            .button-container {
              margin-top: 20px;
              display: flex;
              justify-content: center; /* Центрируем кнопки */
              gap: 10px; /* Добавляем небольшой отступ между кнопками */
            }
            button {
                padding: 10px 20px;
                background-color: #3498db;
                color: white;
                border: none;
                border-radius: 5px;
                cursor: pointer;
                font-size: 16px; /* Увеличиваем размер шрифта */
              }
              button:hover { background-color: #2980b9; }
          </style>
        </head>
        <body>
          <div class="container">
            <p>Знайдена нова версія: #{new_version}</p>
            <div class="button-container">
                <button onclick="sketchup.on_update()">Оновити</button>
                <button onclick="sketchup.on_close()">Закрити</button>
            </div>
          </div>
        </body>
        </html>
        HTML

        dialog.set_html(html)

        dialog.add_action_callback("on_update") do |_action_context|
          install_update(data)
          dialog.close
        end
      dialog.add_action_callback("on_close") do |_action_context|
          dialog.close
        end

        dialog.show
    end

  # --- Функция установки обновления ---
  def self.install_update(data)
    begin
      data['files'].each do |file_info|
        file_url = file_info['url']
        local_path = File.join(PLUGIN_FOLDER, file_info['path'])

        # !!! ПРОВЕРКА, НУЖНО ЛИ ПРОПУСТИТЬ ЭТОТ ФАЙЛ !!!
        next if FILES_TO_SKIP.include?(file_info['path'])

        # Создаем директории, если нужно
        dir = File.dirname(local_path)
        Dir.mkdir(dir) unless Dir.exist?(dir)

        # Загружаем и сохраняем файл
        URI.open(file_url) do |remote_file|
          File.open(local_path, "wb") do |local_file|
            local_file.write(remote_file.read)
          end
        end
      end

      UI.messagebox("Оновлення успішно встановлено. Перезавантажте SketchUp для завершення змін.", MB_OK, "Addons for ABF")
      #Sketchup.reload_extension(ext)  # Перезагрузка расширения

    rescue StandardError => e
      UI.messagebox("Помилка при встановленні оновлення: #{e.message}", MB_OK, "Addons for ABF")
    end
  end

  # --- Подключаем ВСЕ файлы плагина ---
  require 'Addons for ABF/move_attachment.rb'
  require 'Addons for ABF/furniture_properties.rb'
  require 'Addons for ABF/Opensheet.rb'
  require 'Addons for ABF/Prefix.rb'
  require 'Addons for ABF/Settings.rb'
  require 'Addons for ABF/Otvirset.rb'
  require 'Addons for ABF/vzvit.rb'
  require 'Addons for ABF/ABFCleaner.rb'
  require 'Addons for ABF/Changelayer.rb'
  require 'Addons for ABF/Help.rb'
  require 'Addons for ABF/Art.rb'

  unless file_loaded?(__FILE__)
    # --- Меню и панель инструментов ---
    submenu = UI.menu("Extensions").add_submenu("Addons for ABF")
    submenu.add_item("Перенос кріплення") do
      Vzvit.run
      Changelayer.run
      MoveAttachment.run
    end
    submenu.add_item("Властивості фурнітури") { FurnitureProperties.run }
    submenu.add_item("Додати префікс") { Prefixx.run }
    submenu.add_item("Редагувати отвір") { Otvirset.run }
    submenu.add_item("Видалити/змінити номер ABF") { ABFCleaner.run }
    submenu.add_item("Відкрити таблицю") { Opensheet.run }
    submenu.add_item("Налаштування") { Settings.run }
    submenu.add_item("Інструкція") { Help.open_help_dialog }
    submenu.add_item("Перевірити оновлення") { check_for_updates }  # Добавлено

    toolbar = UI::Toolbar.new "Addons for ABF"

    cmd = UI::Command.new("Перенос кріплення") do
      Vzvit.run
      Changelayer.run
      MoveAttachment.run
    end
    cmd.small_icon = "Addons for ABF/img/attachment_move.png"
    cmd.large_icon = "Addons for ABF/img/attachment_move.png"
    cmd.tooltip = "Перенос кріплення"
    toolbar.add_item cmd

    cmd = UI::Command.new("Властивості фурнітури") { FurnitureProperties.run }
    cmd.small_icon = "Addons for ABF/img/furniture_properties.png"
    cmd.large_icon = "Addons for ABF/img/furniture_properties.png"
    cmd.tooltip = "Властивості фурнітури"
    toolbar.add_item cmd

    cmd = UI::Command.new("Додати префікс") { Prefixx.run }
    cmd.small_icon = "Addons for ABF/img/prefix.png"
    cmd.large_icon = "Addons for ABF/img/prefix.png"
    cmd.tooltip = "Додати префікс"
    toolbar.add_item cmd

    cmd = UI::Command.new("Редагувати отвір") { Otvirset.run }
    cmd.small_icon = "Addons for ABF/img/otv.png"
    cmd.large_icon = "Addons for ABF/img/otv.png"
    cmd.tooltip = "Редагувати отвір"
    toolbar.add_item cmd

    cmd = UI::Command.new("Відкрити таблицю") do
      Art.run
      Opensheet.run
    end
    cmd.small_icon = "Addons for ABF/img/Open_sheet.png"
    cmd.large_icon = "Addons for ABF/img/Open_sheet.png"
    cmd.tooltip = "Відкрити таблицю"
    toolbar.add_item cmd

    cmd = UI::Command.new("Налаштування") { Settings.run }
    cmd.small_icon = "Addons for ABF/img/settings.png"
    cmd.large_icon = "Addons for ABF/img/settings.png"
    cmd.tooltip = "Налаштування"
    toolbar.add_item cmd

    toolbar.show

    plugin_name = "Addons for ABF"
    version = "1.3.2"  # ТЕКУЩАЯ версия
    author = "Олександр_К https://t.me/I4ernish"

    ext = SketchupExtension.new(plugin_name, "Addons for ABF.rb")
    ext.description = 'Addons for ABF - auto-update'  # Обновленное описание
    ext.version = version
    ext.creator = author
    ext.copyright = 'Олександр_К © 2024'  # Обновленный год
    Sketchup.register_extension(ext, true)

    file_loaded(__FILE__)

    # --- Добавляем наблюдателя ---
    Sketchup.add_observer(StartupObserver.new)  # !!! Вот здесь была ошибка !!!
  end
end