module PokeAccess
  # The controls screen (0228_NewCommandScreen): two pages, each a column of translated descriptions painted beside
  # pictures of their keys (Graphics/Pictures/NewCmd/page1 and page2, as 0143_PSystem_Controls and Scene_Map read them).
  module XenoverseControls
    # Starts reading a screen that opens.
    def self.watch(scene)
      @scene, @pages = scene, {}
      PokeAccess::Info.clear_text
      PokeAccess::Cursor.reset(scene, :xenoverse_controls)
    end

    # Forgets the screen as it closes.
    def self.unwatch
      PokeAccess::Info.clear_text
      PokeAccess::Cursor.reset(@scene, :xenoverse_controls) if @scene
      @scene, @pages = nil, nil
    end

    # Keeps the descriptions painted on each page's sprite, top to bottom.
    def self.capture(args)
      return unless @scene && args[1].is_a?(Array)
      sprites = PokeAccess.ivar(@scene, :@sprites)
      return unless sprites.is_a?(Hash)
      [0, 1].each do |page|
        sprite = sprites["page#{page + 1}"]
        next unless sprite && args[0].equal?(sprite.bitmap)
        @pages[page] = args[1].select { |row| row.is_a?(Array) }.sort_by { |row| row[2].to_i }.map { |row| row[0] }
      end
    end

    # The keys each page pictures, in its order, each as the player has it now.
    def self.keys(page)
      key = lambda { |button, painted| PokeAccess::KeyHints.key(button, painted) }
      if page == 0
        arrows = [:up, :down, :left, :right].map { |button| key.call(button, PokeAccess::I18n.t("btn_#{button}".to_sym)) }
        [PokeAccess::Routes::Text.and_list(arrows), key.call(:c, PokeAccess::I18n.t(:xenoverse_keys_confirm)),
         key.call(:b, PokeAccess::I18n.t(:xenoverse_keys_cancel)), key.call(:a, "Z"), "F5"]
      else
        [key.call(:r, "W"), key.call(:x, "A"), key.call(:y, "S"), key.call(:z, "D")]
      end
    end

    # Says the page in sight, each key with its description.
    def self.poll
      scene = @scene
      return unless scene
      page = PokeAccess.ivar(scene, :@page)
      return unless [0, 1].include?(page) && @pages[page]
      sprite = PokeAccess.sprite(scene, "page#{page + 1}")
      return unless sprite && !(sprite.disposed? rescue false) && sprite.x == 0
      labels, buttons = @pages[page], keys(page)
      return unless labels.length == buttons.length
      lines = []
      labels.each_with_index do |label, i|
        lines.push(PokeAccess::I18n.t(:xenoverse_named, :name => buttons[i], :text => PokeAccess.clean(label.to_s)))
      end
      text = PokeAccess.sentences(lines)
      PokeAccess::Cursor.announce(scene, :xenoverse_controls, [page, text], true, false) do
        PokeAccess::Info.set_info(:text, text, text)
        text
      end
    end
  end
end

PokeAccess::SceneWatcher.wire("CommandScreen", :initialize, PokeAccess::XenoverseControls)
PokeAccess::Game.define("xenoverse") do
  kernel("pbDrawTextPositions", :after) { |args, _result| PokeAccess::XenoverseControls.capture(args) }
end
