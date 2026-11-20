# The Black Fox Base under Cellia (maps 281 to 287): a chain of consoles, each an action event with no sprite at the room's
# north wall. The lobby's console (map 282, event 7, switch 578) unlocks the two side doors of the corridor (map 281,
# events 1 and 2, to maps 286 and 285); each side room's console (event 7, switches 577 and 579) lowers the barrier of
# one entry room (maps 283 and 284, events 1 to 6); the console behind each barrier adds one to variable 78, and at 2
# the barriers of the corridor and the lobby (map 281 event 3, map 282 event 6) open toward Amelia. In her office (map
# 287) her chair, event 2, has a button under its armrest once the quest reaches variable 125 at 9 (Ryder looks first,
# at 8); pressing it moves 125 on, and the hidden stairway (event 19) is there from 10.
module PokeAccess
  module DesolationBlackFox
    CONSOLES = { 282 => 7, 285 => 7, 286 => 7, 283 => 7, 284 => 7 }

    # The hint of the chain from where it stands.
    def self.hint
      return :deso_fox_hint_lobby unless $game_switches[578]
      return :deso_fox_hint_sides unless $game_switches[577] && $game_switches[579]
      :deso_fox_hint_entries
    end
  end
end

PokeAccess::Game.define("desolation") do
  fox = PokeAccess::DesolationBlackFox
  [281, 282, 283, 284, 285, 286].each do |map|
    mechanic(:state, map) do
      auto
      name fox::CONSOLES[map], :deso_fox_console if fox::CONSOLES[map]
      count :deso_fox_entry_consoles, :var => 78, :of => 2, :assist => true
      hint lambda { fox.hint }
      solved { $game_variables[78].to_i >= 2 }
    end
  end
  mechanic(:state, 287) do
    auto
    name 2, :deso_fox_chair, :when => lambda { |_ev| $game_variables[125].to_i >= 8 && $game_variables[125].to_i < 10 }
    right_choice 2, :takes => { :var => 125 }
    hint :deso_fox_chair_hint
    active { $game_variables[125].to_i >= 8 && $game_variables[125].to_i < 10 }
    solved { $game_variables[125].to_i >= 10 }
  end
end
