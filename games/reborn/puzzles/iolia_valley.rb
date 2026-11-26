# Iolia Valley, the way to Luna's Gym: the Crystal Keys CRYSTALPLUG1 to 4, each replacing the last, wake red (a cave),
# green (rocks), blue (a bridge) and purple (a twin cave) crystals; variable 171 at 3 opens the gym's cave. The reader
# names each crystal and, with the assist, the next step. The purple one of maps 338 and 339 is named alone.
module PokeAccess
  module RebornIolia
    VALLEY = [333, 334, 335]
    MAPS = [336, 337, 333, 334, 335, 338, 339, 341, 342, 343, 344, 346, 347, 348, 349]
    RED = { 336 => { 8 => 162 }, 333 => { 2 => 163, 9 => 164, 16 => 165 }, 334 => { 2 => 166, 4 => 167 },
            335 => { 2 => 168, 4 => 169, 5 => 170, 7 => 171 } }
    WALLS = { 336 => { 7 => 162 }, 333 => { 4 => 163, 14 => 164, 17 => 165 }, 334 => { 1 => 166, 3 => 167 },
              335 => { 1 => 168, 3 => 169, 6 => 170, 11 => 171 } }
    WALL_PARTS = { 336 => [2, 3, 4, 5, 6], 333 => [3, 5, 6, 7, 8, 10, 11, 12, 13, 15], 335 => [8, 9, 10, 12, 13] }
    GREEN = { 333 => { 62 => 443, 70 => 444, 75 => 445 }, 334 => { 5 => 446 },
              335 => { 136 => 447, 141 => 448, 145 => 449, 149 => 450 } }
    BUSHES = { 333 => { 443 => [63, 64, 65, 66, 67, 68, 69], 444 => [71, 72, 73, 74], 445 => [76, 77, 78, 79] },
               334 => { 446 => [6, 7, 8] },
               335 => { 447 => [137, 138, 139, 140], 448 => [142, 143, 144], 449 => [146, 147, 148, 159],
                        450 => [150, 162] } }
    BLUE = { 333 => { 18 => 439 }, 335 => { 57 => 440, 101 => 441, 130 => 442 } }
    TWIN = { 338 => 339, 339 => 338, 341 => 346, 346 => 341, 342 => 347, 347 => 342, 343 => 348, 348 => 343,
             344 => 349, 349 => 344 }
    COLORS = [nil, :rbb_iolia_colors1, :rbb_iolia_colors2, :rbb_iolia_colors3, :rbb_iolia_colors4]

    def self.v(id)
      $game_variables[id].to_i
    end

    def self.s(id)
      $game_switches[id] ? true : false
    end

    # The Crystal Key held, 1 to 4, or 0.
    def self.key
      [4, 3, 2, 1].find { |n| ($PokemonBag.pbQuantity("CRYSTALPLUG#{n}".to_sym) rescue 0).to_i > 0 } || 0
    end

    # Each step: the test that it is still to do, its map, the event to use, its hint and the doors of the way there.
    STEPS = [
      [lambda { $game_map.map_id == 336 && v(162) < 2 }, 336, 8, :rbb_iolia_e01, []],
      [lambda { $game_map.map_id == 336 && v(162) < 3 }, 336, 7, :rbb_iolia_e02, []],
      [lambda { v(167) < 2 }, 334, 4, :rbb_iolia_s01, [[336, 7], [337, 2]]],
      [lambda { v(167) < 3 }, 334, 3, :rbb_iolia_s02, []],
      [lambda { v(168) < 2 }, 335, 2, :rbb_iolia_s03, [[334, 3], [342, 4]]],
      [lambda { v(168) < 3 }, 335, 1, :rbb_iolia_s04, []],
      [lambda { key < 2 }, 335, 157, :rbb_iolia_s05, [[335, 1], [344, 4]]],
      [lambda { !s(443) }, 333, 62, :rbb_iolia_s06, [[335, 156], [344, 2], [335, 152], [342, 2]]],
      [lambda { v(166) < 2 }, 334, 2, :rbb_iolia_s07, []],
      [lambda { v(166) < 3 }, 334, 1, :rbb_iolia_s08, []],
      [lambda { key < 3 }, 335, 158, :rbb_iolia_s09, [[334, 1], [342, 5], [347, 2]]],
      [lambda { !s(439) }, 333, 18, :rbb_iolia_s10, [[335, 151], [342, 3], [347, 4]]],
      [lambda { !s(446) }, 334, 5, :rbb_iolia_s11, []],
      [lambda { !s(440) }, 335, 57, :rbb_iolia_s12, []],
      [lambda { !s(447) }, 335, 136, :rbb_iolia_s13, []],
      [lambda { !s(441) }, 335, 101, :rbb_iolia_s14, []],
      [lambda { !s(444) }, 333, 70, :rbb_iolia_s15, []],
      [lambda { v(165) < 2 }, 333, 16, :rbb_iolia_s16, []],
      [lambda { v(165) < 3 }, 333, 17, :rbb_iolia_s17, []],
      [lambda { !s(448) }, 335, 141, :rbb_iolia_s18, [[333, 17], [341, 3], [346, 1]]],
      [lambda { v(169) < 2 }, 335, 4, :rbb_iolia_s19, [[334, 9], [341, 2]]],
      [lambda { v(169) < 3 }, 335, 3, :rbb_iolia_s20, []],
      [lambda { key < 4 }, 343, 3, :rbb_iolia_s21, [[335, 3]]],
      [lambda { !s(442) && !s(453) }, 343, 1, :rbb_iolia_s22, [[335, 3]]],
      [lambda { !s(442) }, 335, 130, :rbb_iolia_s23, [[335, 3], [348, 3]]],
      [lambda { v(170) < 2 }, 335, 5, :rbb_iolia_s24, []],
      [lambda { v(170) < 3 }, 335, 6, :rbb_iolia_s25, []],
      [lambda { !s(454) && v(171) < 3 }, 344, 1, :rbb_iolia_s26, [[335, 6]]],
      [lambda { s(452) && v(171) < 3 }, 347, 1, :rbb_iolia_s27, [[334, 1], [335, 151]]],
      [lambda { v(171) < 2 }, 335, 7, :rbb_iolia_s28,
       [[349, 3], [335, 154], [348, 2], [334, 3], [342, 4], [335, 1], [349, 4]]],
      [lambda { v(171) < 3 }, 335, 11, :rbb_iolia_s29, []]
    ]

    # The first step still to do, or nil once the gym's cave is open.
    def self.step
      v(171) >= 3 ? nil : STEPS.find { |st| st[0].call }
    end

    def self.hint
      st = step
      st ? st[3] : nil
    end

    # True while the event is the next step's target or a door on its way.
    def self.next?(map, id)
      st = step
      !st.nil? && ((st[1] == map && st[2] == id) || st[4].include?([map, id]))
    end

    def self.spot_label(map, id)
      st = step
      st && st[1] == map && st[2] == id ? :rbb_iolia_next_target : :rbb_iolia_way_on
    end

    def self.step_events(map)
      ids = []
      STEPS.each do |st|
        ids << st[2] if st[1] == map
        st[4].each { |m, id| ids << id if m == map }
      end
      ids.uniq
    end

    def self.crystal_ids(map)
      ids = (RED[map] || {}).keys + (GREEN[map] || {}).keys + (BLUE[map] || {}).keys
      TWIN[map] ? ids + [1] : ids
    end

    # A crystal's colour, and whether it has been woken.
    def self.crystal_label(map, id)
      var = (RED[map] || {})[id]
      return(v(var) >= 2 ? :rbb_iolia_red_spent : :rbb_iolia_red) if var
      sw = (GREEN[map] || {})[id]
      return(s(sw) ? :rbb_iolia_green_spent : :rbb_iolia_green) if sw
      sw = (BLUE[map] || {})[id]
      return(s(sw) ? :rbb_iolia_blue_spent : :rbb_iolia_blue) if sw
      TWIN[map] && id == 1 ? purple_label : nil
    end

    # A purple crystal's name; with the assist, what it does with the last Crystal Key.
    def self.purple_label
      PokeAccess::Puzzles.assist? ? :rb1_iolia_purple_hint : :rbb_iolia_purple
    end

    # A red crystal's wall: grey, then red and cracked; nil once it is a cave, which the core says as an exit.
    def self.wall_label(map, id)
      n = v((WALLS[map] || {})[id].to_i)
      return nil if n >= 3
      n >= 2 ? :rbb_iolia_wall_cracked : :rbb_iolia_wall_grey
    end

    def self.bush_label(map, id)
      (BUSHES[map] || {}).each { |sw, ids| return(s(sw) ? :rbb_iolia_green_rock : :rbb_iolia_bush) if ids.include?(id) }
      nil
    end

    # What each crystal's change shows, said as it happens.
    def self.watches(map)
      list = (RED[map] || {}).values.map do |var|
        { :var => var, :say => lambda { v(var) >= 3 ? :rbb_iolia_cave_opened : :rbb_iolia_red_woke } }
      end
      (GREEN[map] || {}).values.each { |sw| list << { :switch => sw, :say => :rbb_iolia_green_woke } }
      (BLUE[map] || {}).values.each { |sw| list << { :switch => sw, :say => :rbb_iolia_blue_woke } }
      list
    end

    # The valley's rule: the crystals the key held wakes.
    def self.rule(map)
      return nil unless VALLEY.include?(map) || map == 336
      k = key
      k > 0 ? [:rbb_iolia_rule, { :colors => PokeAccess::I18n.t(COLORS[k]) }] : nil
    end
  end
end

PokeAccess::Game.define("reborn") do
  iolia = PokeAccess::RebornIolia
  iolia::MAPS.each do |map|
    mechanic(:state, map, :part => :crystals) do
      iolia.watches(map).each { |w| watch w }
      ids = iolia.crystal_ids(map)
      name ids, lambda { |ev| iolia.crystal_label(map, ev.id) } unless ids.empty?
      name iolia::WALLS[map].keys, lambda { |ev| iolia.wall_label(map, ev.id) } if iolia::WALLS[map]
      name iolia::BUSHES[map].values.flatten, lambda { |ev| iolia.bush_label(map, ev.id) } if iolia::BUSHES[map]
      hide iolia::WALL_PARTS[map] if iolia::WALL_PARTS[map]
      iolia.step_events(map).each do |id|
        spot :event => id, :assist => true, :label => lambda { iolia.spot_label(map, id) },
             :when => lambda { iolia.next?(map, id) }
      end
      sent_back :rbb_iolia_cave_shift, :maps => [iolia::TWIN[map]] if iolia::TWIN[map]
      arrival_hint lambda { iolia.rule(map) }, :once => true
      hint lambda { iolia.hint }
      solved(:rbb_iolia_solved) { $game_variables[171] >= 3 }
    end
  end
end
