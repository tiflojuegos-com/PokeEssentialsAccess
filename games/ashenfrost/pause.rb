# Ashen Frost's pause menu (001_UI_PauseMenu.rb) sets its info box anew on every frame of the menu's loop: the map, the
# money and the level cap. Core says that box on every call, which here would never stop, so it is said once per opening
# and per change of its text.
module PokeAccess
  module AshenPause
    def self.opened
      @said = nil
    end

    # The box as its rows read, label and value together: <r> only aligns the value to the right.
    def self.box(text)
      return unless text.is_a?(String) && text != @said
      @said = text
      line = PokeAccess.clean_fields(text.gsub("<r>", ""))
      PokeAccess.speak(line, false) unless line.empty?
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  override(PokeAccess, :say_info_box) { |_mod, _original, args| PokeAccess::AshenPause.box(args[0]) }
  before("PokemonPauseMenu_Scene", :pbStartScene) { |_scene, _args| PokeAccess::AshenPause.opened }
end
