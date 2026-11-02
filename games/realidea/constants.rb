# Realidea profile: only what differs from core/foundation/config.rb.
PokeAccess::Game.define("realidea") do
  # The weathers past the vanilla range, by the ids of the game's PBWeather and PBFieldWeather; the game paints no
  # name for its own two (Aroma and Ash), which take the mod's words.
  names(:weather_names, 9 => :w_aroma)
  names(:field_weather_names, 8 => :w_shadow_sky, 9 => :w_aroma, 10 => :w_ash)

  # The small-light warp pads (temples, ruins, oasis, metro, director's office) take the teleporter cue.
  teleporter(/\Alucecita\z/i)

  # Its own pbPushThisEvent, which Strength boulders go through too, pulls with the action button.
  pull_script(/pbPushThis(Event|Boulder)/)

  # Its pbPushThisBoulder moves a Strength boulder only with switch 379 on, which a story event sets, and asks for no
  # field move.
  push_script(/pbPushThisBoulder/) { $game_switches[379] ? true : false }

  # M is the mod's coordinates key. The game reads it by code on the map (clearing fog, 0056_Scene_Map; resetting a room,
  # by event), in the Mankey duel (repeating the line) and in the telegraph (its guide), and names it in messages. In
  # battle, where the coordinates say nothing, it stays the game's and shows the information (0087_PokeBattle_Scene).
  remap_extra(:rea_m, 0x4D, :rea_key_m, :button => :M)
  field_key_defaults(:rea_m => "Alt+M")

  # Key hints for the default letters, but not Q and W, which also fire the game's own pause-menu teleport.
  key_hints "Z" => :a, "X" => :b, "C" => :c, "A" => :x, "S" => :y, "D" => :z, "M" => :rea_m
end
