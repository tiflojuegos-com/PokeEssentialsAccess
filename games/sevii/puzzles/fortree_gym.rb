# The Fortree Gym (map 385): eight turning doors, each a variable (V63 to V70) and a few RotateFortree events whose
# page it picks. Bumping an arm while facing the way its page asks turns the door (the variable) and steps the player
# onto it (Game_Player#check_event_trigger_touch starts these on a bump). Twelve turns lead from the door to Winona; the
# hint follows the doors as they stand, whatever order turned them (every door state the entrance's leads to, simulated
# with the arms' pages against the floor: auditoria/puzzles-2026-11/_pulido/sim/sevii/fortree_table.rb).
module PokeAccess
  module SeviiFortree
    MAP = 385
    VARS = (63..70).to_a
    # The plan for every door state reachable from the entrance's (fortree_plan.rb, generated).
    TABLE = PokeAccess::SeviiFortreePlan::TABLE
    WORDS = { 2 => :sevii_dir_down, 4 => :sevii_dir_left, 6 => :sevii_dir_right, 8 => :sevii_dir_up }
    # Every arm the plan ever asks to push.
    ARMS = TABLE.values.map { |rows| rows.map { |row| row[1] } }.flatten.select { |arm| arm }.uniq.sort

    # The plan's answer for the doors as they stand and the region the player walks in, as [arm, direction] (nil and
    # nil by Winona, false with no way left), or nil for doors the plan never meets.
    def self.next_turn
      rows = TABLE[VARS.map { |v| $game_variables[v].to_i }]
      return nil unless rows
      px = $game_player.x
      py = $game_player.y
      row = rows.length == 1 ? rows[0] : rows.find { |r| r[0].any? { |b| px >= b[0] && px <= b[1] && py >= b[2] && py <= b[3] } }
      row ? [row[1], row[2]] : nil
    end

    def self.hint
      turn = next_turn
      return :sevii_fortree_off_plan if turn.nil? || turn[0] == false
      return :sevii_fortree_leader unless turn[0]
      [:sevii_fortree_hint, { :dir => PokeAccess::I18n.t(WORDS[turn[1]]) }]
    end
  end
end

PokeAccess::Game.define("sevii") do
  fortree = PokeAccess::SeviiFortree

  mechanic(:state, fortree::MAP) do
    auto
    name(/^RotateFortree$/, :sevii_fortree_arm, :when => false)
    arrival_hint :sevii_fortree_rule, :once => true
    fortree::ARMS.each do |arm|
      spot :event => arm, :label => :sevii_fortree_next, :assist => true,
           :when => lambda { (turn = fortree.next_turn) && turn[0] == arm }
    end
    hint lambda { fortree.hint }
  end
end
