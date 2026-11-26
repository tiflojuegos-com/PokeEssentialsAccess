# The Underroot (map 153), Treecko's cage: once the city is restored (switch 479) an unseen Kecleon at (30, 20) shuts
# the corridor to the cage lever. Its first use sets variable 332 to 1, standing twelve unseen walls and seven passable
# ones by the lever; a second with the Silvon Scope starts the battles, and 332 at 10 clears the way.
module PokeAccess
  module RebornUnderrootKecleon
    MAP = 153
    RESTORED = 479
    QUEST = 332
    BLOCKER = 6
    WALLS = (115..126).to_a
    BY_LEVER = [17, 18, 21, 24, 25, 26, 27]
    TREECKO = 7

    # True while Treecko waits in its cage, the city restored.
    def self.waiting?
      $game_switches[RESTORED] && !$game_self_switches[[MAP, TREECKO, "A"]]
    end

    # True while the Kecleon of the corridor still stands.
    def self.blocked?
      $game_switches[RESTORED] && $game_variables[QUEST].to_i < 10
    end

    # True while an unseen Kecleon of the cave shuts its tile: after the first use of the corridor's, before its battle.
    def self.wall?(ev)
      $game_variables[QUEST].to_i.between?(1, 9) && !$game_self_switches[[MAP, ev.id, "A"]]
    end

    # True while a Kecleon by the lever can still be fought.
    def self.fightable?(ev)
      $game_variables[QUEST].to_i >= 1 && !$game_self_switches[[MAP, ev.id, "A"]]
    end
  end
end

PokeAccess::Game.define("reborn") do
  kec = PokeAccess::RebornUnderrootKecleon
  mechanic(:state, kec::MAP, :part => :kecleon) do
    auto
    name kec::BLOCKER, lambda { |_ev| PokeAccess::Puzzles.assist? ? :rbj_ur_unseen_kecleon : :rbj_ur_unseen },
         :when => lambda { |_ev| kec.blocked? }
    name kec::WALLS, :rbj_ur_kecleon_wall, :assist => true, :when => lambda { |ev| kec.wall?(ev) }
    name kec::BY_LEVER, :rbj_ur_kecleon_fight, :assist => true, :when => lambda { |ev| kec.fightable?(ev) }
    name kec::TREECKO, :rbj_ur_treecko, :when => lambda { |_ev| kec.waiting? }
    hint :rbj_ur_kecleon_hint
    active { PokeAccess::Puzzles.assist? && kec.waiting? }
    solved(nil, :quiet => true) { $game_self_switches[[kec::MAP, kec::TREECKO, "A"]] }
  end
end
