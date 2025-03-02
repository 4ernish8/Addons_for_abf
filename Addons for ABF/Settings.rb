require 'json'

module Settings
  def self.plugin_folder
    File.dirname(__FILE__)
  end
  SETTINGS_FILE = "settings.json"
  PRICES_FILE = "prices.json"
  OLD_SETTINGS_FILE = "settings.txt"

  def self.settings_file_path
    File.join(plugin_folder, SETTINGS_FILE)
  end

  def self.prices_file_path
    File.join(plugin_folder, PRICES_FILE)
  end

  def self.old_settings_file_path
    File.join(plugin_folder, OLD_SETTINGS_FILE)
  end

  def self.create_settings_file_if_not_exists
    unless File.exist?(settings_file_path)
      File.open(settings_file_path, "w") { |file| file.write("[]") }
    end
  end

  def self.read_settings
    begin
      JSON.parse(File.read(settings_file_path))
    rescue JSON::ParserError, Errno::ENOENT
      []
    end
  end

  def self.write_settings(data)
    create_settings_file_if_not_exists
    File.open(settings_file_path, "w") { |file| file.write(JSON.pretty_generate(data)) }
  end

  def self.add_supplier(supplier)
    suppliers = read_settings
    if suppliers.any? { |s| s.downcase == supplier.downcase }
      UI.messagebox("Такий постачальник вже існує!")
      return
    end
    suppliers << supplier
    suppliers.sort! 
    write_settings(suppliers)
  end

  def self.remove_supplier(index)
    suppliers = read_settings
    suppliers.delete_at(index)
    write_settings(suppliers)
  end

  def self.import_settings(use_old_version = false)
    if use_old_version
      path = UI.openpanel("Виберіть файл settings.txt для імпорту", plugin_folder, "Text Files|*.txt||")
      return if path.nil?

      begin
        suppliers = File.readlines(path)
                        .map(&:strip)
                        .reject { |line| line.start_with?("*", "http", "#") || line.empty? }
                        .uniq
                        .sort 
        write_settings(suppliers)
        UI.messagebox("Налаштування постачальників успішно імпортовано з #{File.basename(path)}!")
      rescue => e
        UI.messagebox("Помилка при імпорті: #{e.message}")
      end

    else
      path = UI.openpanel("Виберіть файл для імпорту", plugin_folder, "JSON Files|*.json||")
      return if path.nil?

      begin
        imported_data = JSON.parse(File.read(path))
        filename = File.basename(path)
        if filename == SETTINGS_FILE && imported_data.is_a?(Array)
          write_settings(imported_data.sort)
          UI.messagebox("Налаштування постачальників успішно імпортовано!")
        elsif filename == PRICES_FILE && imported_data.is_a?(Hash)
          write_prices(imported_data)
          UI.messagebox("Налаштування цін успішно імпортовано!")
        else
          UI.messagebox("Неправильний формат або ім'я файлу для імпорту.")
          return
        end
      rescue JSON::ParserError
        UI.messagebox("Неправильний формат файлу. Файл не є коректним JSON.")
      end
    end

    @dialog.close if @dialog && @dialog.visible?
    self.run
  end

  def self.export_settings
    selected_file = UI.select_directory(title: "Виберіть папку для збереження")
    return if selected_file.nil?

    begin
      File.open(File.join(selected_file, SETTINGS_FILE), 'w') { |f| f.write(JSON.pretty_generate(read_settings)) }
      File.open(File.join(selected_file, PRICES_FILE), 'w') { |f| f.write(JSON.pretty_generate(read_prices)) } if File.exist?(prices_file_path)
      UI.messagebox("Налаштування успішно експортовано до #{selected_file}!")
    rescue => e
      UI.messagebox("Помилка експорту налаштувань: #{e.message}")
    end
  end

  def self.read_prices
    begin
      JSON.parse(File.read(prices_file_path))
    rescue JSON::ParserError, Errno::ENOENT
      {}
    end
  end

  def self.write_prices(data)
    File.open(prices_file_path, "w") { |file| file.write(JSON.pretty_generate(data)) }
  end

  def self.run
    suppliers = read_settings.sort 
    base_height = 260
    supplier_item_height = 28
    additional_height = suppliers.length * supplier_item_height
    total_height = base_height + additional_height
    total_height = [total_height, 550].min

    html = <<~HTML
      <html>
      <head>
        <meta charset="UTF-8">
        <link href="https://fonts.googleapis.com/css2?family=Balsamiq+Sans&display=swap" rel="stylesheet">
        <style>
          body {
            font-family: 'Balsamiq Sans', sans-serif;
            font-size: 14px;
            color: #333;
          }
          .container {
            width: 90%;
            margin: 0 auto;
            display: flex;
            flex-direction: column;
            justify-content: space-between;
            height: 100%;
          }
          h2 {
            text-align: center;
            font-size: 18px;
            margin-bottom: 20px;
          }
          .input-group {
            display: flex;
            margin-bottom: 10px;
            align-items: center;
          }
          #new-item {
            flex-grow: 1;
            padding: 6px;
            margin-right: 5px;
            font-size: 14px;
          }
          .supplier-list {
            list-style: none;
            padding: 0;
          }
          .supplier-item {
            display: flex;
            align-items: center;
            margin-bottom: 3px;
            border-bottom: 1px solid #eee;
            padding-bottom: 3px;
          }
          .supplier-name {
            flex-grow: 1;
            padding: 4px;
            font-size: 14px;
            line-height: 1.2;
          }
          .add-button, .delete-button {
            width: 24px;
            height: 24px;
            background-color: transparent;
            background-repeat: no-repeat;
            background-position: center;
            border: none;
            padding: 0;
            cursor: pointer;
            display: flex;
            justify-content: center;
            align-items: center;
          }
          .add-button {
            background-image: url('file:///#{File.join(plugin_folder, "img/buttons/add.png").gsub("\\", "/")}');
          }
          .delete-button {
            background-image: url('file:///#{File.join(plugin_folder, "img/buttons/del.png").gsub("\\", "/")}');
            margin-left: 5px;
          }
          .import-export-buttons {
            display: flex;
            margin-bottom: 20px;
          }
          .button-img {
            width: 100px;
            height: 30px;
            cursor: pointer;
            margin-right: 10px;
          }
          .buttons-and-checkbox-container {
            margin-top: auto;
            display: flex;
            flex-direction: column;
            align-items: center;
          }
          .checkbox-container {
            display: flex;
            align-items: center;
            margin-top: 10px;
          }
          .top-content {
            flex-grow: 1;
          }
          .buttons-wrapper {
            display: flex;
            justify-content: center;
            align-items: flex-start;
          }
        </style>

        <script>
          function addSupplier() {
            var supplier = document.getElementById('new-item').value;
            if (supplier.trim() !== '') {
              window.location.href = 'skp:add_supplier@' + encodeURIComponent(supplier);
            }
          }

          function deleteSupplier(index) {
            window.location.href = 'skp:remove_supplier@' + index;
          }

          function importSettings() {
            var useOldVersion = document.getElementById('oldVersionCheckbox').checked;
            window.location = 'skp:import_settings@' + useOldVersion;
          }

          function exportSettings() {
            window.location = 'skp:export_settings';
          }
        </script>
      </head>
      <body>
        <div class="container">
          <div class="top-content">
            <h2>Постачальники</h2>
            <div class="input-group">
              <input type="text" id="new-item" placeholder="Новий постачальник">
              <button class="add-button" onclick="addSupplier()"></button>
            </div>
            <ul class="supplier-list">
              #{suppliers.each_with_index.map { |supplier, index|
                "<li class='supplier-item'>
                  <span class='supplier-name'>#{supplier}</span>
                  <button class='delete-button' onclick='deleteSupplier(#{index})'></button>
                </li>"
              }.join}
            </ul>
          </div>
          <div class="buttons-and-checkbox-container">
            <div class="buttons-wrapper">
              <img class='button-img' src='file:///#{File.join(plugin_folder, "img/buttons/import.png").gsub("\\", "/")}' onclick='importSettings()'>
              <img class='button-img' src='file:///#{File.join(plugin_folder, "img/buttons/exp.png").gsub("\\", "/")}' onclick='exportSettings()'>
            </div>
            <div class="checkbox-container">
              <input type="checkbox" id="oldVersionCheckbox">
              <label for="oldVersionCheckbox">Імпорт з файлу settings.txt (old)</label>
            </div>
          </div>
        </div>
      </body>
      </html>
    HTML

    dialog_options = {
      dialog_title: "Налаштування",
      preferences_key: "com.example.plugin.settings",
      resizable: true,
      width: 400,
      height: total_height,
      left: 100,
      top: 100,
      style: UI::HtmlDialog::STYLE_DIALOG
    }

    @dialog = UI::HtmlDialog.new(dialog_options)
    @dialog.set_html(html)

    @dialog.add_action_callback("add_supplier") do |_dialog, params|
      supplier = params
      add_supplier(supplier)
      @dialog.close
      self.run
    end

    @dialog.add_action_callback("remove_supplier") do |_dialog, params|
      index = params.to_i
      remove_supplier(index)
      @dialog.close
      self.run
    end

    @dialog.add_action_callback("import_settings") do |_dialog, params|
      use_old_version = params == "true"
      import_settings(use_old_version)
    end

    @dialog.add_action_callback("export_settings") do |_dialog, _params|
      export_settings
    end

    @dialog.show
  end
end
