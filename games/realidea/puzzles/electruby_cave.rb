# The Electruby Cave (map 155): red crystals that shoot to the end of their run when bumped, once each (their self switch
# A), and that event 14 puts back on every entry, but for the one by the exit to Garnet Village.
module PokeAccess
  module RealideaCave
    MAP = 155
    CRYSTALS = [2, 5, 6, 7]

    # True once a crystal has been pushed.
    def self.spent?(id)
      $game_self_switches[[MAP, id, "A"]] ? true : false
    end
  end
end

PokeAccess::Game.define("realidea") do
  cave = PokeAccess::RealideaCave
  mechanic(:state, cave::MAP) do
    auto
    name cave::CRYSTALS, lambda { |ev| cave.spent?(ev.id) ? :rea_crystal_spent : :rea_crystal }
    active { true }
    arrival_hint :rea_crystal_rule
    hint :rea_crystal_hint
  end
end
