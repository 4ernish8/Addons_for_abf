require 'sketchup.rb'
require 'extensions.rb'
require 'net/http'
require 'json'
require 'open-uri'

module ABFAddons

  # --- Константи ---
  CURRENT_VERSION = "1.3.3"  # !!! Поточна версія !!!
  VERSION_JSON_URL = "https://raw.githubusercontent.com/4ernish8/Addons_for_abf/main/version.json" # URL version.json
  PLUGIN_FOLDER = File.join(Sketchup.find_support_file("Plugins")) # Вірний шлях до Plugins
  CHECKED_FOR_UPDATES = false # Додаємо флаг перевірки оновлень

  # --- Перелік файлів які не чіпаємо ---
  FILES_TO_SKIP = [
    "Addons for ABF/settings.json",
    "Addons for ABF/prices.json"
  ].freeze

  # --- Завантаження файлів плагіну (.rbe или .rb) ---
  def self.load_plugin_file(filename)
    rbe_path = File.join(PLUGIN_FOLDER, "Addons for ABF", "#{filename}.rbe") # Додаємо "Addons for ABF"
    rb_path  = File.join(PLUGIN_FOLDER, "Addons for ABF", "#{filename}.rb")  # Додаємо "Addons for ABF"

    begin
      if File.exist?(rbe_path)
        Sketchup.load(rbe_path) # Завантажуємо .rbe
        puts "Loaded: #{rbe_path}" 
        return true
      elsif File.exist?(rb_path)
        load rb_path # Завантажуємо.rb (якщо немає .rbe)
        puts "Loaded: #{rb_path}"  
        return true
      else
        UI.messagebox("ERROR: File not found: #{filename}.rb or #{filename}.rbe")
        return false
      end
    rescue => e
      UI.messagebox("Error loading #{filename}: #{e.message}\n#{e.backtrace.join("\n")}") # Додали backtrace
      return false
    end
  end

  # --- Перефірка оновленнь ---
  def self.check_for_updates
    # Чи була перевірку в цьому сеансі
    return if CHECKED_FOR_UPDATES

    begin
      # Завантажуємо version.json
      uri = URI.parse(VERSION_JSON_URL)
      response = Net::HTTP.get_response(uri)

      if response.is_a?(Net::HTTPSuccess)
        data = JSON.parse(response.body)
        remote_version = data['version']

        # Порівнюваємо версії
        if Gem::Version.new(remote_version) > Gem::Version.new(CURRENT_VERSION)
          show_update_dialog(remote_version, data)
        end
      else
        UI.messagebox("Помилка при перевірці оновленнь: #{response.code} - #{response.message}", MB_OK, "Addons for ABF")
      end

    rescue StandardError => e
      UI.messagebox("Помилка при перевірці оновленнь: #{e.message}", MB_OK, "Addons for ABF")
    end

    # Встановлюваємо флаг якщо перевірка вже була
     @checked_for_updates = true
  end

  # --- Диалог (HTML) ---
  def self.show_update_dialog(new_version, data)
    dialog = UI::HtmlDialog.new(
      {
        :dialog_title => "Оновлення Addons for ABF",
        :preferences_key => "com.example.plugin.updatedialog", # Уникальний ключ
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
          align-items: center;
          justify-content: center;
          height: 100%;
          text-align: center;
        }
        .button-container {
          margin-top: 20px;
          display: flex;
          justify-content: center;
          gap: 10px;
        }
        button {
            padding: 10px 20px;
            background-color: #3498db;
            color: white;
            border: none;
            border-radius: 5px;
            cursor: pointer;
            font-size: 16px;
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

  # --- Функція встановлення оновлення ---
  def self.install_update(data)
    begin
      data['files'].each do |file_info|
        file_url = file_info['url']
        local_path = File.join(PLUGIN_FOLDER, file_info['path'])

        # !!! ПЕРЕВІРКА ЩО ТРЕБА ПРОПУСТИТИ ФАЙЛ !!!
        next if FILES_TO_SKIP.include?(file_info['path'])

        # Створюємо папку якщо її немає
        dir = File.dirname(local_path)
        Dir.mkdir(dir) unless Dir.exist?(dir)

        # Завантажуємо і зберігаємо файл
        URI.open(file_url) do |remote_file|
          File.open(local_path, "wb") do |local_file|
            local_file.write(remote_file.read)
          end
        end
      end

      UI.messagebox("Оновлення успішно встановлено. Перезавантажте SketchUp для завершення змін.", MB_OK, "Addons for ABF")
      #Sketchup.reload_extension(ext)

    rescue StandardError => e
      UI.messagebox("Помилка при встановленні оновлення: #{e.message}", MB_OK, "Addons for ABF")
    end
  end

    unless file_loaded?(__FILE__)
    # --- Меню ---
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
    submenu.add_item("Перевірити оновлення") { check_for_updates }

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
    version = CURRENT_VERSION
    author = "Олександр_К https://t.me/I4ernish"

        ext = SketchupExtension.new(
          plugin_name,
          if File.exist?(File.join(PLUGIN_FOLDER, "Addons for ABF.rbe"))
              File.join(PLUGIN_FOLDER, "Addons for ABF.rbe")
          else
              File.join(PLUGIN_FOLDER, "Addons for ABF.rb")
          end
        )

    ext.description = 'Перенос кріпленнь та пазів з компонентів фурнітури на деталі'
    ext.version = version
    ext.creator = author
    ext.copyright = 'Олександр_К © 2025'
    Sketchup.register_extension(ext, true)

    file_loaded(__FILE__)

      # --- Завантажуємо файлі плагіну ---
    files = [
      'move_attachment',
      'furniture_properties',
      'Opensheet',
      'Prefix',
      'Settings',
      'Otvirset',
      'vzvit',
      'ABFCleaner',
      'Changelayer',
      'Help',
      'Art'
    ]
    files.each do |file|
      load_plugin_file(file)
    end
        # --- Запускаємо таймер оновлення при запуску ---
    UI.start_timer(40, false) { ABFAddons.check_for_updates }
  end
end