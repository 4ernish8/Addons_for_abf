module Opensheet
  require 'json'
  require 'uri'
  require 'fileutils'

  def self.run
    model = Sketchup.active_model

    @prices_file = File.join(File.dirname(__FILE__), 'prices.json')
    puts "Прайс завантажено з: #{@prices_file}"

    @prices = load_prices
    @items = collect_groups_data(model)
    @viyar_items = collect_viyar_data(model)

    dialog = UI::HtmlDialog.new(
      dialog_title: "Спецификація фурнітури та профілів",
      scrollable: true,
      width: 1000,
      height: 800,
      style: UI::HtmlDialog::STYLE_DIALOG
    )
    dialog.add_action_callback("updatePrice") do |action_context, id, new_price|
      begin
        price = new_price.to_f
        @prices[id] = price

        if @items[id]
          @items[id][:price] = price
          quantity = @items[id][:quantity]
          new_total = price * quantity

          save_prices
          dialog.execute_script("updateRowValues('#{id}', #{price}, #{new_total})")
        else
          puts "Error: Item not found for id: #{id}"
        end
      rescue => e
        puts "Error in updatePrice: #{e.message}\n#{e.backtrace.join("\n")}"
      end
    end
    
    dialog.add_action_callback("refreshTable") do |_context|
      @items = collect_groups_data(Sketchup.active_model)
      @viyar_items = collect_viyar_data(Sketchup.active_model)
      dialog.set_html(generate_html)
    end
    
    dialog.add_action_callback("saveToCSV") do |_context|
      filepath = UI.savepanel("Зберегти таблицю", "", "специфікація.csv")
      return unless filepath

      filepath += ".csv" unless filepath.downcase.end_with?(".csv")
      
      total_sum = @items.values.sum { |item| item[:price] * item[:quantity] }
      
      File.open(filepath, "w:UTF-8") do |file|
        file.write("\uFEFF")
        file.puts "№;Артикул;Назва;Од. вим;Кількість;Артикул виробника;Постачальник;Ціна;Вартість"
        
        @items.each_with_index do |(_, item), index|
          total = item[:price] * item[:quantity]
          file.puts "#{index + 1};#{item[:art]};#{item[:nazva]};#{item[:odvm]};#{sprintf('%.2f', item[:quantity]).gsub('.', ',')};#{item[:artv]};#{item[:post]};#{sprintf('%.2f', item[:price]).gsub('.', ',')};#{sprintf('%.2f', total).gsub('.', ',')}"
        end
        
        file.puts ";;;;;;;Загальна сума;#{sprintf('%.2f', total_sum).gsub('.', ',')}"
      end
      
      UI.messagebox("Специфікацію збережено:\n#{filepath}")
    end

    dialog.add_action_callback("saveViyarToCSV") do |_context|
      filepath = UI.savepanel("Експорт CSV до віяр", "", "віяр_фурнітура.csv")
      return unless filepath

      filepath += ".csv" unless filepath.downcase.end_with?(".csv")
      
      File.open(filepath, "w:UTF-8") do |file|
        file.write("\uFEFF")
        file.puts "Код;Кількість"
        
        @viyar_items.each do |item|
          file.puts "#{item[:art]};#{item[:quantity]}"
        end
      end
      
      UI.messagebox("Фурнітуру для Віяр збережено:\n#{filepath}")
    end

    dialog.set_html(generate_html)
    dialog.show
  end

  private
    def self.collect_viyar_data(model)
        viyar_items = {}
        find_viyar_groups(model.entities, viyar_items)
        viyar_items.values.sort_by { |item| item[:art].to_s }
    end

    def self.find_viyar_groups(entities, items)
      entities.each do |entity|
        if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
          attrs = entity.attribute_dictionary("dynamic_attributes")

          if attrs && attrs["post"].to_s.downcase == "віяр" && attrs["dzm"].to_s.downcase == "true"
            art = attrs["art"].to_s
            key = art.downcase
            odvm = attrs["odvm"].to_s
            lp = attrs["lp"].to_f

            if odvm == "м" && lp > 0
              length = get_group_length(entity)
              if items[key]
                items[key][:length] += length
              else
                items[key] = { art: art, length: length, quantity: 0 }
              end
              items[key][:quantity] = (items[key][:length] / lp).ceil
            else
              if items[key]
                items[key][:quantity] += 1
              else
                items[key] = { art: art, quantity: 1 }
              end
            end
          end
          if entity.respond_to?(:entities)
              find_viyar_groups(entity.entities, items)
          elsif entity.is_a?(Sketchup::ComponentInstance) && entity.respond_to?(:definition)
              find_viyar_groups(entity.definition.entities, items)
          end
        end
      end
    end



  def self.collect_groups_data(model)
    items = {}
    entities_to_process = model.selection.empty? ? model.entities : model.selection
    @table_title = if model.selection.empty?
                     "Специфікація"
                   elsif model.selection.size == 1 && model.selection.first.is_a?(Sketchup::Group)
                     "Специфікація на #{model.selection.first.name}"
                   else
                      "Специфікація"
                   end
    find_groups_with_attributes(entities_to_process, items)
    items.select { |_, item| !item[:nazva].nil? && !item[:nazva].empty? }  # Filter out entries with no 'nazva'
  end
  def self.find_groups_with_attributes(entities, items)
      entities.each do |entity|
        if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
          attrs = entity.attribute_dictionary("dynamic_attributes")
          if attrs && attrs["nazva"] && !attrs["nazva"].to_s.empty?
            item = {
              art: attrs["art"].to_s,
              nazva: attrs["nazva"].to_s,
              odvm: attrs["odvm"].to_s,
              artv: attrs["artv"].to_s,
              post: attrs["post"].to_s
            }

            key = URI.encode_www_form_component("#{item[:art]}_#{item[:nazva]}_#{item[:odvm]}_#{item[:artv]}_#{item[:post]}")

            if item[:odvm] == "м"
              length = get_group_length(entity)
              if items[key]
                items[key][:quantity] += length
              else
                stored_price = @prices[key]
                items[key] = item.merge(quantity: length, price: (stored_price || 0).to_f)
              end
            else
              if items[key]
                items[key][:quantity] += 1
              else
                stored_price = @prices[key]
                items[key] = item.merge(quantity: 1, price: (stored_price || 0).to_f)
              end
            end
          end
          if entity.respond_to?(:entities)
            find_groups_with_attributes(entity.entities, items)
          elsif entity.is_a?(Sketchup::ComponentInstance) && entity.respond_to?(:definition)
            find_groups_with_attributes(entity.definition.entities, items)
          end
        end
      end
    end

  def self.get_group_length(group)
      bounds = group.bounds
      x_size = bounds.width * 25.4
      y_size = bounds.height * 25.4
      z_size = bounds.depth * 25.4
      max_size = [x_size, y_size, z_size].max
      (max_size / 1000.0).round(3)
  end

  def self.format_price(value)
    value % 1 == 0 ? value.to_i.to_s : sprintf('%.2f', value)
  end

  def self.generate_html
    plugin_folder = File.dirname(__FILE__)
  
    html = <<-HTML
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <link href="https://fonts.googleapis.com/css2?family=Balsamiq+Sans&display=swap" rel="stylesheet">
      <style>
        body { font-family: 'Balsamiq Sans', sans-serif; font-size: 12px; }
        .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
        .title { font-size: 18px; font-weight: bold; text-align: center; flex-grow: 1; }
        .buttons { display: flex; gap: 10px; user-select: none; }
        .button-img { width: 24px; height: 24px; cursor: pointer; border: none; background: none; padding: 0; }
        .tabs { display: flex; margin-bottom: 20px; border-bottom: 1px solid #ddd; }
        .tab { padding: 10px 20px; cursor: pointer; border: 1px solid #ddd; border-bottom: none; background: #f5f5f5; margin-right: 5px; border-radius: 5px 5px 0 0; }
        .tab:hover { background: #e0e0e0; }
        .tab.active { background: #007BFF; color: white; font-weight: bold; border-bottom: 2px solid #007BFF; margin-bottom: -2px; }
        .tab-content { display: none; }
        .tab-content.active { display: block; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 6px; font-size: 12px; text-align: center; }
        td:nth-child(3) { text-align: left; }
        th { background-color: #f5f5f5; }
        .price-input { text-align: right; font-size: 12px; }
        .total { text-align: right; }
        .summary { font-weight: bold; text-align: right; background-color: #f0f0f0; font-size: 12px; }
         h2 {
            text-align: center;
            font-size: 18px;
          font-family: 'Balsamiq Sans', sans-serif;
            margin-bottom: 20px;
          }
        @media print { .buttons, .tabs { display: none; } .tab-content { display: block; } }
      </style>
    </head>
    <body>
      <div class="tabs">
        <div class="tab active" onclick="switchTab('furniture')">Фурнітура</div>
        <div class="tab" onclick="switchTab('viyar')">Віяр</div>
      </div>
  
      <div id="furniture" class="tab-content active">
        <div class="header">
          <div class="title">#{@table_title}</div>
          <div class="buttons">
            <img class='button-img' src='file:///#{File.join(plugin_folder, "img/buttons/refresh.png").gsub("\\", "/")}'' onclick='refreshTable()' title='Оновити таблицю'>
            <img class='button-img' src='file:///#{File.join(plugin_folder, "img/buttons/save.png").gsub("\\", "/")}'' onclick='saveToCSV()' title='Зберегти у CSV'>
          </div>
        </div>
  
        <table>
          <thead>
            <tr>
              <th onclick="sortTable(0)">№</th>
              <th onclick="sortTable(1)">Артикул</th>
              <th onclick="sortTable(2)">Назва</th>
              <th onclick="sortTable(3)">Од. вим</th>
              <th onclick="sortTable(4)">Кількість</th>
              <th onclick="sortTable(5)">Артикул виробника</th>
              <th onclick="sortTable(6)">Постачальник</th>
              <th onclick="sortTable(7)">Ціна</th>
              <th onclick="sortTable(8)">Вартість</th>
            </tr>
          </thead>
          <tbody>
    HTML
  
    total_sum = @items.values.sum { |item| item[:price] * item[:quantity] }
  
    @items.sort_by { |_, item| item[:post].to_s.downcase }.each_with_index do |(id, item), index|
      total = item[:price] * item[:quantity]
      html += <<-ROW
        <tr id="#{id}">
          <td>#{index + 1}</td>
          <td>#{item[:art]}</td>
          <td>#{item[:nazva]}</td>
          <td>#{item[:odvm]}</td>
          <td>#{item[:quantity]}</td>
          <td>#{item[:artv]}</td>
          <td>#{item[:post]}</td>
          <td><input type="number"
                     class="price-input"
                     step="0.01"
                     value="#{sprintf('%.2f', item[:price])}"
                     onkeyup="priceChanged(event, '#{id}', this.value)"
                     onchange="priceChanged(event, '#{id}', this.value)"></td>
          <td class="total" id="total_#{id}">#{format_price(total)}</td>
        </tr>
      ROW
    end
  
    html += <<-HTML
      </tbody>
      <tfoot>
        <tr>
          <td colspan="8" class="summary">Загальна сума:</td>
          <td class="summary" id="grand_total">#{sprintf('%.2f', total_sum)}</td>
        </tr>
      </tfoot>
    </table>
  </div>
  
  <div id="viyar" class="tab-content">
    <div class="header">
      <div class="title">Експорт фурнітури до Віяр</div>
      <div class="buttons">
        <img class='button-img' src='file:///#{File.join(plugin_folder, "img/buttons/refresh.png").gsub("\\", "/")}'' onclick='refreshTable()' title='Оновити таблицю'>
        <img class='button-img' src='file:///#{File.join(plugin_folder, "img/buttons/save_viyar.png").gsub("\\", "/")}'' onclick='saveViyarToCSV()' title='Експорт фурнітури до віяр'>
      </div>
    </div>
  
    <table>
      <thead>
        <tr>
          <th>Код</th>
          <th>К-во</th>
        </tr>
      </thead>
      <tbody>
  HTML
  
    @viyar_items.each_with_index do |item, index|
      html += <<-ROW
        <tr>
          <td>#{item[:art]}</td>
          <td>#{item[:quantity]}</td>
        </tr>
      ROW
    end
  
    html += <<-HTML
      </tbody>
    </table>
  </div>
  
  <script>
    let currentSortColumn = -1;
    let sortDirection = 1;
  
    function sortTable(columnIndex) {
      const table = document.querySelector('#furniture table');
      const tbody = table.querySelector('tbody');
      const rows = Array.from(tbody.querySelectorAll('tr'));
  
      if (currentSortColumn === columnIndex) {
        sortDirection = -sortDirection;
      } else {
        sortDirection = 1;
        currentSortColumn = columnIndex;
      }
  
      rows.sort((a, b) => {
        let aValue = a.cells[columnIndex].textContent;
        let bValue = b.cells[columnIndex].textContent;
  
        if (columnIndex === 4 || columnIndex === 7 || columnIndex === 8) {
          aValue = parseFloat(aValue.replace(/[^\d.-]/g, '')) || 0;
          bValue = parseFloat(bValue.replace(/[^\d.-]/g, '')) || 0;
        } else {
          aValue = aValue.toLowerCase();
          bValue = bValue.toLowerCase();
        }
  
        if (aValue < bValue) return -1 * sortDirection;
        if (aValue > bValue) return 1 * sortDirection;
        return 0;
      });
  
      rows.forEach(row => tbody.appendChild(row));
  
      rows.forEach((row, index) => {
        row.cells[0].textContent = index + 1;
      });
    }
  
    function switchTab(tabId) {
      document.querySelectorAll('.tab').forEach(tab => {
        tab.classList.remove('active');
      });
  
      document.querySelector(`[onclick="switchTab('${tabId}')"]`).classList.add('active');
  
      document.querySelectorAll('.tab-content').forEach(content => {
        content.classList.remove('active');
      });
  
      document.getElementById(tabId).classList.add('active');
    }
  
    function priceChanged(event, id, newPrice) {
      if (newPrice === '') newPrice = '0';
      sketchup.updatePrice(id, newPrice);
    }
  
    function updateRowValues(id, price, total) {
      const priceInput = document.querySelector(`#${id} .price-input`);
      const totalCell = document.querySelector(`#total_${id}`);
  
      if (price !== parseFloat(priceInput.value)) {
        priceInput.value = price.toFixed(2);
      }
      totalCell.textContent = total.toFixed(2);
      updateGrandTotal();
    }
  
    function updateGrandTotal() {
      let totalSum = 0;
      document.querySelectorAll(".total").forEach(cell => {
        totalSum += parseFloat(cell.textContent) || 0;
      });
      document.getElementById("grand_total").textContent = totalSum.toFixed(2);
    }
  
    function refreshTable() {
      sketchup.refreshTable();
    }
  
    function saveToCSV() {
      sketchup.saveToCSV();
    }
  
    function saveViyarToCSV() {
      sketchup.saveViyarToCSV();
    }
  </script>
  </body>
  </html>
  HTML
  
  html
  end

  def self.load_prices
    begin
      FileUtils.mkdir_p(File.dirname(@prices_file))

      unless File.exist?(@prices_file)
        File.write(@prices_file, JSON.pretty_generate({}))
      end

      content = File.read(@prices_file)
      prices = JSON.parse(content)
      prices.transform_keys! { |key| URI.decode_www_form_component(key) }
      prices
    rescue => e
      puts "Error loading prices: #{e.message}"
      {}
    end
  end

  def self.save_prices
    begin
      encoded_prices = @prices.transform_keys { |key| URI.encode_www_form_component(key) }
      File.write(@prices_file, JSON.pretty_generate(encoded_prices))
    rescue => e
      puts "Error saving prices: #{e.message}"
    end
  end
  end