# Royal's grid pause menu (Menu2): @items entries are [icon_name, label, method] and @selected_item the cursor, read
# on each pbActualizarIconosMenu. The words are the icons', since the undrawn label field can be wrong.
module PokeAccess
  module RoyalGridMenu
    @open = 0
    @last = nil

    # param menu the Menu2 whose loop is starting, which an entry that ends it marks
    def self.open!(menu = nil)
      @open += 1
      @menu = menu
    end

    def self.close!; @open -= 1 if @open > 0; end

    # The word inside each icon, by its base name (the "_en" English set included); the words come from lang/.
    ICON_WORDS = { "dex" => :rgrid_dex, "pokeball" => :rgrid_pokemon, "pkmnpc" => :rgrid_pc,
                   "bag" => :rgrid_bag, "save" => :rgrid_save, "map" => :rgrid_map,
                   "trainer" => :rgrid_cards, "logros" => :rgrid_achievements, "regalo" => :rgrid_gifts,
                   "options" => :rgrid_options }

    # The word an entry's icon carries, or its label field for an icon the table does not know.
    def self.label(item)
      key = ICON_WORDS[item[0].to_s.sub(/_en\z/, "")]
      key ? PokeAccess::I18n.t(key) : item[1]
    end

    # Speaks the focused command (kept for the return); the info key answers with the trainer, as in any pause menu.
    def self.focus(menu)
      PokeAccess::Info.set_info(:trainer, nil)
      items = PokeAccess.ivar(menu, :@items)
      idx   = PokeAccess.ivar(menu, :@selected_item)
      return unless items.is_a?(Array) && idx && items[idx].is_a?(Array)
      return unless PokeAccess::Cursor.changed?(menu, :pm, idx)
      word = label(items[idx])
      return if word.nil? || word.to_s.empty?
      @last = word.to_s
      PokeAccess.speak_clean(@last, true)
      panel(menu)
    rescue StandardError
      nil
    end

    # The money written beside the grid and, while key hints are said, the bar painted under it; said once after the
    # first focused icon (no clock, as in every panel).
    def self.panel(menu)
      return if PokeAccess.ivar(menu, :@access_panel_said)
      menu.instance_variable_set(:@access_panel_said, true)
      texts = PokeAccess.ivar(menu, :@currentTexts)
      lines = (texts.is_a?(Array) && texts[1]) ? [texts[1]] : []
      lines.concat(key_bar) if PokeAccess::Verbosity.hints?
      PokeAccess::PausePanel.say(lines) unless lines.empty?
    end

    # The bar the background (menubg) paints under the grid: D saves from any icon (Input::SPECIAL, said as the key
    # the player has it on now) and F1 opens the controls.
    def self.key_bar
      [PokeAccess::I18n.t(:rgrid_key_save, :key => PokeAccess::KeyHints.key(:z, "D")),
       PokeAccess::I18n.t(:rgrid_key_controls)]
    end

    # The top-level functions the grid dispatches, whose return means the player is back (not all of them fade);
    # not exitMenuPause, which ends the menu.
    ENTRIES = %w[openDex openParty openBag openTrainerCard openSave openMap
                 openPCStorageFromPauseMenu openTarjetaLiga openLogros openRegaloMisterioso openOptions]

    # Back from an entry, repeats the focused command while the menu is open (two entries are reachable from the
    # field too) and the entry did not end it (@exit, @retorno_vuelo).
    def self.returned
      return if @menu && (PokeAccess.ivar(@menu, :@exit) || PokeAccess.ivar(@menu, :@retorno_vuelo))
      return unless @open > 0
      PokeAccess::Info.set_info(:trainer, nil)
      PokeAccess.speak_clean(@last, true) if @last
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("royal") do
  after("Menu2", :pbActualizarIconosMenu) { |menu, _ret, _args| PokeAccess::RoyalGridMenu.focus(menu) }
  # pbStartPokemonMenu is the menu's loop, held so the entries' returns know the menu is still on screen.
  around("Menu2", :pbStartPokemonMenu) do |menu, nxt, _a|
    PokeAccess::RoyalGridMenu.open!(menu)
    begin; nxt.call; ensure; PokeAccess::RoyalGridMenu.close!; end
  end
  PokeAccess::RoyalGridMenu::ENTRIES.each do |fn|
    kernel(fn, :after) { |_args, _r| PokeAccess::RoyalGridMenu.returned }
  end
end
