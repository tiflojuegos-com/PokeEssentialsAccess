# Awakening profile: only what differs from core/foundation/config.rb.
PokeAccess::Game.define("awakening") do
  # The game adds a ninth battle weather past the vanilla eight, so a fight under it was announced as having
  # no field condition at all. Id from the game's own PBWeather (MIASMA = 9).
  names(:weather_names, 9 => "Miasma")
end
