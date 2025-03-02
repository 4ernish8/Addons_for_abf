require 'pathname'
require 'json' 

module FurnitureProperties
  def self.run

    plugin_folder = Pathname.new(__FILE__).parent.to_s
    suppliers_file = File.join(plugin_folder, 'settings.json')

    begin
      file_content = File.read(suppliers_file)
      suppliers = JSON.parse(file_content)
    rescue Errno::ENOENT
      UI.messagebox("Помилка: Файл settings.json не знайдено!")
      return
    rescue JSON::ParserError
      UI.messagebox("Помилка: Некоректний формат файлу settings.json!")
      return
    rescue => e
      UI.messagebox("Сталася помилка при читанні файлу settings.json:\n#{e.message}")
      return
    end
     suppliers = suppliers.sort 
    selection = Sketchup.active_model.selection
    if selection.empty?
      UI.messagebox("Оберіть компонент або групу!")
      return
    end
    prompts = ["Артикул / код", "Назва", "Одиниці виміру", "Постачальник", "Артикул виробника", "Дозамовити вручну", "Довжина профілю (м)"]
    defaults = [
      selection.first.get_attribute("dynamic_attributes", "art").to_s,
      selection.first.get_attribute("dynamic_attributes", "nazva").to_s,
      selection.first.get_attribute("dynamic_attributes", "odvm").to_s.empty? ? "" : selection.first.get_attribute("dynamic_attributes", "odvm").to_s,
      selection.first.get_attribute("dynamic_attributes", "post").to_s.empty? ? "" : selection.first.get_attribute("dynamic_attributes", "post").to_s,
      selection.first.get_attribute("dynamic_attributes", "artv").to_s,
      selection.first.get_attribute("dynamic_attributes", "dzm").to_s == "true" ? "Так" : "Ні",
      selection.first.get_attribute("dynamic_attributes", "lp").to_s
    ]

    list = [
      "",
      "",
      " |шт|компл|м", 
      "|#{suppliers.join('|')}", 
      "",
      "Ні|Так",
      ""
    ]
      results = UI.inputbox(prompts, defaults, list, "Заповніть потрібні вам данні")
         return if results == false

    if results[3] == defaults[3] && results[3].empty?
      results[3] = suppliers.first 
    end
    if results[3].downcase.include?("віяр") || results[5].downcase.include?("viyar")
      alt_art = results[0] 
      art = results[0] 
    else
      alt_art = results[0]
      art = ''
    end
    tip_f = ""
    selection.each do |sel|
      next unless sel.is_a?(Sketchup::ComponentInstance) || sel.is_a?(Sketchup::Group)
      sel.set_attribute("dynamic_attributes", "art", art)
      sel.set_attribute("dynamic_attributes", "nazva", results[1])
      sel.set_attribute("dynamic_attributes", "odvm", results[2])
      existing_post = sel.get_attribute("dynamic_attributes", "post").to_s
      if results[3] != existing_post
        sel.set_attribute("dynamic_attributes", "post", results[3])
      end

      sel.set_attribute("dynamic_attributes", "artv", results[4])
      sel.set_attribute("dynamic_attributes", "dzm", results[5] == "Так" ? true : false)
      sel.set_attribute("dynamic_attributes", "lp", results[6])
      sel.set_attribute("dynamic_attributes", "uchet", "так")
      sel.set_attribute("dynamic_attributes", "dopart", alt_art)
        dict_name = "ABF"
        dict = sel.attribute_dictionary(dict_name, true)
        if dict.nil?
          dict = sel.attribute_dictionary(dict_name, true)
        else
          dict.each_key { |key| dict.delete_key(key) }
        end
        if results[4]==""
          abf_name = results[1] +" | "+ results[3]
        else
          abf_name = results[1] + " [" + results[4] + "]" +" | "+ results[3]
        end
        if results[2] == "шт"
          dict["hinge-group-a-id"]=42586
          dict["is-hinge-part-b"] = true
          dict["setting-name"] = abf_name
        elsif results[2] == "компл"
          dict["is-minifix-part-a"] = true
          dict["minifix-group-b-id"] =42903
          dict["setting-name"] = abf_name
        elsif results[2] == "м"
          dict["article"] = ""
          dict["is-statistical-object"] = true
          dict["statistical-type"] = "length_measuring"
          dict["statistical-name"] = abf_name
        end

        selection.each do |entity|
          next unless entity.is_a?(Sketchup::Group)
          group = entity
          bounds = group.local_bounds
          a = bounds.width
          b = bounds.height
          c = bounds.depth
          x1, x2 = [a, b, c].sort[1..2]
          x3 = [a, b, c].min

          if x3 == 0
            tip_f = "Отвір"
          else
            tip_f = "Фурнітура 3D"
          end
        end

      if tip_f == "Фурнітура 3D"
        furniture_layer = Sketchup.active_model.layers.find { |layer| layer.name =~ /.*Фурнітура.*/ }
        unless furniture_layer
          furniture_layer = Sketchup.active_model.layers.add("Фурнітура")
        end
        selection = Sketchup.active_model.selection
        if selection.empty?
          UI.messagebox("Оберіть хоча б одну групу для зміни слою!")
          return
        end

        selection.each do |entity|
            next unless entity.is_a?(Sketchup::Group)
            entity.layer = furniture_layer
            sel.name = results[1]
            model = Sketchup.active_model
            selection = model.selection
            group = selection[0]
            bounds = group.bounds
            a = bounds.width
            b = bounds.height
            c = bounds.depth
            x1, x2 = [a, b, c].sort[1..2]
            if x1 == a && x2 == b || x1 == b && x2 == a
              selected_plane = "XY"
            elsif x1 == b && x2 == c || x1 == c && x2 == b
              selected_plane = "YZ"
            elsif x1 == a && x2 == c || x1 == c && x2 == a
              selected_plane = "XZ"
            end
            cross_line_size = 0.1.mm
            cl=cross_line_size/2
            center = bounds.center
            if selected_plane == "XY"
              start_point = Geom::Point3d.new(center.x, center.y + cross_line_size/2, center.z)
              end_point = Geom::Point3d.new(center.x, center.y - cross_line_size/2, center.z)
            elsif selected_plane == "YZ"
              start_point = Geom::Point3d.new(center.x, center.y, center.z + cross_line_size/2)
              end_point = Geom::Point3d.new(center.x, center.y, center.z - cross_line_size/2)
            elsif selected_plane == "XZ"
              start_point = Geom::Point3d.new(center.x + cross_line_size/2, center.y, center.z)
              end_point = Geom::Point3d.new(center.x - cross_line_size/2, center.y, center.z)
            end
            cross_line_1 = model.active_entities.add_line(start_point, end_point)
            if selected_plane == "XY"
              start_point = Geom::Point3d.new(center.x + cross_line_size/2, center.y, center.z)
              end_point = Geom::Point3d.new(center.x - cross_line_size/2, center.y, center.z)
            elsif selected_plane == "YZ"
              start_point = Geom::Point3d.new(center.x, center.y + cross_line_size/2, center.z)
              end_point = Geom::Point3d.new(center.x, center.y - cross_line_size/2, center.z)
            elsif selected_plane == "XZ"
              start_point = Geom::Point3d.new(center.x, center.y, center.z + cross_line_size/2)
              end_point = Geom::Point3d.new(center.x, center.y, center.z - cross_line_size/2)
            end
            cross_line_2 = model.active_entities.add_line(start_point, end_point)
            new_group = model.active_entities.add_group([cross_line_1, cross_line_2])
            new_group.name = "Мітка"
            cross_bounds = new_group.bounds
            cross_center = cross_bounds.center
            if selected_plane == "XY"
              translation = Geom::Vector3d.new(center.x - cross_center.x, center.y - cross_center.y, center.z - cross_center.z)
            elsif selected_plane == "YZ"
              translation = Geom::Vector3d.new(center.x - cross_center.x, center.y - cross_center.y, center.z - cross_center.z)
            elsif selected_plane == "XZ"
              translation = Geom::Vector3d.new(center.x - cross_center.x, center.y - cross_center.y, center.z - cross_center.z)
            end
            new_group.transform!(translation)
            selection = Sketchup.active_model.selection
            entities = selection.empty? ? Sketchup.active_model.entities : selection.to_a.grep(Sketchup::Group) + selection.to_a.grep(Sketchup::ComponentInstance)
            entities.each do |entity|
              if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
                has_marker = false
                entity.definition.entities.each do |sub_entity|
                  if sub_entity.is_a?(Sketchup::Group) && sub_entity.name == "Мітка"
                    has_marker = true
                    break
                  end
                end
                unless has_marker
                  group_center = entity.bounds.center
                  if entity.is_a?(Sketchup::ComponentInstance)
                    transformation = entity.transformation
                    new_group_instance = entity.definition.entities.add_instance(new_group.definition, group_center)
                    new_group_instance.transform!(transformation)
                  elsif entity.is_a?(Sketchup::Group)
                    new_group_instance = entity.entities.add_instance(new_group.definition, group_center)
                  end
                  new_group_instance.transform!(entity.transformation.inverse)
                  new_group_instance.transform!(Geom::Transformation.new([0, 0, 0]))
                  new_group_instance.name = "Мітка"
                end
              end
            end
            new_group.erase!
            Sketchup.active_model.active_view.refresh
          end
        elsif tip_f == "Отвір"
          hole_layer = Sketchup.active_model.layers.find { |layer| layer.name == "-" }
          unless hole_layer
            hole_layer = Sketchup.active_model.layers.add("-")
          end
          selection = Sketchup.active_model.selection
          selection.each do |entity|
            next unless entity.is_a?(Sketchup::Group)
              entity.layer = hole_layer
              sel.name = 'ABF_Hole'
              selection = Sketchup.active_model.selection
              groups = selection.grep(Sketchup::Group)
              groups.each do |group|
                child_group = group.entities.find { |e| e.is_a?(Sketchup::Group) && e.name == "Мітка" }
                if child_group
                  group.entities.erase_entities(child_group)
                end
              end
            end
          end
    end
  end
end