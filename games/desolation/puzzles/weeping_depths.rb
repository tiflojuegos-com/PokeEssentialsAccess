# Weeping Depths. Map 14: sixteen gravestones in rows; only event 2 sounds hollow, and with the quest Explore the Depths
# (switch 199) Lucas's key crumbles it (switch 227). Map 12: ten broken gravestones add one each to variable 46 once their
# text is read; with 9 the next one read opens the door of event 25 (switch 233). Map 20: the poem (event 1) puts
# variable 45 at 0, and events 2 to 65 are a ring of hidden floor that counts only stepped in order (event n while
# variable 45 is n - 2), any other putting it back to 0; on the last, at 63, the Old Doll opens the door (switch 231).
module PokeAccess
  module DesolationWeepingDepths
    PATH_FIRST = 2
    PATH_LAST = 65
    GRAVES = [7, 16, 17, 18, 19, 20, 21, 22, 23, 24]

    # The index of the path tile to step on next.
    def self.next_tile
      PATH_FIRST + $game_variables[45].to_i
    end
  end
end

PokeAccess::Game.define("desolation") do
  wd = PokeAccess::DesolationWeepingDepths
  mechanic(:state, 14) do
    auto
    name([2] + (4..18).to_a, lambda { |ev| PokeAccess::Puzzles.assist? && ev.id == 2 ? :deso_depths_hollow_grave : :deso_depths_grave })
    hint :deso_depths_hollow_hint
    solved { $game_switches[227] }
  end
  mechanic(:state, 12) do
    auto
    name wd::GRAVES, :deso_depths_broken_grave
    count :deso_depths_graves, :var => 46, :of => 9, :assist => true
    spot(:event => 25, :label => :deso_depths_door, :when => lambda { $game_switches[233] })
    hint :deso_depths_graves_hint
    solved { $game_switches[233] }
  end
  mechanic(:state, 20) do
    auto
    count :deso_depths_path, :var => 45, :of => 63, :assist => true, :reset => :deso_depths_path_reset
    (wd::PATH_FIRST..wd::PATH_LAST).each do |id|
      spot(:event => id, :label => (id == wd::PATH_LAST ? :deso_depths_path_last : :deso_depths_path_next),
           :assist => true, :onto => true, :when => lambda { wd.next_tile == id })
    end
    hint :deso_depths_path_hint
    solved { $game_switches[231] }
  end
end
