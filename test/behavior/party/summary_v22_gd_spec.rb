# Cycling Pokemon in the v22 summary: set_party_index calls refresh inside itself, and the reentrancy guard skips
# that nested refresh so set_party_index's own after-hook says the page with the new Pokemon's glance.
Suite.define("summary v22: switching Pokemon announces the new Pokemon's glance") do
  party = [Poke.build(:name => "Bulba", :species => 1, :level => 12, :hp => 22, :totalhp => 22),
           Poke.build(:name => "Char",  :species => 4, :level => 25, :hp => 33, :totalhp => 44)]
  vis = UI::PokemonSummaryVisuals.new(party, 0)

  SpeakCapture.clear
  vis.set_party_index(1)
  spoke "switching reads the new Pokemon's glance (name + HP fraction)", /Char/
  spoke "the glance HP fraction is spoken (only the glance voices it)", /33 (de|of) 44/

  SpeakCapture.clear
  vis.set_party_index(0)
  spoke "switching back reads the other Pokemon's glance", /Bulba/
  spoke "the second switch is not swallowed by the earlier dedup", /22 (de|of) 22/
end

# The glance prefixes only a Pokemon switch: a page change is read by go_to_next_page's after-hook, without it.
Suite.define("summary v22: a page change after a switch does not prepend a glance") do
  party = [Poke.build(:name => "Squir", :species => 7, :level => 30, :hp => 55, :totalhp => 60)]
  vis = UI::PokemonSummaryVisuals.new(party, 0)
  vis.set_party_index(0)

  SpeakCapture.clear
  vis.go_to_next_page(:skills)
  spoke "the page change is read", /55 (de|of) 60/
  not_spoke "page navigation does not prepend the Pokemon glance (name)", /Squir/
end
