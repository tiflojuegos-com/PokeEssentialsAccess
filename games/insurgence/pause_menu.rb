module PokeAccess
  # Insurgence's pause menu (PokemonMenu#pbStartPokemonMenu, opened by Scene_Map#call_menu): its Game_Temp has no
  # in_menu for the menu to set, so the menu's run is marked here and the map counts as covered while it lasts.
  module InsurgencePause
    @open = false

    # Whether the pause menu, or a screen opened from it, is up.
    def self.open?
      @open ? true : false
    end

    # Runs the menu with open? true, put back however it ends.
    def self.during
      was = @open
      @open = true
      yield
    ensure
      @open = was
    end
  end
end

PokeAccess::Game.define("insurgence") do
  around("PokemonMenu", :pbStartPokemonMenu) { |_menu, nxt, _a| PokeAccess::InsurgencePause.during { nxt.call } }
  override("PokeAccess::Control", :on_map?) do |_m, original, _a|
    original.call && !PokeAccess::InsurgencePause.open?
  end
end
