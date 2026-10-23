# Pokemon Desolation 6.0.0: only what differs from core/foundation/config.rb.
PokeAccess::Game.define("desolation") do
  # Its overworld weathers keep the numbers events give them (pbPrepareBattle in Field.rb): 4 sandstorm, 5 sun,
  # 6 winds, 7 heavy rain, 8 blizzard, which the core's gen-6 table reads otherwise.
  names(:field_weather_names, 4 => :w_sandstorm, 5 => :w_sun, 6 => :w_wind, 7 => :w_heavy_rain, 8 => :w_blizzard)
end
