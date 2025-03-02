
module Changelayer
    def self.find_and_change_groups(entities, name, target_layer, groups_to_change)
      entities.each do |entity|
        if entity.is_a?(Sketchup::Group)
          if entity.name.downcase.include?(name.downcase) && entity.layer != target_layer
            groups_to_change << entity
          end
          find_and_change_groups(entity.entities, name, target_layer, groups_to_change) if entity.respond_to?(:entities)
        elsif entity.is_a?(Sketchup::ComponentInstance)
          find_and_change_groups(entity.definition.entities, name, target_layer, groups_to_change)
        end
      end
    end
  
    def self.change_group_layer_by_name(name, target_layer_name)
      model = Sketchup.active_model
      entities = model.entities
      target_layer = model.layers.add(target_layer_name)
      groups_to_change = []
  
      find_and_change_groups(entities, name, target_layer, groups_to_change)
  
      groups_to_change.each { |group| group.layer = target_layer }
    end
  
    def self.run
      change_group_layer_by_name("ABF_Hole", "-")
    end
  end
  