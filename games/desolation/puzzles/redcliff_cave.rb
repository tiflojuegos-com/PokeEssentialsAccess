# The cave of the five slabs near Redcliff (map 101): five slabs with no sprite, the middle one (event 3) and one at each
# corner (4 northeast, 5 southwest, 6 southeast, 7 northwest). Each shows a parchment whose picture names the slab that
# comes next, and counts in variable 35 only in order: middle, northeast, southwest, southeast, northwest, then those four
# again; any other puts it back to 0 with no sound, the middle back to 1. At 9 the middle one opens the two ways on (switch
# 151). Without the assist, what each parchment shows; with it, the slab to touch next.
module PokeAccess
  module DesolationRedcliffCave
    MAP = 101
    SLABS = { 3 => :deso_cave_slab_middle, 4 => :deso_cave_slab_north_east, 5 => :deso_cave_slab_south_west,
              6 => :deso_cave_slab_south_east, 7 => :deso_cave_slab_north_west }
    # The slab to touch at each value of variable 35.
    ORDER = [3, 4, 5, 6, 7, 4, 5, 6, 7, 3]
    # The direction each slab's parchment names.
    POINTS = { 3 => :deso_cave_dir_north_east, 4 => :deso_cave_dir_south_west, 5 => :deso_cave_dir_south_east,
               6 => :deso_cave_dir_north_west, 7 => :deso_cave_dir_north_east }

    # What the parchment of a slab shows as it is touched; nil for the middle one opening the ways, which shows none.
    def self.parchment(ev)
      return nil if ev.id == 3 && $game_variables[35].to_i >= 9 && !$game_switches[151]
      done = $game_switches[151] && ev.id == 3
      last = ev.id == 7 && $game_variables[35].to_i == 8
      dir = done || last ? :deso_cave_dir_origin : POINTS[ev.id]
      [:deso_cave_parchment, { :dir => PokeAccess::I18n.t(dir) }]
    end

    # The slab to touch next, with the assist.
    def self.hint
      id = ORDER[[$game_variables[35].to_i, ORDER.length - 1].min]
      [:deso_cave_next, { :name => PokeAccess::I18n.t(SLABS[id]) }]
    end
  end
end

PokeAccess::Game.define("desolation") do
  cave = PokeAccess::DesolationRedcliffCave
  mechanic(:state, cave::MAP) do
    auto
    cave::SLABS.each { |id, key| name id, key }
    on_use cave::SLABS.keys, lambda { |ev| cave.parchment(ev) }
    arrival_hint :deso_cave_rule, :once => true
    hint lambda { cave.hint }
    solved { $game_switches[151] }
  end
end
