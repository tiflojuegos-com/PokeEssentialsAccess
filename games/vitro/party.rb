# Vitro's party screen (0160_PScreen_Party, 0293_Evolucion party) marks with an arrow a member that can evolve now, and paints
# the team's balanced level and its rank under the panels, once, as it opens.
module PokeAccess
  module VitroParty
    # The line the screen paints under the panels, from the party reading's medium.
    def self.level_line
      line = _INTL("Nv. Medio {1} (R: {2})", clGetLevelMedia, $game_variables[25] + 1)
      PokeAccess::Verbosity.line(:party, [[line, :medium]])
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Whether the panel draws the arrow, by the game's own check.
    def self.can_evolve?(pk)
      pbCanEvolveNow?(pk) ? true : false
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end
  end
end

PokeAccess::Game.define("vitro") do
  override("PokeAccess::Party", :panel_marks) do |_mod, original, args|
    PokeAccess::VitroParty.can_evolve?(args[0]) ? original.call + [PokeAccess::I18n.t(:vitro_can_evolve)] : original.call
  end
  read_on_open("PokemonScreen_Scene", :pbStartScene, :optional => true, :hook_container => true) do |_scene|
    PokeAccess::VitroParty.level_line
  end
end
