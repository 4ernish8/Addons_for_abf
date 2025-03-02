module Vzvit
  def self.add_attribute_if_absent(group, key, value, dict_name)
    if group.attribute_dictionary(dict_name).nil? || group.attribute_dictionary(dict_name)[key].nil?
      group.set_attribute(dict_name, key, value)
    end
  end

  def self.update_groups_dynamic_attributes(entities, dict_name)
    entities.each do |entity|
      if entity.is_a?(Sketchup::Group)
        dict = entity.attribute_dictionary(dict_name)
        
        if dict && dict["is-screw"] == true
          next
        end
        
        if dict && dict["is-minifix-part-a"] == true && entity.get_attribute("dynamic_attributes", "nazva").nil?
          value = dict["setting-name"]
          add_attribute_if_absent(entity, "nazva", value, "dynamic_attributes")
        elsif dict && !dict["component-counter"].nil? && entity.get_attribute("dynamic_attributes", "nazva").nil?
          component_counter = dict["component-counter"]
          name = component_counter.split('"')[-2]
          value = name
          add_attribute_if_absent(entity, "nazva", value, "dynamic_attributes")
        elsif dict && dict["statistical-type"] == "length_measuring"
          add_attribute_if_absent(entity, "odvm", "м", "dynamic_attributes")
          if entity.get_attribute("dynamic_attributes", "nazva").nil?
            statistical_name = dict["statistical-name"]
            add_attribute_if_absent(entity, "nazva", statistical_name, "dynamic_attributes")
          end
        end
        update_groups_dynamic_attributes(entity.entities, dict_name)
      end
    end
  end

  def self.run
    model = Sketchup.active_model
    entities = model.entities
    update_groups_dynamic_attributes(entities, "ABF")
  end
end
