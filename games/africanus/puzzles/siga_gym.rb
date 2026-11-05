# Siga's gym (map 7): sap from the palms (events 2 to 18, variable 64) is spent at a vat for a potion of the vat's colour
# (variable 65, switches 233 green, 234 red, 235 brown, 236 blue; each vat gives one once), and only the right potion
# clears the thorns: red the first group (events 27 to 31 and 33, switch 237), brown the second (events 32 and 34 to 38,
# switch 238). A wrong one spends the sap and the potion and starts a wild fight. Each vat is two events side by side.
# Both groups gone ends it: no rule on arriving, nothing on the info key.
PokeAccess::Game.define("africanus") do
  mechanic(:state, 7) do
    auto
    name 2..18, :af_sap_palm
    name 19, :af_vat_green
    name 21, :af_vat_red
    name 23, :af_vat_brown
    name 25, :af_vat_blue
    hide [20, 22, 24, 26]
    obstacle({ :events => [27, 28, 29, 30, 31, 33] }, :label => :af_thorns_first)
    obstacle({ :events => [32, 34, 35, 36, 37, 38] }, :label => :af_thorns_second)
    watch :var => 64, :label => :af_sap, :on => :af_yes, :off => :af_no
    watch :var => 65, :label => :af_potion, :on => :af_yes, :off => :af_no
    count :af_thorns_cleared, :switches => [237, 238]
    arrival_hint :af_siga_rule
    solved { $game_switches[237] && $game_switches[238] }
    phase(lambda { !$game_switches[237] }, :title => :af_siga_first, :hint => :af_siga_first_hint)
    phase(lambda { $game_switches[237] && !$game_switches[238] }, :title => :af_siga_second,
          :hint => :af_siga_second_hint)
  end
end
