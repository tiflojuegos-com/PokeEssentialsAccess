module PokeAccess
  # The options screen (0227_NewOptions, PokemonOptionScene): a column of bars (@sprites["opt#{i}"]), each with its
  # option's name and a strip of values under a cursor (selIndex), the row chosen by @index; Default, Save and Back on
  # the lower bar.
  module XenoverseOptions
    # Starts reading a screen that opens.
    def self.watch(scene)
      @scene, @opening = scene, true
      PokeAccess::Cursor.reset(self, :xenoverse_options)
    end

    # Forgets the screen as it closes.
    def self.unwatch
      PokeAccess::Info.clear_text
      @scene = nil
    end

    # Says the row under the cursor and its value whenever either changes; the first time after the painted title.
    def self.poll
      scene = @scene
      return unless scene
      options = PokeAccess.ivar(scene, :@PokemonOptions)
      index = PokeAccess.ivar(scene, :@index)
      return unless options.is_a?(Array) && index.is_a?(Integer) && options[index]
      bar = PokeAccess.sprite(scene, "opt#{index}")
      values = (bar.options rescue nil)
      sel = (bar.selIndex rescue nil)
      return unless values.is_a?(Array) && sel.is_a?(Integer) && values[sel]
      row = PokeAccess::I18n.t(:xenoverse_named, :name => PokeAccess.clean(options[index].name.to_s),
                                                  :text => PokeAccess.clean(values[sel].to_s))
      row = PokeAccess::Verbosity.list_entry(row, index + 1, options.length)
      text = @opening ? opening(scene, row) : row
      spoken = PokeAccess::Cursor.announce(self, :xenoverse_options, [index, sel], !@opening) do
        PokeAccess::Info.set_info(:text, row)
        text
      end
      @opening = false if spoken
    end

    # The painted title before the first row, and the lower bar's Default and Save with their keys as a hint.
    def self.opening(scene, row)
      title = PokeAccess::XenoversePainted.of_sprite(PokeAccess.sprite(scene, "banner")).first.to_s
      bar = PokeAccess::XenoversePainted.of_sprite(PokeAccess.sprite(scene, "lowerbar"))
      line = PokeAccess.sentences([title, row])
      PokeAccess::XenoversePainted.with_hint(line, [[bar[0], :x, "A"], [bar[1], :y, "S"]])
    end
  end

  # The Mystery Gift menu (0247_MGH, MysteryGiftScene, from the pause menu): two buttons, Get a Mystery Gift and Quit
  # (@selIndex), each with the line its message window shows (@messages).
  module XenoverseMysteryGift
    BUTTONS = %w[code exit]

    # Starts reading a menu that opens.
    def self.watch(scene)
      @scene = scene
      PokeAccess::Cursor.reset(self, :xenoverse_gift)
    end

    # Forgets the menu as it closes.
    def self.unwatch
      PokeAccess::Info.clear_text
      @scene = nil
    end

    # Says the button under the cursor and its message whenever the cursor moves.
    def self.poll
      scene = @scene
      return unless scene
      index = PokeAccess.ivar(scene, :@selIndex)
      buttons = PokeAccess.ivar(scene, :@commands)
      messages = PokeAccess.ivar(scene, :@messages)
      return unless index.is_a?(Integer) && buttons.is_a?(Hash) && messages.is_a?(Array) && BUTTONS[index]
      label = PokeAccess::XenoversePainted.of_sprite(buttons[BUTTONS[index]]).last
      return if label.nil?
      text = PokeAccess.sentences([label, PokeAccess.clean(messages[index].to_s)])
      PokeAccess::Cursor.announce(self, :xenoverse_gift, index, true, false) do
        PokeAccess::Info.set_info(:text, text)
        text
      end
    end
  end
end

PokeAccess::SceneWatcher.wire("PokemonOptionScene", :pbOptions, PokeAccess::XenoverseOptions)
PokeAccess::SceneWatcher.wire("MysteryGiftScene", :initialize, PokeAccess::XenoverseMysteryGift)
