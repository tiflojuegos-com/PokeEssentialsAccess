# Relict surfs by its Autosurf alone (997_Addons/Autosurf.rb): walking into water starts it on a floor whose map
# metadata has the dungeonDisplay flag while switch 60 is on, with no Pokemon, badge or look at who walks along. Its
# pbSurf never surfs, its party screen lists no field move and the ready menu's Surf wants a badge it never gives.
module PokeAccess
  module RelictSurf
    # True where walking into water starts Autosurf: on a map flagged dungeonDisplay, with switch 60 on.
    def self.autosurf?
      return false unless ($game_map.metadata.has_flag?("dungeonDisplay") rescue false)
      ($game_switches[60] rescue false) ? true : false
    end
  end
end

PokeAccess::Game.define("relict") do
  override("PokeAccess::FieldMoves", :can?) do |_mod, original, args|
    args[0] == :SURF ? PokeAccess::RelictSurf.autosurf? : original.call
  end

  # Autosurf asks nothing of who walks along.
  surf_company(:anyone)
end
