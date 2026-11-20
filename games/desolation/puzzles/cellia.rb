# Cellia. The candy store (map 289): the scene locks the door, and a red switch under the register (event 6, no sprite)
# breaks it (switch 585), after which Garret opens the way out. The Suspicious House of Cellia North (map 353): a phone
# (event 1) and a laptop (event 15) ask for numbers, which the core answers with the assist, and the bin (event 14) holds
# the note with the laptop's user and password. In the sewers (map 261), three consoles with no sprite (events 50, 69, 86)
# raise a bridge each, which the core says as it opens. The Pyrulean Lab (map 355): five diary entries (events 10 to 14)
# add one each to variable 109; the one of event 14, read while the count is 5 (again if need be), takes it to 6 with the
# computer chip; the old terminal (event 15) takes the chip at 6 (7), and the machine (event 1) then opens a cabinet with a
# Turtwig (its self switch A once taken).
module PokeAccess
  module DesolationPyrulean
    # The lab's next step with the assist.
    def self.hint
      v = $game_variables[109].to_i
      return :deso_lab_diaries_hint if v < 5
      return :deso_lab_chip_hint if v == 5
      v == 6 ? :deso_lab_terminal_hint : :deso_lab_cabinet_hint
    end
  end
end

PokeAccess::Game.define("desolation") do
  mechanic(:state, 289) do
    auto
    name 6, lambda { |_ev| PokeAccess::Puzzles.assist? ? :deso_candy_switch : :deso_candy_register },
         :when => lambda { |_ev| !$game_switches[585] }
    hint :deso_candy_hint
    solved { $game_switches[585] }
  end
  mechanic(:state, 261) do
    auto
    name [50, 69, 86], :deso_sewer_console
  end
  mechanic(:state, 355) do
    auto
    name (10..14).to_a, :deso_lab_diary
    name 15, :deso_lab_terminal
    name 1, :deso_lab_machine
    count :deso_lab_entries, :var => 109, :of => 5, :assist => true
    hint lambda { PokeAccess::DesolationPyrulean.hint }
    solved { $game_self_switches[[355, 1, "A"]] }
  end
  mechanic(:state, 353) do
    auto
    name 1, :deso_house_phone
    name 15, :deso_house_laptop
    name 14, :deso_house_bin
    hint :deso_house_hint
    solved { $game_switches[683] }
  end
end
