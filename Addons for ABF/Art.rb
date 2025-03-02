module Art
  def self.run
    def self.process_groups(entities)
      entities.each do |entity|
        if entity.is_a?(Sketchup::Group)
          group = entity

          art_value = group.get_attribute "dynamic_attributes", "art", nil
          dopart_value = group.get_attribute "dynamic_attributes", "dopart", nil

          if art_value.nil? || art_value.empty?
            if !dopart_value.nil? && !dopart_value.empty?
              group.set_attribute "dynamic_attributes", "art", dopart_value
              puts "Артикул оновлено #{group.name.empty? ? 'Unnamed Group' : group.name}"
            else
            
            end
          else

          end

          # Рекурсивный вызов для обработки вложенных групп
          process_groups(group.entities) if group.entities.any?

        elsif entity.is_a?(Sketchup::ComponentInstance)
            # Рекурсивный вызов для обработки вложенных групп и компонентов
            process_groups(entity.definition.entities) if entity.definition.entities.any?
        end
      end
    end

    model = Sketchup.active_model
    process_groups(model.entities)
    puts "Operation complete."
  end
end
