# The basement under the academy of Berilo Town (map 28): six levers (variable 34 counts them) open the door at the back
# and send the Porygon-Z away (switch 63). A Porygon-Z that sees the player, up to three tiles ahead of where it faces,
# sends them back to the start; four invisible tiles set the one by the middle room turning. Switch 63 ends it: no rule on
# arriving, nothing on the info key.
module PokeAccess
  module RealideaBerilo
    SENTINELS = [9, 13, 24, 30, 31, 32]
    TWIGS = [25, 26, 27, 28]
    START = [18, 48]
    GONE = 63
    WORDS = { 2 => :dir_down, 4 => :dir_left, 6 => :dir_right, 8 => :dir_up }

    # The name of a sentinel, with the way it faces as it is asked.
    def self.sentinel(ev)
      lambda { [:rea_berilo_sentinel, { :dir => PokeAccess::I18n.t(WORDS[ev.direction] || :dir_down) }] }
    end
  end
end

PokeAccess::Game.define("realidea") do
  berilo = PokeAccess::RealideaBerilo
  mechanic(:state, 28) do
    auto
    name berilo::SENTINELS, lambda { |ev| berilo.sentinel(ev) }
    name berilo::TWIGS, :rea_berilo_twig
    count :rea_levers_pulled, :var => 34, :of => 6
    sent_back :rea_berilo_seen, :to => berilo::START, :events => berilo::SENTINELS
    arrival_hint :rea_berilo_rule
    solved { $game_switches[berilo::GONE] }
  end
end
