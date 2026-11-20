# Perseida's puzzle room of the Mirror Ruins (map 137): two halves that must show what the mirror reflects. North, four
# tasks each add one to V45: unrolling the carpet (EV24), setting the mirror (EV27) in its frame (EV32), pushing the box
# (EV2) onto 4,6, which EV33 checks, and the barrel (EV1) to 23,7 or past it, which EV38 checks; at 4, EV46 opens the door
# EV47. South, four statues turn on each use (EV16, EV15, EV13, EV17), each right once it faces as the mirror image of the
# fixed statue across the room (EV10, EV11, EV12, EV9); V46 counts the right ones and at 4 EV43 opens the door EV48.
module PokeAccess
  module PerseidaMirror
    MAP = 137
    TASKS = 45
    TURNS = 46
    FIXED = [9, 10, 11, 12]
    GOALS = { [22, 32] => 2, [20, 30] => 6, [18, 32] => 8, [20, 34] => 4 }
    CARPET = [24, 69]
    MIRROR = [27, 64]
    FRAME = 32
    BOX = [2, 67, [4, 6, 4, 6]]
    BARREL = [1, 66, [23, 7, 25, 7]]

    # True while the north tasks are not all done and the assist is on.
    def self.tasks_assist?
      PokeAccess::Puzzles.assist? && $game_variables[TASKS].to_i < 4
    end

    # True once the mirror sits in its frame.
    def self.mirror_set?
      $game_self_switches[[MAP, FRAME, "A"]] ? true : false
    end

    # A fixed statue's name with the way it faces.
    def self.fixed_label(ev)
      [:perseida_mirror_fixed, { :dir => PokeAccess::Puzzles.face_name(ev.direction) }]
    end
  end
end

PokeAccess::Game.define("perseida") do
  mirror = PokeAccess::PerseidaMirror
  mechanic(:state, mirror::MAP, :part => :tasks) do
    auto
    name mirror::CARPET[0], :perseida_mirror_carpet
    name mirror::MIRROR[0], :perseida_mirror_mirror
    name mirror::FRAME, :perseida_mirror_frame
    name mirror::BOX[0], :perseida_mirror_box
    name mirror::BARREL[0], :perseida_mirror_barrel
    name mirror::FIXED, lambda { |ev| lambda { mirror.fixed_label(ev) } }
    count :perseida_mirror_tasks, :value => lambda { [$game_variables[mirror::TASKS].to_i, 4].min }, :of => 4,
                                  :assist => true
    phase lambda { mirror.tasks_assist? && !$game_switches[mirror::CARPET[1]] }, :quiet => true,
          :hint => :perseida_mirror_carpet_hint
    phase lambda { mirror.tasks_assist? && !$game_switches[mirror::MIRROR[1]] }, :quiet => true,
          :hint => :perseida_mirror_take_hint
    phase lambda { mirror.tasks_assist? && !mirror.mirror_set? }, :quiet => true, :hint => :perseida_mirror_frame_hint
    [[mirror::BOX, :perseida_mirror_box, :perseida_mirror_box_hint, :perseida_mirror_box_goal],
     [mirror::BARREL, :perseida_mirror_barrel, :perseida_mirror_barrel_hint, :perseida_mirror_barrel_goal]].each do |row|
      piece, label, hint, goal_label = row
      phase lambda { mirror.tasks_assist? && !$game_switches[piece[1]] }, :quiet => true, :hint => hint,
            :track => { :event => piece[0], :label => label, :goal => piece[2], :goal_label => goal_label }
    end
    solved { $game_variables[mirror::TASKS].to_i >= 4 }
  end

  mechanic(:facing, mirror::MAP, :part => :statues) do
    auto
    statues(/\AEstatuaDiosa\z/, :perseida_mirror_statue)
    obstacle({ :events => mirror::FIXED }, :label => :perseida_mirror_statue)
    goals mirror::GOALS
    solved(nil, :quiet => true) { $game_variables[mirror::TURNS].to_i >= 5 }
  end
end
