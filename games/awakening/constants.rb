# Awakening profile: only what differs from core/foundation/config.rb.
PokeAccess::Game.define("awakening") do
  # The game's ninth battle weather (PBWeather MIASMA = 9).
  names(:weather_names, 9 => "Miasma")

  # Its statues (pbMoverEstatuas) are pulled with the action button, and pushed holding the way toward them.
  pull_script(/pbMoverEstatuas/)

  # Its Kernel.pbSurf refuses while anyone walks along as a dependent event.
  surf_company(:dependents)

  # The hint letters of the buttons the game kept (its Input moves X, Y and Z and reads A, S, D, F and G raw).
  key_hints "Z" => :a, "X" => :b, "C" => :c, "Q" => :l, "W" => :r

  # Its v17 party panel draws pokerus in the state slot.
  override("PokeAccess::Party", :panel_pokerus?) { |_mod, _original, _args| true }
end
