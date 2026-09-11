# Battle pure helpers (the G-key field report and the level-up table): each is a side-effect-free function
# tested directly. Weather resolves dual-shape (gen-6 integer + modern symbol); the level-up text diffs the
# new stats against the old values the scene passed; expected strings go through I18n so the assertion holds
# in whatever language is loaded.
Suite.define("battle: weather and mega-evolution cues") do
  eq "weather gen-6 integer", PokeAccess::Battle.weather_name(1), PokeAccess::I18n.t(:w_sun)
  eq "weather modern symbol", PokeAccess::Battle.weather_name(:Sun), PokeAccess::I18n.t(:w_sun)
  truthy "weather none is nil",
         PokeAccess::Battle.weather_name(:None).nil? && PokeAccess::Battle.weather_name(0).nil?

  truthy "mega open does not announce", PokeAccess::Battle.mega_key(nil, 1).nil?
  eq "mega activate", PokeAccess::Battle.mega_key(1, 2), :bt_mega_on
  eq "mega deactivate", PokeAccess::Battle.mega_key(2, 1), :bt_mega_off
  truthy "mega no change does not announce", PokeAccess::Battle.mega_key(1, 1).nil?
end

# Level-up stat table: diffs the new stats (on the pokemon) against the old values the scene passed; no
# change and a nil pokemon both yield nil.
Suite.define("battle: level-up stat differences") do
  lvpkmn = Struct.new(:totalhp, :attack, :defense, :spatk, :spdef, :speed)
  lvp = lvpkmn.new(48, 30, 28, 25, 24, 33)
  lvexp = [[:st_hp, 3], [:st_atk, 2], [:st_spdef, 2], [:st_speed, 3]].map do |k, n|
    PokeAccess::I18n.t(:lvl_stat, :stat => PokeAccess::I18n.t(k), :n => n)
  end.join(", ")
  eq "per-stat difference", PokeAccess::Battle.levelup_text(lvp, 45, 28, 28, 25, 22, 30), lvexp
  truthy "no change yields nil", PokeAccess::Battle.levelup_text(lvp, 48, 30, 28, 25, 24, 33).nil?
  truthy "nil pokemon yields nil", PokeAccess::Battle.levelup_text(nil, 1, 1, 1, 1, 1, 1).nil?
end

# Overworld field report (G key outside battle): gen-6 integers follow the PBFieldWeather layout (rain=1,
# storm=2, blizzard=4), distinct from the battle table; zero/none is nil. The day/night clock and the
# Safari/Bug-Contest minigame globals are absent in the harness, so those guard to nil rather than crash.
Suite.define("battle: overworld weather, clock and minigame guards") do
  eq "overworld rain (1)", PokeAccess::Battle.overworld_weather_name(1), PokeAccess::I18n.t(:w_rain)
  eq "overworld blizzard (4)", PokeAccess::Battle.overworld_weather_name(4), PokeAccess::I18n.t(:w_blizzard)
  truthy "overworld none is nil", PokeAccess::Battle.overworld_weather_name(0).nil?
  truthy "time_of_day without a clock is nil", PokeAccess::Battle.time_of_day.nil?
  eq "m:ss formatting", PokeAccess::Battle.fmt_mmss(125), "2:05"
  truthy "field_event_text without state is nil", PokeAccess::Battle.field_event_text.nil?
end

# Ability cue (modern BattleScene helper): "name: ability" or nil when there is no ability.
Suite.define("battle: ability cue helper") do
  abil = Struct.new(:pbThis, :abilityName)
  eq "name plus ability",
     PokeAccess::BattleScene.ability_text(abil.new("Pikachu enemigo", "Electricidad Estatica")),
     PokeAccess::I18n.t(:bt_ability, :name => "Pikachu enemigo", :ability => "Electricidad Estatica")
  truthy "no ability is nil", PokeAccess::BattleScene.ability_text(abil.new("X", "")).nil?
  truthy "nil is nil", PokeAccess::BattleScene.ability_text(nil).nil?
end

# The MODERN branch of the same reader, which had no spec at all -- which is how it could be changed into
# reading English identifiers out loud without anything turning red.
#
# In this class the game's "name" is usually not a name: vanilla sets @real_name = hash[:id].to_s and
# aliases name to it, and no register() in any surveyed game passes a :name. So the mod's own table has to
# be asked FIRST, and the game's name only when it is something other than the symbol itself.
Suite.define("battle: a modern weather is named from the mod's table, not from its own identifier") do
  bt = PokeAccess::Battle
  eq "a weather the mod has a word for is said in the player's language",
     bt.overworld_weather_name(:Sandstorm), PokeAccess::I18n.t(:w_sandstorm)
  eq "and so is the one whose identifier reads like a name already",
     bt.overworld_weather_name(:HeavyRain), PokeAccess::I18n.t(:w_heavy_rain)

  # A weather the game invented: nothing in the mod's table, and its name IS its symbol, so there is
  # nothing better to say than the symbol -- but it must not pretend to be a translation.
  eq "an invented weather with no name of its own falls back to its identifier",
     bt.overworld_weather_name(:FogLeafG), "FogLeafG"

  # A profile can name that one, and then the profile wins over everything.
  saved = PokeAccess::Config.field_weather_names.dup
  begin
    PokeAccess::Config.field_weather_names[:FogLeafG] = :w_sandstorm
    eq "a profile's declaration is the first thing asked",
       bt.overworld_weather_name(:FogLeafG), PokeAccess::I18n.t(:w_sandstorm)
  ensure
    PokeAccess::Config.field_weather_names.clear
    PokeAccess::Config.field_weather_names.merge!(saved)
  end

  truthy "none is still nothing", bt.overworld_weather_name(:None).nil?
end
