module Otvirset
  def self.run
model = Sketchup.active_model
selection = model.selection

if selection.empty?
  UI.messagebox("Оберіть отвір/отвори")
else
  model.start_operation("Зміна отвору", true)

  begin
    layers_set = Set.new
    diameters_set = Set.new
    groups_data = []

    selection.each do |entity|
      next unless entity.is_a?(Sketchup::Group)
      group = entity
      entities = group.entities
      group_layer = nil
      group_diameter = nil
      group_circle_center = nil
      group_circle_normal = nil

      entities.each do |elem|
        if elem.is_a?(Sketchup::Edge) && elem.curve && elem.curve.is_a?(Sketchup::ArcCurve)
          group_layer = elem.layer
          group_diameter = elem.curve.radius * 2.0 * 25.4
          group_circle_center = elem.curve.center
          group_circle_normal = elem.curve.normal
          break
        end
      end

      unless group_layer && group_diameter
        UI.messagebox("Це не схоже на отвір: #{group.name}")
        next
      end
      layer_name = group_layer.name
      diameter = nil
      depth = nil
      article1 = nil
      article2 = nil
      if layer_name =~ /(?:D(\d+(\.\d+)?))?_?DEPTH(F|\d+(\.\d+)?)(?:[-_](?:\$|ARTICLE)(\d+))?(?:[-_]\$(\d+))?/
        diameter = $1 ? $1.to_f : nil          
        depth = $3                              
        article1 = $5                           
        article2 = $6                           
      end

      unless depth
        UI.messagebox("Не знайдено данних про глибину: #{layer_name}")
        next
      end
      layers_set.add(group_layer)
      diameters_set.add(group_diameter.round(3)) 
      groups_data << {
        group: group,
        layer: group_layer,
        diameter: diameter || group_diameter, 
        center: group_circle_center,
        normal: group_circle_normal,
        depth: depth,
        article1: article1,
        article2: article2
      }
    end
    if layers_set.size > 1
      UI.messagebox("Обрані різні отвори")
    elsif diameters_set.size > 1
      UI.messagebox("Отвори мають різний діаметр")
    else
      common_diameter = diameters_set.to_a.first
      common_depth = groups_data.first[:depth]
      common_article1 = groups_data.first[:article1]
      common_article2 = groups_data.first[:article2]
      prompts = ["Диаметр (мм):", "Глибина (мм або F):", "Артикул:", "Артикул 2:"]
      defaults = [common_diameter.to_s, common_depth.to_s, common_article1.to_s, common_article2.to_s]
      input = UI.inputbox(prompts, defaults, "Заміна отвору")

      if input
        new_diameter = input[0].to_f
        new_depth = input[1]
        new_article1 = input[2]
        new_article2 = input[3]
        diameter_part = if new_diameter > 0
                          new_diameter_formatted = new_diameter == new_diameter.to_i ? new_diameter.to_i : new_diameter
                          "D#{new_diameter_formatted}_"
                        else
                          ""
                        end

        depth_part = "DEPTH#{new_depth}"
        article_part = if new_article2.strip.empty?
                         "-$#{new_article1}" unless new_article1.strip.empty?
                       else
                         "-$#{new_article1}-$#{new_article2}"
                       end
        new_layer_name = "#{diameter_part}#{depth_part}#{article_part}".chomp("_")
        if new_layer_name.length > 26
          new_layer_name = "#{depth_part}#{article_part}".chomp("_")
        end
        new_layer = model.layers[new_layer_name] || model.layers.add(new_layer_name)
        groups_data.each do |data|
          group = data[:group]
          entities = group.entities
          entities.clear!
          new_diameter_in_inches = new_diameter * 0.0393701
          radius = new_diameter_in_inches / 2.0
          circle = entities.add_circle(data[:center], data[:normal], radius)
          face = entities.add_face(circle)
          face.erase! if face
          entities.add_cpoint(data[:center])
          entities.each do |element|
            element.layer = new_layer
          end
        end

        UI.messagebox("Отвір оновлено: '#{new_layer_name}'")
      end
    end
  rescue StandardError => e
    model.abort_operation 
    UI.messagebox("Помилка #{e.message}")
  else
    model.commit_operation 
  end
end

  end
end


