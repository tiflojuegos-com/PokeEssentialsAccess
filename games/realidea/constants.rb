# Realidea profile: only what differs from core/foundation/config.rb.
PokeAccess::Game.define("realidea") do
  # The game extends both weather enums past the vanilla range, and the core tables stopped short, so these
  # read as nothing at all: a battle under Aroma was announced as having no field condition, and three
  # overworld weathers that fill the screen came out as clear skies. Ids from the game's own PBWeather
  # (AROMA = 9) and PBFieldWeather (ShadowSky = 8, Aroma = 9, Ash = 10). Shadow Sky already has a core key,
  # so it reuses it and stays translated; the two the game invented carry its own Spanish names.
  names(:weather_names, 9 => "Aroma")
  names(:field_weather_names, 8 => :w_shadow_sky, 9 => "Aroma", 10 => "Ceniza")
end
