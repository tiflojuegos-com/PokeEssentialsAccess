# Pokemon Rejuvenation 14: only what differs from core/foundation/config.rb.
PokeAccess::Game.define("rejuvenation") do
  # Its advanced weather turns each number into a symbol of its own (Game_Screen#weather in AdvancedWeather.rb); these
  # are the real weathers among its effects, under the names the core gives them.
  names(:field_weather_names, :Storm => :w_storm, :Thunder => :w_storm, :RealThunder => :w_storm,
        :StormLegacy => :w_storm, :RainLegacy => :w_rain, :SnowAlt => :w_snow, :Blizzard => :w_blizzard,
        :BlizzardAlt => :w_blizzard, :Sunny => :w_sun, :Winds => :w_wind, :FallingAsh => :w_ash)
end
