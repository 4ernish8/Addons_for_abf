module MoveAttachment
  class GroupSelectorTool
  def initialize(group)
    @group = group
  end
  def activate
    Sketchup.active_model.selection.add(@group)
  end
  def deactivate(view)
    begin
      Sketchup.active_model.selection.remove(@group) if Sketchup.active_model.selection.include?(@group)
    rescue
      # здесь можно выполнить любой код, который необходимо выполнить при возникновении ошибки
      return
    end
  end
 end

 def self.run
  model = Sketchup.active_model
  entities = model.entities
  model.start_operation('Move Attachment', true) # Включаем операцию отмены
  my_selection = Sketchup.active_model.selection
 my_selected_groups = Sketchup.active_model.entities.grep(Sketchup::Group).select { |g| my_selection.include?(g) }
 my_selected_groups.each do |my_group|
 Sketchup.active_model.selection.clear
 Sketchup.active_model.tools.push_tool(GroupSelectorTool.new(my_group))
 #Очищаем неиспользуемые компоненты и материалы
 model = Sketchup.active_model
 entities = model.entities
 manager = model.layers
 model.definitions.purge_unused
 model.materials.purge_unused
 #Переместить слои созданные ABF в папку ABF
 abf_folder = nil
 manager.each_folder do |folder|
   if folder.name == 'ABF'
    abf_folder = folder
    break
   end
 end
 if abf_folder
   manager.remove_folder(abf_folder)
 end
 abf_folder = manager.add_folder('ABF')
 layers_to_move = manager.select { |layer| layer.name.include?('ABF_G') || layer.name.include?('DEPTH')  || layer.name.include?('1COUNTERSINK') || layer.name.include?('ABF-DS') }
 layers_to_move.each { |layer| abf_folder.add_layer(layer) }
 # Скрыть все, кроме выделенной группы
 current_group = model.selection[0]
 if current_group.is_a?(Sketchup::Group)
 group_name = current_group.name
 entities.each do |entity|
   if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
     if entity != current_group
       entity.hidden = true
     end
  end
 end
 current_group.explode
 # Найти группы содержащие в имени "шухляда" (в любом регистре)
drawer_groups = entities.grep(Sketchup::Group).select do |g|
g.name.downcase.include?("шухляда") &&
  (!g.attribute_dictionary("dynamic_attributes") || 
  g.get_attribute("dynamic_attributes", "uchet", "").downcase != "так")
end

drawer_groups.each_with_index do |drawer, index|
drawer_layer_name = "#{drawer.name.downcase.sub('шухляда', 'шухлядка')}_#{index+1}"
drawer_layer = model.layers.add(drawer_layer_name)
drawer_entities = drawer.entities
drawer_entities.each do |entity|
  if entity.is_a?(Sketchup::Group)
    entity.layer = drawer_layer
  end
end
drawer.explode
end

 # Поиск деталей АБФ и перенос на них обработок
groups_array = entities.find_all do |e|
e.is_a?(Sketchup::Group) &&
(
  e.name =~ /^__\d+/ || # Группа с именем, соответствующим шаблону "__число"
  (e.attribute_dictionaries && e.attribute_dictionary("ABF") && e.get_attribute("ABF", "is-board", nil)) # Или словарь ABF с атрибутом is-board
)
end

groups_array.each_with_index do |group, index|
model.selection.clear
model.selection.add(group)
selected_group = model.selection[0]
touching_groups = []

entities.each do |entity|
  next unless entity.is_a?(Sketchup::Group)
  next unless entity.name.downcase.include?("abf_intersect") || entity.name.downcase.include?("hole") || entity.layer.name == "-"
  next if entity == selected_group

  if selected_group.bounds.contains?(entity.bounds.center)
    touching_groups << entity
  end
end

model.selection.clear
touching_groups.each do |group|
  model.selection.add(group)
end

last_selected_group = selected_group
target_group = last_selected_group
selected_groups = touching_groups
target_group_transformation = target_group.transformation

selected_groups.each do |group|
  group_transformation = group.transformation
  new_transform = target_group_transformation.inverse * group_transformation
  new_group = target_group.entities.add_instance(group.definition, new_transform)
  new_group.name = group.name

  group.attribute_dictionaries.each do |dict|
    dict.each do |key, value|
      new_group.set_attribute(dict.name, key, value)
    end
  end
end

selected_groups.each(&:erase!)
end

 #Удаление вспомагательных групп
 %w[Мітка Габарит Мітки Відмітки].each do |name|
   entities.grep(Sketchup::Group).each do |group|
     if group.name == name && group.visible?
       group.erase!
     end
   end
 end
 #Удаляем группу "• Фурнітура", если она существует а затем собрать всю фурнитуру в одну группу
 furn_group = model.entities.find { |e| e.is_a?(Sketchup::Group) && e.name == "• Фурнітура" }
 furn_group.explode if furn_group
 # Выбираем все группы на слое с названием, содержащим строку "Фурнітура", и добавляем их в текущую выборку
 selection = model.selection
 model.active_entities.each do |entity|
   next unless entity.is_a?(Sketchup::Group) && entity.layer.name.include?("Фурнітура") && entity.visible?
     selection.add(entity)
   end
   # Если выборка не пустая, создаем из выделенных групп новую группу с именем "• Фурнітура"
   if not model.selection.empty?
     new_group = model.entities.add_group(model.selection.to_a)
     new_group.name = "• Фурнітура"
   end
   model.selection.clear
   #Создать шухляды
   model.layers.each do |layer|
     next unless layer.name.downcase.include?("шухлядка")
       layer_entities = entities.select { |entity| entity.layer == layer }
       if layer_entities.any?
         drawer_name = layer.name.split("_")[0]
         drawer_index = layer.name.split("_")[1].to_i
         drawer_group = entities.add_group(layer_entities)
         drawer_group.name = "__#{drawer_name}"
         drawer_group.layer = layer
       end
     end
     #Перенести шухляды на слой
     drawer_groups1 = entities.grep(Sketchup::Group).select { |g| g.name.downcase.include?("__шухлядка") }
     drawer_groups1.each_with_index do |drawer, index|
     drawer_layer_name1 = "7. Шухляди"
     drawer_layer1 = model.layers.add(drawer_layer_name1)
     drawer_entities1 = drawer.entities
     drawer_entities1.each do |entity|
       if entity.is_a?(Sketchup::Group)
         entity.layer = drawer_layer1
       end
     end
     end
     while (layer = model.layers.find {|layer| layer.name.downcase.include?("шухлядка")}) != nil
       model.layers.remove(layer)
     end
     #Восстановить видимость и собрать в группу
     visible_entities = entities.select { |entity| !entity.hidden? }
     new_group = entities.add_group(visible_entities)
     new_group.name = group_name
     entities.each do |entity|
       entity.hidden = false
     end
     else
     UI.messagebox("Модуль не обрано")
   end
 end
 model.commit_operation # Завершаем операцию отмены
 UI.messagebox "Кріплення перенесено"
end
end
