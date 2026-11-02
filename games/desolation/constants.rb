# Pokemon Desolation 6.0.0: only what differs from core/foundation/config.rb.
PokeAccess::Game.define("desolation") do
  # Its overworld weathers keep the numbers events give them (pbPrepareBattle in Field.rb): 4 sandstorm, 5 sun,
  # 6 winds, 7 heavy rain, 8 blizzard, which the core's gen-6 table reads otherwise.
  names(:field_weather_names, 4 => :w_sandstorm, 5 => :w_sun, 6 => :w_wind, 7 => :w_heavy_rain, 8 => :w_blizzard)

  # M is the mod's coordinates key and, beside Alt, one of the game's two speed keys (System.rb): Alt keeps the speed.
  remap_extra(:des_speed_m, :M, :des_key_m)
  key_defaults(:des_speed_m => "None")
end
