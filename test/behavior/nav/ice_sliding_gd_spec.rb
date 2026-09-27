# The ice-slide flag is $PokemonGlobal.sliding up to v20 and ice_sliding from v21: Locator.sliding? answers to the
# modern name too.
Suite.define("guides: the v21 name of the ice-slide flag holds the guides too") do
  loc = PokeAccess::Locator
  falsy "nothing is sliding to begin with", loc.sliding?
  begin
    $PokemonGlobal.ice_sliding = true
    truthy "the modern flag alone says the player is sliding", loc.sliding?
  ensure
    $PokemonGlobal.ice_sliding = false
  end
  falsy "and it is over when the flag drops", loc.sliding?
end
