# Noyanagi Plains (map 82, SQ1): once Akira has asked for help (var 35 at 1), three Kurai members hide as events with no
# graphic at (18, 4), (19, 19) and (36, 3). Each is solid and still: bumping into one moves it away (the grass rustles only where
# it lands), and on the third bump it shows itself; the fourth starts the fight. Each defeat adds 1 to var 35, which reaches 4
# with the three and opens Kazuo. What cannot be seen is named only with the puzzle assist.
PokeAccess::Game.define("keishou") do
  hiders = [9, 12, 13]
  found = lambda { [[$game_variables[35] - 1, 0].max, 3].min }
  hiding = lambda do |ev|
    $game_variables[35] >= 1 && !$game_self_switches[[82, ev.id, "C"]] && !$game_self_switches[[82, ev.id, "D"]]
  end
  mechanic(:state, 82) do
    auto
    name hiders, lambda { |ev| hiding.call(ev) ? :ks_kurai_hidden : nil }, :assist => true, :when => hiding
    count :ks_kurai_found, :of => 3, :value => found
    phase lambda { $game_variables[35] >= 1 && $game_variables[35] < 4 }, :title => :ks_kurai_rule, :entry_title => true,
          :hint => :ks_kurai_hint
  end
end
