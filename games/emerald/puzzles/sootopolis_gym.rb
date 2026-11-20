# Sootopolis Gym (map 581): three floors of cracked ice. The first step on a tile cracks it (its self switch A) and adds
# to the floor's variable (141, 142, 143); a second step breaks it and drops the player to the basement (map 582) on the
# same tile. Once every tile of a floor is cracked (7, 19 and 38), stairs up to the next floor appear. Arriving starts
# every floor over. ORDERS holds every order that cracks a whole floor from its
# way in to its stairs, found by a search over the floor; the assist follows the one the player is taking.
module PokeAccess
  module EmSootopolis
    MAP = 581
    BASEMENT = 582
    BEATEN = 11
    FLOORS = [
      [141, 7, [9, 12, 13, 15, 16, 17, 18]],
      [142, 19, [14] + (19..36).to_a],
      [143, 38, (40..77).to_a]
    ]
    ORDERS = [
      [[[8, 19], [7, 19], [7, 18], [8, 18], [9, 18], [9, 17], [8, 17]]],
      [[[8, 14], [7, 14], [6, 14], [5, 14], [5, 13], [5, 12], [6, 12], [7, 12], [7, 13], [8, 13], [9, 13], [9, 14],
        [10, 14], [11, 14], [11, 13], [11, 12], [10, 12], [9, 12], [8, 12]],
       [[8, 14], [9, 14], [10, 14], [11, 14], [11, 13], [11, 12], [10, 12], [9, 12], [9, 13], [8, 13], [7, 13], [7, 14],
        [6, 14], [5, 14], [5, 13], [5, 12], [6, 12], [7, 12], [8, 12]]],
      [[[8, 9], [7, 9], [6, 9], [5, 9], [4, 9], [3, 9], [3, 8], [3, 7], [3, 6], [4, 6], [4, 7], [5, 7], [5, 8], [6, 8],
        [6, 7], [6, 6], [7, 6], [7, 7], [8, 7], [8, 8], [9, 8], [9, 9], [10, 9], [10, 8], [11, 8], [12, 8], [12, 9],
        [13, 9], [13, 8], [13, 7], [13, 6], [12, 6], [11, 6], [11, 7], [10, 7], [10, 6], [9, 6], [8, 6]],
       [[8, 9], [7, 9], [6, 9], [5, 9], [4, 9], [3, 9], [3, 8], [3, 7], [3, 6], [4, 6], [4, 7], [5, 7], [5, 8], [6, 8],
        [6, 7], [6, 6], [7, 6], [7, 7], [8, 7], [8, 8], [9, 8], [9, 9], [10, 9], [10, 8], [10, 7], [11, 7], [11, 8],
        [12, 8], [12, 9], [13, 9], [13, 8], [13, 7], [13, 6], [12, 6], [11, 6], [10, 6], [9, 6], [8, 6]],
       [[8, 9], [7, 9], [6, 9], [6, 8], [5, 8], [5, 9], [4, 9], [3, 9], [3, 8], [3, 7], [3, 6], [4, 6], [4, 7], [5, 7],
        [6, 7], [6, 6], [7, 6], [7, 7], [8, 7], [8, 8], [9, 8], [9, 9], [10, 9], [10, 8], [11, 8], [12, 8], [12, 9],
        [13, 9], [13, 8], [13, 7], [13, 6], [12, 6], [11, 6], [11, 7], [10, 7], [10, 6], [9, 6], [8, 6]],
       [[8, 9], [7, 9], [6, 9], [6, 8], [5, 8], [5, 9], [4, 9], [3, 9], [3, 8], [3, 7], [3, 6], [4, 6], [4, 7], [5, 7],
        [6, 7], [6, 6], [7, 6], [7, 7], [8, 7], [8, 8], [9, 8], [9, 9], [10, 9], [10, 8], [10, 7], [11, 7], [11, 8],
        [12, 8], [12, 9], [13, 9], [13, 8], [13, 7], [13, 6], [12, 6], [11, 6], [10, 6], [9, 6], [8, 6]]]
    ]

    # Whether floor i's stairs stand: its variable at its total.
    def self.floor_done?(i)
      var, total, _ = FLOORS[i]
      $game_variables[var].to_i >= total
    end

    # The tiles of floor i cracked now, as [x, y].
    def self.cracked(i)
      FLOORS[i][2].map do |id|
        ev = $game_map.events[id]
        ev && $game_self_switches[[MAP, id, "A"]] ? [ev.x, ev.y] : nil
      end.compact
    end

    # The tile of floor i to step on next along an order the cracked tiles begin, or nil when none fits.
    def self.next_tile(i)
      done = cracked(i).sort
      ORDERS[i].each do |order|
        return order[done.size] if order[0, done.size].sort == done
      end
      nil
    end

    # The assist's line for floor i: where its next tile lies, or how to start the floor over.
    def self.hint(i)
      tile = next_tile(i)
      return :em_soot_restart_hint unless tile
      [:em_soot_next_hint, { :place => PokeAccess::EmPuzzles.place(tile[0], tile[1]) }]
    end
  end
end

PokeAccess::Game.define("emerald") do
  gym = PokeAccess::EmSootopolis
  gym::FLOORS.each_with_index do |(var, total, ids), i|
    mechanic(:grid, gym::MAP, :part => "floor#{i + 1}".to_sym) do
      auto
      tiles ids, :self => "A", :label => :em_soot_ice, :count => :em_soot_ice_count,
                 :words => { true => :em_soot_cracked, false => :em_soot_whole }
      solved { $game_variables[var].to_i >= total || $game_switches[gym::BEATEN] }
    end
  end

  mechanic(:state, gym::MAP, :part => :order) do
    auto
    3.times do |i|
      phase lambda { PokeAccess::Puzzles.assist? && !gym.floor_done?(i) }, :quiet => true, :hint => lambda { gym.hint(i) }
    end
    arrival_hint :em_soot_rule, :once => true
    solved { $game_switches[gym::BEATEN] }
  end

  mechanic(:state, gym::BASEMENT) do
    auto
    sent_back :em_soot_fell, :maps => [gym::MAP], :from => [3, 13, 5, 19], :to => [3, 13, 5, 19]
  end
end
