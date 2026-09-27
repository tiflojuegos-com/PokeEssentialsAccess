# Pokemon Insurgence 1.2.7 profile: only what differs from core/foundation/config.rb. Insurgence ships for the original
# RPG Maker XP player; this profile assumes it running under mkxp-z, where the mod can load.
PokeAccess::Game.define("insurgence") do
  # Its battle weathers (050_PBWeather.rb): New Moon takes 5, which moves harsh sun, heavy rain and strong winds to
  # 6, 7 and 9; the core's table has them at 5, 6 and 7.
  names(:weather_names, 5 => :ins_w_new_moon, 6 => :w_harsh_sun, 7 => :w_heavy_rain, 9 => :w_strong_winds)

  # Its overworld weathers are RPG Maker's weather types with sandstorm at 4 and sun at 5, as pbPrepareBattle
  # carries them into battle (086_PokemonField.rb); it has no PBFieldWeather, whose 4 and 5 the core reads.
  names(:field_weather_names, 4 => :w_sandstorm, 5 => :w_sun)
end
