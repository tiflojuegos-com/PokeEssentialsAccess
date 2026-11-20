# Keneph: the caves' levers and jammed doors (map 87), the clues about Kuiki in the village (map 91) that Connor waits for at
# the caves' entrance, and the panel of the waterfall cave (map 86) that gives way to insisting.
#
# Map 87: lever 45 opens door 44 (switch 112; since 6.0.13 only facing it from the south or a side), lever 47 opens door 46
# (113), lever 85 opens door 96 (165). Lever 45 says, used from the north, that it does not move; the core says what each pull opens, and the walks plan the pulls. Event 71, on the
# tile below lever 45, sends the player back while variable 32 is under 5.
# Map 91: six sources add one each to variable 32, once: the woman (1), the three shining diaries (3, 8, 9), the diary
# on the house's table (14, its Yes) and the villager in a trance (39).
# Map 442: Connor blocks the way out (event 5) until variable 239 reaches 16, which pressing the switch under the healing
# machine (event 3) does.
# Map 86: the panel (3) speaks once, then each touch adds one to variable 33 and says "..."; at 11 the next touch moves it
# aside (switch 133). Shiv's book (map 94, event 2) adds one as well.
module PokeAccess
  module DesolationKeneph
    # True once Connor lets the player through.
    def self.clues_done?
      $game_variables[32].to_i >= 5
    end
  end
end

PokeAccess::Game.define("desolation") do
  keneph = PokeAccess::DesolationKeneph
  mechanic(:state, 87, :part => :levers) do
    auto
    [112, 113, 165].each { |s| watch :switch => s, :quiet => true }
    controls
    name [45, 47, 85], :deso_keneph_lever
    name [44, 46, 96], :deso_keneph_jammed_door
    name 72, :deso_keneph_locked_gate
    on_use 45, lambda { |_ev| $game_player.direction == 2 ? :deso_keneph_lever_stuck : nil }
  end
  mechanic(:state, [87, 91], :part => :clues) do
    auto
    name 14, :deso_keneph_diary
    count :deso_keneph_clues, :var => 32, :of => 5, :assist => true
    hint :deso_keneph_clues_hint
    solved { keneph.clues_done? }
  end
  mechanic(:state, 442) do
    auto
    right_choice 3, :takes => { :var => 239 }
  end
  mechanic(:state, 86) do
    auto
    name 3, :deso_keneph_panel, :when => lambda { |_ev| !$game_switches[133] }
    count :deso_keneph_panel_count, :var => 33, :of => 11, :assist => true
    hint :deso_keneph_panel_hint
    solved { $game_switches[133] }
  end
end
