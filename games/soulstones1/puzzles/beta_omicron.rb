# Ruins of Beta Omicron. Map 11: numbered doors open by variable 178, which each key found raises: statue 3 (event 24)
# gives key 321, statue 4 (25) key 322, Ronnie (35) key 325 and statue 6 (26) key 324; the healing bot (59) then opens the
# way out (event 22, variable 180 at 2). Maps 23 and 24: eleven sprite-less diaries raise variable 185, and with all of them
# read (12) the keypad door of map 23 (event 45) takes the pass code from one of their covers. Map 287: five defaced
# gravestones (events 15 to 19, self switch A once read) raise variable 183, and at 5 a Dusknoir haunts map 14 (event 25).
module PokeAccess
  module SoulstonesBetaOmicron
    DOORS = { 12 => 321, 13 => 322, 18 => 325, 17 => 324, 16 => 323 }
    # Variable 178 below each value => the event that raises it next.
    KEYS = [[4, 24], [5, 25], [6, 35], [7, 26], [8, 59]]
    DIARIES = { 23 => (30..35).to_a, 24 => (4..8).to_a }

    # The name of a numbered door: the number the game gives it.
    def self.door_label(ev)
      [:ss1_bo_door, { :n => DOORS[ev.id] }]
    end

    # The event the assist points at in map 11: the next key, the healing bot, then the way out.
    def self.next_key
      v = $game_variables[178].to_i
      step = KEYS.find { |below, _ev| v < below }
      step ? step[1] : 22
    end
  end
end

PokeAccess::Game.define("soulstones1") do
  bo = PokeAccess::SoulstonesBetaOmicron

  mechanic(:state, 11) do
    auto
    name bo::DOORS.keys, lambda { |ev| bo.door_label(ev) }
    name [24, 25, 26, 58], :ss1_bo_statue
    (bo::KEYS.map { |_below, ev| ev } + [22]).each do |id|
      spot(:event => id, :label => :puzzle_right_way, :assist => true, :when => lambda { bo.next_key == id })
    end
    hint :ss1_bo_keys_hint
    active { PokeAccess::Puzzles.assist? && $game_variables[180].to_i < 2 }
    solved(nil, :quiet => true) { $game_variables[180].to_i >= 2 }
  end

  bo::DIARIES.each do |map, ids|
    mechanic(:state, map) do
      auto
      name ids, :ss1_bo_diary
      name 45, :ss1_bo_keypad if map == 23
      count :ss1_bo_diaries, :value => lambda { [$game_variables[185].to_i, 11].min }, :of => 11, :assist => true,
                             :hide_zero => true
      hint :ss1_bo_diaries_hint
      solved(nil, :quiet => true) { $game_variables[185].to_i >= 12 }
    end
  end

  mechanic(:state, 287) do
    auto
    name 15..19, :ss1_phantom_grave, :when => lambda { |ev| !$game_self_switches[[287, ev.id, "A"]] }
    count :ss1_phantom_graves, :value => lambda { [$game_variables[183].to_i, 5].min }, :of => 5, :assist => true,
                               :hide_zero => true
    hint :ss1_phantom_hint
    solved(nil, :quiet => true) { $game_variables[183].to_i >= 5 }
  end
end
