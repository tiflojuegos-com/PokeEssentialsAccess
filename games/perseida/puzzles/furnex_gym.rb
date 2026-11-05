# Perseida's Furnex gym (map 129): four guide statues each ask in which room of the palace statues like the ones in front are
# seen. The choice goes to variable 37 and the flame beyond takes it: the right one moves variable 38 on, any other fights the
# player. The assist says the room the flame wants, as the statue's own menu words it. The right-hand statues of three pairs
# are named "2" by the game, so they are named here.
module PokeAccess
  module PerseidaFurnex
    MAP = 129
    CHOICE = 37
    PROGRESS = 38
    FLAMES = { 1 => 5, 14 => 7, 18 => 17, 10 => 13 }
    ANCIENT_STATUES = [8, 12, 16]
  end
end

PokeAccess::Game.define("perseida") do
  furnex = PokeAccess::PerseidaFurnex
  mechanic(:state, furnex::MAP) do
    auto
    name furnex::ANCIENT_STATUES, :perseida_furnex_statue, :when => false
    furnex::FLAMES.each do |statue, flame|
      right_choice statue, :takes => { :var => furnex::CHOICE, :compared_by => flame, :moving => furnex::PROGRESS }
    end
  end
end
