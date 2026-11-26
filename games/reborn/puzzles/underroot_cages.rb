# The Underroot (map 153), under Rhodochrine Jungle: three levers drawn as tiles take a cage's bars away: (16, 23)
# toggles switch 97, bars at (18, 22) of the officer caged at (18, 20); (24, 18) sets 1790, bars at (21, 17); (77, 80)
# toggles 1785, bars at (80, 80). Falls through jungle pits to (80, 72), (52, 5) or (16, 73) are said.
module PokeAccess
  module RebornUnderroot
    MAP = 153
    LEVERS = [2, 50, 37]
    BARS = [3, 51, 38]
    LANDINGS = [[80, 72], [52, 5], [16, 73]]
    CAGE_LEVER = 2
    OFFICER = 4

    # True while the caged officer waits to be freed.
    def self.officer_caged?
      $game_variables[78].to_i >= 1 && !$game_self_switches[[MAP, OFFICER, "A"]]
    end

    # The name of a lever; with the assist, the one of the officer's cage says so, and the one at (24, 18) that working
    # it a second time shuts its cage again.
    def self.lever(ev)
      cage = ev.id == CAGE_LEVER && PokeAccess::Puzzles.assist? && officer_caged? && !$game_switches[97]
      cage ? :rbd_ur_lever_officer : :rbd_ur_lever
    end
  end
end

PokeAccess::Game.define("reborn") do
  ur = PokeAccess::RebornUnderroot
  mechanic(:state, ur::MAP, :part => :cages) do
    auto
    name ur::LEVERS, lambda { |ev| ur.lever(ev) }
    name ur::BARS, :rbd_ur_bars
    ur::LANDINGS.each { |at| sent_back :rbd_rj_fell, :maps => [150], :to => at }
    hint :rbd_ur_hint
    active { PokeAccess::Puzzles.assist? && ur.officer_caged? }
    solved(nil, :quiet => true) { $game_self_switches[[ur::MAP, ur::OFFICER, "A"]] }
  end
end
