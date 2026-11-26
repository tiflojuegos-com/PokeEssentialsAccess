# Room I of the Eastridge Escape Room (map 135): eleven pads with no graphic over a pit, a row of seven on y = 16 and
# one above and below its third and fifth. Landing on a pad with a direction held jumps two tiles that way. Variable 47
# climbs as the pads of ORDER are landed on in turn; the last sends the player to the exit door (event 2), open at 5.
module PokeAccess
  module AshenJumpRoom
    MAP = 135
    ROW = [7, 4, 9, 5, 10, 6, 8]
    ABOVE = { 11 => 3, 12 => 5 }
    BELOW = { 13 => 3, 14 => 5 }
    # The pad each value of variable 47 waits for, and the hint said for it.
    ORDER = [[13, :afg_er1_step1], [4, :afg_er1_step2], [9, :afg_er1_step3], [6, :afg_er1_step4], [11, :afg_er1_step5]]

    # The ids of every pad.
    def self.pads
      ROW + ABOVE.keys + BELOW.keys
    end

    # A pad's name: its place along the row, or the pad of the row it stands above or below.
    def self.label(ev)
      k = ROW.index(ev.id)
      return [:afg_er1_pad, { :n => k + 1 }] if k
      return [:afg_er1_pad_above, { :n => ABOVE[ev.id] }] if ABOVE[ev.id]
      BELOW[ev.id] ? [:afg_er1_pad_below, { :n => BELOW[ev.id] }] : nil
    end

    # How many steps of the order have been taken, from variable 47.
    def self.step
      $game_variables[47].to_i
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  jr = PokeAccess::AshenJumpRoom
  mechanic(:state, jr::MAP, :part => :jumps) do
    auto
    name jr.pads, lambda { |ev| jr.label(ev) }
    arrival_hint :afg_er1_rule
    jr::ORDER.each_with_index do |(pad, hint), k|
      phase lambda { PokeAccess::Puzzles.assist? && jr.step == k },
            :hint => hint, :spots => [{ :event => pad, :label => :afg_er1_next, :onto => true }]
    end
    phase lambda { jr.step < 5 }
    solved(nil, :quiet => true) { jr.step >= 5 }
  end
end
