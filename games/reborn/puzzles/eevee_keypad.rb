# The keypad console of Labradorra City (map 774), event 122 at (32, 17): it asks for a four digit code in variable 62;
# 3862 opens one box (switch 1064) and 2368 the other (1063), and a code whose box is open does nothing. The core says
# no answer for a page that compares two codes, so with the assist the answer is the code of the box still shut.
module PokeAccess
  module RebornEeveeKeypad
    CODES = [[1064, "3862"], [1063, "2368"]]

    # The answer line for the first box still shut, or nil with both open.
    def self.answer
      shut = CODES.find { |sw, _code| !$game_switches[sw] }
      shut && [:puzzle_answer, { :a => shut[1] }]
    end
  end
end

PokeAccess::Game.define("reborn") do
  keypad = PokeAccess::RebornEeveeKeypad
  mechanic(:state, 774, :part => :keypad) do
    auto
    name 122, :rbe_eevee_keypad
    on_use 122, lambda { |_ev| keypad.answer }, :assist => true
  end
end
