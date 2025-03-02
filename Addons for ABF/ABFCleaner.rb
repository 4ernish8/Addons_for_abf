module ABFCleaner
  def self.run
    model = Sketchup.active_model
    model.start_operation("ABF Cleanup", true, true, true)
    selection = model.selection

    if selection.empty?
      UI.messagebox("Нічого не обрано-очищуємо мітки в усієї моделі...")
      process_entities(model.entities, clear_board_index: true)
    elsif selection.length > 1
      UI.messagebox("Очищуємо мітки лише в обраних групах...")
      selection.grep(Sketchup::Group).each { |group| process_entity(group, clear_board_index: true) }
      selection.grep(Sketchup::Group).each { |group| process_entities(group.entities, clear_board_index: true) } # Додано обробку вкладених груп для множинного вибору
    else
      entity = selection.first
      return model.abort_operation unless entity.is_a?(Sketchup::Group)

      abf_dict = entity.attribute_dictionary("ABF", false)
      return model.abort_operation unless abf_dict && abf_dict.keys.include?("board-index")

      current_value = abf_dict["board-index"]

      prompts = ["Оберіть дію:", "№ деталі:"]
      defaults = ["Змінити", current_value ? current_value.to_s : ""]
      list = ["Видалити|Змінити", ""]

      input = UI.inputbox(prompts, defaults, list, "Видалення/зміна номера деталі")

      return model.abort_operation unless input

      action, new_board_index = input

      if action == "Змінити"
        new_value = new_board_index.to_i

        if new_value != 0
          duplicate_groups = find_groups_with_board_index(new_value, entity, model.entities) 
          if duplicate_groups.any?
            UI.messagebox("Деталь з таким номером вже існує")

            duplicate_board_index_value = new_value
            model.selection.clear
            while model.active_path
              model.close_active
            end
            duplicate_groups_to_select = find_groups_with_board_index(duplicate_board_index_value, nil, model.entities)
            puts "Знайдені деталі з таким номером #{duplicate_board_index_value}:"
            duplicate_groups_to_select.each { |grp| puts "  #{grp.name} (ObjectID: #{grp.object_id})" }
            if duplicate_groups_to_select.empty?
              puts "**ВНИМАНИЕ: Список дубликатов ПУСТ! Проверьте find_groups_with_board_index!**"
            end
            duplicate_groups_to_select.each { |grp| model.selection.add(grp) }
            model.active_view.zoom_extents
            UI.messagebox("Виділені деталі з таким номером!")
            return model.abort_operation
          end
        end
        entity.set_attribute("ABF", "board-index", new_value)
        entity.make_unique 
        entities = entity.entities
        label_group = entities.find { |e| e.is_a?(Sketchup::Group) && e.name == "_ABF_Label" }
        entities.erase_entities(label_group) if label_group
      elsif action == "Видалити"
        entity.set_attribute("ABF", "board-index", nil)
      end
      process_entity(entity, clear_board_index: action == "Видалити")
      process_entities(entity.entities, clear_board_index: action == "Видалити") 
    end
    model.commit_operation
    UI.messagebox("Мітки видалені!")
  end
  def self.find_groups_with_board_index(value, exclude_group = nil, entities_to_search = nil)
    model = Sketchup.active_model
    groups_with_value = []
    entities = entities_to_search || model.entities 
    entities.each do |entity|
      if entity.is_a?(Sketchup::Group)
        next if entity == exclude_group
        abf_dict = entity.attribute_dictionary("ABF", false)
        if abf_dict && abf_dict.keys.include?("board-index") && abf_dict["board-index"] == value
          groups_with_value << entity
        end
        groups_with_value.concat(find_groups_with_board_index(value, exclude_group, entity.entities)) 
      end
    end

    groups_with_value
  end

  def self.process_entities(entities, clear_board_index: false)
    entities.each do |entity|
      if entity.is_a?(Sketchup::Group)
        process_entity(entity, clear_board_index: clear_board_index)
        process_entities(entity.entities, clear_board_index: clear_board_index) 
      end
    end
  end

  def self.process_entity(entity, clear_board_index: false)
    return unless entity.is_a?(Sketchup::Group)

    abf_dict = entity.attribute_dictionary("ABF", false)
    if clear_board_index && abf_dict && abf_dict.keys.include?("board-index")
      entity.set_attribute("ABF", "board-index", nil)
    end

    entity.entities.each do |sub_entity|
      if sub_entity.is_a?(Sketchup::Group) && sub_entity.name == "_ABF_Label"
        sub_entity.erase!
      end
    end

    if abf_dict && abf_dict["is-board"] == true
      clean_group_name(entity)
    end
  end

  def self.clean_group_name(entity)
    return unless entity.is_a?(Sketchup::Group)

    abf_dict = entity.attribute_dictionary("ABF", false)
    return unless abf_dict && abf_dict["is-board"] == true

    if entity.name.is_a?(String)
      old_name = entity.name
      cleaned_name = old_name.gsub(/^__[\d\.\s]+/, '').strip
      cleaned_name = "" if cleaned_name.empty? || old_name.match?(/^__\d+$/)

      entity.name = cleaned_name
      entity.definition.name = cleaned_name
      puts "Старе ім`я: #{old_name.inspect}, Нове ім`я: #{cleaned_name.inspect}"
    end
  end
end