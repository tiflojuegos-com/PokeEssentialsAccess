# Santuario de Ordelen, the fifth gym (maps 118 to 120), until its badge: the mechanisms worked, the levers and doors by name and, with
# the assist, what each mechanism opens and the two tiles that get round the ghosts before Elus.
module PokeAccess
  module ArmoniaCatacombs
    VARIABLE = 34
    BADGE = 8
    TOTAL = 6
    HINTS = [:arm_ordelen_hint_0, :arm_ordelen_hint_1, :arm_ordelen_hint_2, :arm_ordelen_hint_3, :arm_ordelen_hint_4,
             :arm_ordelen_hint_5, :arm_ordelen_hint_6]
    # Every mechanism that leaves a self switch behind, as [map, event]: all but the fight with the Lampent.
    MARKED = [[118, 17], [119, 3], [119, 4], [119, 13], [120, 8]]

    # How many mechanisms are worked.
    def self.count
      $game_variables[VARIABLE].to_i
    end

    # The step the count stands at, nil once Elus is beaten.
    def self.step
      $game_switches[BADGE] ? nil : [count, TOTAL].min
    end

    # The count as said: with its total, which the game never gives, only with the assist.
    def self.title(n)
      return [:arm_ordelen_count, { :n => n, :of => TOTAL }] if PokeAccess::Puzzles.assist?
      [:arm_ordelen_count_plain, { :n => n }]
    end

    # Whether the count reached two with the fight still to come, which takes the Lampent away for good: every mechanism counted left a mark.
    def self.fight_lost?
      count >= 2 && MARKED.select { |map, ev| $game_self_switches[[map, ev, "A"]] }.length == count
    end

    # What the assist says at a step: what the next mechanism does, or that the count will stop short.
    def self.hint(n)
      fight_lost? ? :arm_ordelen_hint_lost : HINTS[n]
    end

    # Whether a lever of the current map is still to pull, until the badge: its self switch.
    def self.unpulled?(ev)
      !$game_switches[BADGE] && !$game_self_switches[[$game_map.map_id, ev.id, "A"]]
    end

    # The Misdreavus's name: with the assist, what sends it off.
    def self.blocker(ev)
      PokeAccess::Puzzles.assist? ? :arm_ordelen_blocker_item : :arm_ordelen_blocker
    end

    # Whether the three ghosts stand in the way to Elus: from the scene that raises them until they vanish or the badge.
    def self.ghosts_up?
      $game_self_switches[[118, 37, "A"]] && !$game_self_switches[[118, 37, "B"]] && !$game_switches[BADGE]
    end
  end
end

PokeAccess::Game.define("armonia") do
  catacombs = PokeAccess::ArmoniaCatacombs
  lever = lambda { |ev| catacombs.unpulled?(ev) }
  ghosts_up = lambda { catacombs.ghosts_up? }

  mechanic(:state, [118, 119, 120], :part => :count) do
    auto
    (0..catacombs::TOTAL).each do |n|
      phase lambda { catacombs.step == n }, :title => lambda { catacombs.title(n) }, :hint => lambda { catacombs.hint(n) },
            :entry_title => n > 0
    end
  end

  mechanic(:state, 118, :part => :levers) do
    auto
    name 17, :arm_ordelen_lever, :when => lever
    name 34, :arm_ordelen_elus, :when => false
    name 36..38, :arm_ordelen_ghost
    spot :at => [20, 46], :label => :arm_ordelen_gap, :assist => true, :when => ghosts_up, :onto => true
    spot :at => [28, 46], :label => :arm_ordelen_gap, :assist => true, :when => ghosts_up, :onto => true
    phase ghosts_up, :title => :arm_ordelen_ghosts, :quiet => true, :hint => :arm_ordelen_bypass
  end

  mechanic(:state, 119, :part => :levers) do
    auto
    obstacle(/PuertasCripta/, :label => :arm_ordelen_door)
    watch :var => catacombs::VARIABLE, :quiet => true
    controls
    name [3, 4, 13], :arm_ordelen_lever, :when => lever
    name 1, lambda { |ev| catacombs.blocker(ev) }
  end

  mechanic(:state, 120, :part => :levers) do
    auto
    obstacle(/PuertasCripta/, :label => :arm_ordelen_door)
    watch :var => catacombs::VARIABLE, :quiet => true
    controls
    name 5, :arm_ordelen_lampent
    name 8, :arm_ordelen_lampent2
  end
end
