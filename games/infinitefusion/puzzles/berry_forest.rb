# Berry Forest (map 619): five lost children (events 24 to 28) come back to the camp as they are talked to (var 188), the
# count at the camp shows seven (switch 548) and the extra one, event 18 at (14, 19), is a Zoroark that fights when talked to
# (switch 871); beating it clears the forest (switch 860). The camp's children look alike and the editor's name "fake kid"
# stays out of every list.
PokeAccess::Game.define("infinitefusion") do
  lost = (24..28).to_a
  camp = [14, 15, 16, 17, 18, 19, 20]
  impostor = 18
  searching = lambda { $game_switches[548] && !$game_switches[860] }

  mechanic(:state, 619) do
    auto
    name lost, :ifu_berry_kid_lost
    name camp - [impostor], :ifu_berry_camp_kid, :when => lambda { |_ev| searching.call }
    name impostor, lambda { |_ev|
      PokeAccess::Puzzles.assist? && searching.call ? :ifu_berry_impostor : :ifu_berry_camp_kid
    }, :when => lambda { |_ev| searching.call }
    count :ifu_berry_kids, :var => 188, :of => 5
    hint lambda {
      if !$game_switches[861] then :ifu_berry_hint_ask
      elsif $game_variables[188] < 5 then :ifu_berry_hint_search
      elsif !$game_switches[548] then :ifu_berry_hint_count
      elsif !$game_switches[860] then :ifu_berry_hint_impostor
      end
    }
    solved(nil, :quiet => true) { $game_switches[860] }
  end
end
