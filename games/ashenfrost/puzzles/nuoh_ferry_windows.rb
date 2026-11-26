# Ashen Frost's port windows on the Nuoh Ferry's deck (map 641, Case Fifteen): Kalvin's (EV6 at 5,15) sparkles and, once
# switch 256 asks for the windows, gives the window clue (self switch A); Hart's (EV5 at 8,15) has no graphic. Switch
# 266 ends the case.
module PokeAccess
  module AshenFerryWindows
    MAP = 641
    KALVIN = 6
    HART = 5
    ASKED = 256
    CLOSED = 266

    # Whether the clue window has given its clue, or the case is over.
    def self.done?
      $game_self_switches[[MAP, KALVIN, "A"]] || $game_switches[CLOSED] ? true : false
    end

    # Whether the case asks for the windows and the clue is still there.
    def self.asked?
      $game_switches[ASKED] && !done? ? true : false
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  windows = PokeAccess::AshenFerryWindows
  mechanic(:state, windows::MAP, :part => :afe_windows) do
    auto
    active { PokeAccess::Puzzles.assist? && windows.asked? }
    asked = lambda { |_ev| windows.asked? }
    name windows::KALVIN, :afe_window_sparkle, :when => asked
    name windows::HART, :afe_window, :when => asked
    phase lambda { windows.asked? }, :hint => :afe_window_hint
  end
end
