# Power Plant (maps 484 to 487): a field of "Stepped on" tiles a floor. A tile's first step marks it (self switch A) and adds to
# the floor's variable (V405 to V408); a marked one sends the player back near the stairs and puts the count to 0, but keeps
# the other tiles marked, since a transfer within the map does not reload it: only entering the floor again, whose Reset
# Switch runs then, clears them. At the floor's total the field holds and its Ladder Out shows. Each floor's order steps on
# every tile once from the first, the one tile with plain floor beside it (checked with _pulido/sim/soulstones2/power_plant.rb),
# so once the player has left the field after the first step the rest can only be reached over marked tiles.
module PokeAccess
  module SS2PowerPlant
    FLOORS = {
      484 => [405, 14, [1, 2, 3, 4, 9, 8, 5, 6, 7, 11, 12, 13, 10]],
      485 => [406, 53, [1, 4, 5, 6, 18, 17, 16, 7, 8, 9, 10, 11, 12, 48, 49, 50, 47, 13, 14, 46, 51, 52, 43, 44, 45, 15, 19, 40,
                        41, 42, 37, 36, 35, 38, 39, 20, 21, 34, 33, 22, 23, 24, 3, 2, 25, 26, 27, 28, 29, 30, 31, 32]],
      486 => [407, 41, (1..40).to_a],
      487 => [408, 55, [1, 2, 7, 8, 9, 10, 11, 14, 15, 18, 19, 20, 21, 22, 17, 16, 13, 12, 5, 6, 3, 4, 31, 30, 25, 24, 23, 26,
                        27, 54, 53, 52, 51, 50, 49, 48, 47, 28, 29, 46, 45, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 44, 43, 42]]
    }
    # The tile a field tile wears, as the free camera names it: fresh, or stepped on (marked, or all once the floor holds).
    TILE_KEYS = { 4155 => :ss2_pz_pp_fresh, 4136 => :ss2_pz_pp_marked }

    # A floor's tiles in the order the hint follows.
    def self.order(map); FLOORS[map][2]; end

    # True once a tile has been stepped on.
    def self.marked?(map, id)
      $game_self_switches[[map, id, "A"]] ? true : false
    end

    # How many of the floor's tiles are marked.
    def self.marked_count(map)
      order(map).count { |id| marked?(map, id) }
    end

    # True once the floor holds.
    def self.solved?(map)
      $game_variables[FLOORS[map][0]] >= order(map).length
    end

    # Where an event stands, as an offset phrase from the player ("" on it).
    def self.offset_to(id)
      ev = $game_map.events[id]
      ev ? PokeAccess::Puzzles.offset_phrase(ev.x - $game_player.x, ev.y - $game_player.y) : ""
    end

    # True when the player stands on the event's tile.
    def self.on?(id)
      ev = $game_map.events[id]
      ev ? ev.x == $game_player.x && ev.y == $game_player.y : false
    end

    # The next step of the plan, or what to do when it cannot go on: a key and its interpolations. The floor must start
    # over when the marked tiles are not the plan's first ones, when their number is not the game's count (a repeated tile
    # put it to 0 and left the rest marked), or when the player has stepped off the last one, since every way back in crosses
    # a marked tile.
    def self.next_step(map)
      list = order(map)
      return [:ss2_pz_pp_h_done, { :dist => offset_to(FLOORS[map][1]) }] if solved?(map)
      done = list.take_while { |id| marked?(map, id) }.length
      count = marked_count(map)
      return [:ss2_pz_pp_h_reset, {}] if count != done || count != $game_variables[FLOORS[map][0]]
      return [:ss2_pz_pp_h_start, { :dist => offset_to(list[0]) }] if done == 0
      return [:ss2_pz_pp_h_reset, {}] unless on?(list[done - 1])
      [:ss2_pz_pp_h_next, { :dist => offset_to(list[done]), :n => list.length - done }]
    end

    # The hint, as the info key and each step say it.
    def self.hint(map)
      key, vars = next_step(map)
      PokeAccess::I18n.t(key, vars)
    end

    # What the free camera says of a tile of the floor's field: stepped on or not, as its tile shows; nil off the field.
    def self.tile_line(map, x, y)
      ev = order(map).map { |id| $game_map.events[id] }.find { |e| e && e.x == x && e.y == y }
      key = ev ? TILE_KEYS[ev.tile_id.to_i] : nil
      key ? PokeAccess::I18n.t(key) : nil
    end

    # The sides of the player with a marked tile, as words.
    def self.marked_around(map)
      x = $game_player.x
      y = $game_player.y
      sides = [[0, -1, :dir_up], [0, 1, :dir_down], [-1, 0, :dir_left], [1, 0, :dir_right]].select do |dx, dy, _key|
        order(map).any? { |id| (ev = $game_map.events[id]) && ev.x == x + dx && ev.y == y + dy && marked?(map, id) }
      end
      sides.map { |_dx, _dy, key| PokeAccess::I18n.t(key) }
    end

    # The info key's line: the tiles stepped on and the marked ones beside the player.
    def self.info(map)
      t = PokeAccess::I18n
      count = t.t(:ss2_pz_pp_count, :n => marked_count(map), :total => order(map).length)
      near = marked_around(map)
      near.empty? ? count : PokeAccess.sentences([count, t.t(:ss2_pz_pp_near, :dirs => near.join(", "))])
    end
  end
end

PokeAccess::Game.define("soulstones2") do
  camera_tile(:maps => PokeAccess::SS2PowerPlant::FLOORS.keys) do |x, y|
    PokeAccess::SS2PowerPlant.tile_line($game_map.map_id, x, y)
  end
  PokeAccess::SS2PowerPlant::FLOORS.each do |map, floor|
    mechanic(:state, map) do
      auto
      not_control floor[2]
      avoid floor[2], :assist => true
      name floor[1], :ss2_pz_pp_ladder, :when => lambda { |_ev| PokeAccess::SS2PowerPlant.solved?(map) }
      arrival_hint :ss2_pz_pp_rule, :once => true
      watch :var => floor[0], :say => lambda { PokeAccess::Puzzles.assist? ? PokeAccess::SS2PowerPlant.hint(map) : nil }
      info { PokeAccess::SS2PowerPlant.info(map) }
      solved { PokeAccess::SS2PowerPlant.solved?(map) }
      hint lambda { PokeAccess::SS2PowerPlant.hint(map) }
    end
  end
end
