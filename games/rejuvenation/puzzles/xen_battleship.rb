# The Xen Battleship on Route 6 (map 318), variable 731 from 49 to 54. Switch 476 is the deck the player is on, flipped
# by touch sensors: on at row 39 and the ladders' north end, off at row 43, their south end and the first touch. Three
# floor buttons (events 31, 48, 81) raise variable 522 to their number; the gates up (19, 22) reset it.
module PokeAccess
  module RejuvXenBattleship
    MAP = 318
    BUTTONS = { 31 => 1, 48 => 2, 81 => 3 }
    FIRST = 31
    LAST = 91
    # step (variable 731) => [the point it runs to, stood on, the hint while it is due]
    STEPS = { 49 => [75, true, :rjrb_sh_go], 50 => [90, true, :rjrb_sh_go], 51 => [90, true, :rjrb_sh_go],
              52 => [LAST, false, :rjrb_sh_last], 53 => [94, true, :rjrb_sh_fight], 54 => [6, true, :rjrb_sh_exit] }
    # The steps whose point needs the first button pressed: Venam's.
    NEEDS_FIRST = [50, 51]

    # The step of the ship's chapter, variable 731, and the buttons' count, variable 522.
    def self.step; $game_variables[731].to_i; end
    def self.pressed; $game_variables[522].to_i; end

    # While the ship is crossed.
    def self.live?; STEPS.key?(step); end

    # A button's name: whether it is pressed.
    def self.button(ev)
      done = ev.id == LAST ? step >= 53 : pressed >= BUTTONS[ev.id]
      done ? :rjf_xs_button_on : :rjf_xs_button
    end

    # The assist's next move: the first button while the step's point needs it and the gates left it unpressed, then the
    # point; nil off the ship.
    def self.move
      s = STEPS[step]
      return nil unless s
      return [:press, FIRST] if pressed < 1 && NEEDS_FIRST.include?(step)
      [:go, s[0]]
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  ship = PokeAccess::RejuvXenBattleship
  mechanic(:state, ship::MAP, :part => :buttons) do
    auto
    name ship::BUTTONS.keys + [ship::LAST], lambda { |ev| ship.button(ev) }
    phase lambda { PokeAccess::Puzzles.assist? && ship.move == [:press, ship::FIRST] }, :quiet => true,
          :hint => [:rjrb_sh_press, { :n => ship::BUTTONS[ship::FIRST] }],
          :spots => [{ :event => ship::FIRST, :label => :rjf_xs_next, :assist => true }]
    ship::STEPS.values.uniq.each do |point, onto, hint|
      label = point == 6 ? :rjrb_sh_spot_exit : :rjrb_sh_spot_point
      phase lambda { PokeAccess::Puzzles.assist? && ship.move == [:go, point] }, :quiet => true, :hint => hint,
            :spots => [{ :event => point, :label => label, :assist => true, :onto => onto }]
    end
    active { ship.live? }
  end
end
