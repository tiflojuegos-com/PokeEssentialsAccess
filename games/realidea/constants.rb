# Realidea profile: only what differs from core/foundation/config.rb.
PokeAccess::Game.define("realidea") do
  # The weathers past the vanilla range, by the ids of the game's PBWeather and PBFieldWeather; the game paints no
  # name for its own two (Aroma and Ash), which take the mod's words.
  names(:weather_names, 9 => :w_aroma)
  names(:field_weather_names, 8 => :w_shadow_sky, 9 => :w_aroma, 10 => :w_ash)

  # The small-light warp pads (temples, ruins, oasis, metro, director's office) take the teleporter cue.
  teleporter(/\Alucecita\z/i)

  # Key hints for the default letters, but not Q and W, which also fire the game's own pause-menu teleport.
  key_hints "Z" => :a, "X" => :b, "C" => :c, "A" => :x, "S" => :y, "D" => :z
end
