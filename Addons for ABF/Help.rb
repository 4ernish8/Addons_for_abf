module Help
    def self.open_help_dialog
      url = "https://4ernish8.wixsite.com/my-site-2"
  
      # Создаем новый веб-диалог
      dlg = UI::HtmlDialog.new({
        :dialog_title => "Інструкція по роботі з плагіном Addons for ABF",
        :preferences_key => "com.sketchup.examples.html_dialog",
        :scrollable => true,
        :resizable => true,
        :width => 1000,
        :height => 600,
        :left => 100,
        :top => 100,
        :min_width => 50,
        :min_height => 50,
        :max_width => 1100,
        :max_height => 1000
      })
  
      # Загружаем URL в диалоговое окно
      dlg.set_url(url)
  
      # Отображаем диалоговое окно
      dlg.show
    end
  end
  