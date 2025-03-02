module Prefixx
  def self.run
    prompts = ["Префікс", ""]
    defaults = ["", "Додати префікс"]
    list = ["", "Додати префікс|Видалити префікс"]
    results = UI.inputbox(prompts, defaults, list, "Додати префікс до деталей")
    
    if results == false
      UI.messagebox("Відмінено користувачем")
      return
    end


    def self.make_groups_unique(group)
      group.entities.each do |entity|
        if entity.is_a?(Sketchup::Group)
          entity.make_unique 
          make_groups_unique(entity) 
        end
      end
    end
    def self.rename_groups(group, regex, prefix)
      group.entities.each do |entity|
        if entity.is_a?(Sketchup::Group)
          rename_groups(entity, regex, prefix)
          if entity.name =~ regex
            new_name = entity.name.sub(regex, "\\0 [#{prefix}]")
            entity.name = new_name.strip
          end
        end
      end
    end
    def self.remove_prefix(group)
      group.entities.each do |entity|
        if entity.is_a?(Sketchup::Group)
          remove_prefix(entity)
          entity.name = entity.name.gsub(/\[.*?\] /, '').strip
        end
      end
    end
    def self.remove_prefix2(group)
      group.entities.each do |entity|
        if entity.is_a?(Sketchup::Group)
          remove_prefix2(entity)
          entity.name = entity.name.gsub(/\[.*?\] /, '').gsub(/^__\d+\. /, '').strip
        end
      end
    end
    Sketchup.active_model.start_operation("Перейменування груп", true)
    
    selection = Sketchup.active_model.selection
    return unless selection.length == 1 && selection[0].is_a?(Sketchup::Group)
    
    group = selection[0]

    case results[1]
    when "Додати префікс"
      prefix = results[0].empty? ? group.name : results[0]
      self.make_groups_unique(group)

      regex = /^__\d+\./
      new_name = results[0].empty? ? group.name : "[#{prefix}] #{group.name}"
      group.name = new_name.strip

      self.rename_groups(group, regex, prefix)

    when "Видалити префікс"
      group.name = group.name.gsub(/\[.*?\] /, '').strip
      self.remove_prefix(group)

    else
      group.name = group.name.gsub(/\[.*?\] /, '').gsub(/^__\d+\. /, '').strip
      self.remove_prefix2(group)
    end

    Sketchup.active_model.commit_operation
    Sketchup.active_model.selection.clear
  end
end
