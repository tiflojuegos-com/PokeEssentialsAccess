# Saki's gym in the Axis Factory (map 111): each of four statues (events 68, 71, 72 and 73) adds one to variable 703
# when turned the right way, and the four open a chest. A statue already turned (self switch A) asks to be reset
# instead, and resetting a right one (self switch B) takes the one back; a wrong one has to be reset to turn it again.
module PokeAccess
  module RejuvAxisFactory
    # What a statue's menu takes: variable 703 while it waits to be turned, a reset (self switch A off) if turned wrong,
    # nothing once turned right.
    def self.statue_takes
      id = PokeAccess.ivar($game_system.map_interpreter, :@event_id)
      return { :var => 703 } unless $game_self_switches[[111, id, "A"]]
      $game_self_switches[[111, id, "B"]] ? nil : { :self => "A" }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  mechanic(:state, 111, :part => :statues) do
    auto
    right_choice [68, 71, 72, 73], :takes => lambda { PokeAccess::RejuvAxisFactory.statue_takes }
    solved { $game_variables[703].to_i >= 6 }
  end
end
