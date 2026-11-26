# Ashen Frost's cell in the Flores Mansion's basement (map 646), as Mordecai: the Poke Ball (EV8) does nothing; its use
# is the event beside it (EV9, no graphic), which frees Rotom (EV12). Rotom's drill fixes the toy car (EV15, self switch
# B), which brings the card that opens the cell (variable 221 at 2). The landing scene is EV7 (self switch A).
module PokeAccess
  module AshenRotomCell
    MAP = 646
    BALL = 8
    BALL_SPOT = 9
    ROTOM = 12
    LANDING = 7
    STEP = 221

    # A self switch of an event of the cell's map.
    def self.self_on?(ev, letter)
      $game_self_switches[[MAP, ev, letter]] ? true : false
    end

    # Whether the player is shut in the cell: landed, the card not brought yet.
    def self.locked_in?
      self_on?(LANDING, "A") && $game_variables[STEP].to_i < 2
    end

    # The step the cell is at, for the assist: :ball, :drill, :car, or nil.
    def self.step
      return nil unless locked_in?
      return :car if self_on?(ROTOM, "B") || $game_variables[STEP].to_i >= 1
      self_on?(BALL_SPOT, "A") ? :drill : :ball
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  cell = PokeAccess::AshenRotomCell
  mechanic(:state, cell::MAP, :part => :afe_rotom) do
    auto
    active { PokeAccess::Puzzles.assist? && cell.locked_in? }
    solved(nil, :quiet => true) { $game_variables[cell::STEP].to_i >= 2 }
    name cell::BALL_SPOT, :afe_rotom_ball, :when => lambda { |_ev| !cell.self_on?(cell::BALL_SPOT, "A") }
    hide cell::BALL, :when => lambda { |_ev| !cell.self_on?(cell::BALL_SPOT, "A") }
    right_choice cell::ROTOM, :takes => { :self => "B" }
    phase lambda { cell.step == :ball }, :hint => :afe_rotom_hint_ball
    phase lambda { cell.step == :drill }, :hint => :afe_rotom_hint_drill
    phase lambda { cell.step == :car }, :hint => :afe_rotom_hint_car
  end
end
