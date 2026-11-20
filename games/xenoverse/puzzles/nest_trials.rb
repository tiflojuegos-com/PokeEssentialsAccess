# More Pokemon Nests, optional zones played with the starter. Bosco Stellafilante (maps 502 to 505): guardians close the
# way, unseen tiles in front of them send the player out of the nest, and a bait (honey, raspberry or sap, one carried at a
# time) smeared on the right tree moves them aside; the baits and trees are named, the bait carried is told by the info
# key, and with the assist each tree says its bait. Map 505's six tree events all set switch 655, a slip of the game, and its
# end is reached with no bait. Percorso 5 (map 495): ten Abra alike, half teleporting the player on and half sending them
# out, told apart with the assist. Percorso 12 (maps 496 to 499): pads that move the player, some before the Druddigon,
# told apart with the assist. Via Vittoria (maps 509 to 519): doors of rock that show up after Golem's scene, named by side,
# the ones before the Tyranitar told apart with the assist. Cunicolo Gravita (map 507): boulders moved one step by a menu,
# which, with the assist, say the way to pick to reach the chest. Sabolt's nests (maps 249 and 255): the power box with no
# sprite (event 2) that brings the current back (switches 497 and 338), and with it the robots that bar doors outside.
module PokeAccess
  module XenoNestTrials
    BAITS = { 502 => { 4 => :honey }, 503 => { 1 => :honey, 2 => :sap, 3 => :raspberry },
              504 => { 18 => :honey, 19 => :raspberry, 20 => :sap }, 505 => { 13 => :honey } }
    TREES = { 502 => [[[11, 15], :honey, 639]],
              503 => [[[7, 8], :honey, 643], [[15, 18, 24, 26], :sap, 644], [[34, 35], :raspberry, 645]],
              504 => [[[21, 22], :honey, 651], [[23, 24], :raspberry, 649], [[25, 26], :sap, 650]],
              505 => [[[17, 18, 19, 23, 24, 25], :honey, 655]] }
    WATCHED = { 502 => [5, 9, 10], 503 => [9, 10, 25, 27, 28, 29, 32, 33], 504 => (27..37).to_a,
                505 => [29, 30, 31, 32, 33, 34, 39] }
    CARRIED = [[[638, 640, 647, 652], :honey], [[641, 646], :raspberry], [[642, 648], :sap]]
    BAIT_KEYS = { :honey => :xv_bait_honey, :raspberry => :xv_bait_raspberry, :sap => :xv_bait_sap }
    TREE_KEYS = { :honey => :xv_bait_tree_honey, :raspberry => :xv_bait_tree_raspberry, :sap => :xv_bait_tree_sap }

    ABRA_MAP = 495
    ABRAS = [1, 4, 6, 7, 11, 14, 17, 18, 19, 20]
    ABRA_ON = [1, 4, 6, 7, 19]

    PAD = /\Apedanenido\z/
    PADS_ON = { 496 => [3, 4, 5], 497 => [2, 5, 6], 499 => [3] }
    PADS_BACK = { 499 => [12] }

    DOORS = { 509 => [2, 3, 4], 510 => [2, 3, 4], 511 => [2, 4, 3], 512 => [2, 3, 4], 513 => [2, 3, 4],
              515 => [2, 3, 4, 6, 7], 517 => [2, 4, 3], 518 => [2, 3, 6, 4, 5] }
    DOORS_OUT = { 510 => [3, 4], 511 => [4], 512 => [4], 513 => [2, 4], 517 => [2, 4], 518 => [2, 3, 4, 5] }
    SIDES = [:xv_root_door_left, :xv_root_door_middle, :xv_root_door_right]

    POWER = { 249 => 497, 255 => 338 }
    POWER_SWITCH = 2

    GRAVITY = 507
    ROCKS = 1..18
    ROCK_STEPS = { 1 => { [24, 24] => 6 }, 2 => { [24, 23] => 8, [24, 22] => 8, [24, 21] => 8, [24, 20] => 8, [24, 19] => 6 },
                   4 => { [11, 17] => 2 }, 18 => { [13, 9] => 2 }, 12 => { [16, 8] => 8 } }
    DIRS = { 2 => :dir_down, 4 => :dir_left, 6 => :dir_right, 8 => :dir_up }

    # The map the player is on.
    def self.map
      $game_map.map_id rescue 0
    end

    # The tree entry [events, bait, switch] an event belongs to on this map, or nil.
    def self.tree_of(ev)
      (TREES[map] || []).find { |ids, _bait, _sw| ids.include?(ev.id) }
    end

    # A bait tree's name; with the assist, the bait it takes.
    def self.tree_label(ev)
      tree = tree_of(ev)
      return :xv_bait_tree unless tree && PokeAccess::Puzzles.assist?
      TREE_KEYS[tree[1]]
    end

    # True while a bait tree still waits for its bait.
    def self.tree_waits?(ev)
      tree = tree_of(ev)
      tree ? !$game_switches[tree[2]] : false
    end

    # The info key's line: the bait the player carries, or nil.
    def self.carried_line
      hit = CARRIED.find { |sws, _bait| sws.any? { |s| $game_switches[s] } }
      hit ? [:xv_bait_carried, { :bait => PokeAccess::I18n.t(BAIT_KEYS[hit[1]]) }] : nil
    end

    # An Abra's name with the assist: whether it teleports the player on or sends them out.
    def self.abra_label(ev)
      key = ABRA_ON.include?(ev.id) ? :xv_nest_abra_on : :xv_nest_abra_out
      [key, { :pokemon => PokeAccess::Data.species_name(:ABRA) }]
    end

    # A pad's name; with the assist, whether it leads on toward the end, or back to the nest's entrance once done.
    def self.pad_label(ev)
      return :xv_nest_pad unless PokeAccess::Puzzles.assist?
      return :xv_nest_pad_back if (PADS_BACK[map] || []).include?(ev.id)
      (PADS_ON[map] || []).include?(ev.id) ? :xv_nest_pad_on : :xv_nest_pad_out
    end

    # A door's name by its place from the left; with the assist, whether it leads on or before the Tyranitar.
    def self.door_label(ev)
      doors = DOORS[map] || []
      i = doors.index(ev.id)
      return nil unless i
      side = doors.size == 3 ? PokeAccess::I18n.t(SIDES[i]) : PokeAccess::I18n.t(:xv_nest_door_nth, :n => i + 1)
      return side unless PokeAccess::Puzzles.assist?
      return [:xv_nest_door_on, { :door => side }] unless (DOORS_OUT[map] || []).include?(ev.id)
      [:xv_nest_door_out, { :door => side, :pokemon => PokeAccess::Data.species_name(:TYRANITAR) }]
    end

    # A boulder's name; with the assist, the way to pick for it where the plan to the chest moves it from here.
    def self.rock_label(ev)
      dir = PokeAccess::Puzzles.assist? ? (ROCK_STEPS[ev.id] || {})[[ev.x, ev.y]] : nil
      dir ? [:xv_gravity_rock_pick, { :dir => PokeAccess::I18n.t(DIRS[dir]) }] : :xv_gravity_rock
    end
  end
end

PokeAccess::Game.define("xenoverse") do
  trials = PokeAccess::XenoNestTrials
  trials::TREES.each_key do |map|
    mechanic(:state, map) do
      auto
      trials::BAITS[map].each { |id, bait| name id, trials::BAIT_KEYS[bait] }
      trees = trials::TREES[map].map { |ids, _bait, _sw| ids }.flatten
      name trees, lambda { |ev| trials.tree_label(ev) }, :grouped => true, :when => lambda { |ev| trials.tree_waits?(ev) }
      hide trials::WATCHED[map], :when => lambda { |_ev| !PokeAccess::Puzzles.assist? }
      name trials::WATCHED[map], :xv_nest_watched, :assist => true
      info { trials.carried_line }
      active { !trials.carried_line.nil? }
    end
  end

  mechanic(:state, trials::ABRA_MAP) do
    auto
    name trials::ABRAS, lambda { |ev| trials.abra_label(ev) }, :assist => true
  end

  trials::PADS_ON.each_key do |map|
    mechanic(:state, map, :part => :pads) do
      auto
      name trials::PAD, lambda { |ev| trials.pad_label(ev) }
    end
  end

  trials::DOORS.each_key do |map|
    mechanic(:state, map) do
      auto
      name trials::DOORS[map], lambda { |ev| trials.door_label(ev) }
    end
  end

  trials::POWER.each do |map, power|
    mechanic(:state, map) do
      auto
      name trials::POWER_SWITCH, :xv_power_switch, :when => lambda { |_ev| !$game_switches[power] }
    end
  end

  mechanic(:state, trials::GRAVITY) do
    auto
    name trials::ROCKS, lambda { |ev| trials.rock_label(ev) }
  end
end
