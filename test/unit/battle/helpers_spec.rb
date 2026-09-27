# Battle's pure helpers. Weather resolves from a gen-6 integer or a modern symbol; the mega cue speaks when the
# toggle changes, not on opening.
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

# The overworld field report: gen-6 weather integers follow PBFieldWeather (rain 1, storm 2, blizzard 4), not the
# battle table; with no clock or minigame state in the harness those parts are nil.
Suite.define("battle: overworld weather, clock and minigame guards") do
  eq "overworld rain (1)", PokeAccess::Battle.overworld_weather_name(1), PokeAccess::I18n.t(:w_rain)
  eq "overworld blizzard (4)", PokeAccess::Battle.overworld_weather_name(4), PokeAccess::I18n.t(:w_blizzard)
  truthy "overworld none is nil", PokeAccess::Battle.overworld_weather_name(0).nil?
  truthy "time_of_day without a clock is nil", PokeAccess::Battle.time_of_day.nil?
  eq "m:ss formatting", PokeAccess::Battle.fmt_mmss(125), "2:05"
  truthy "field_event_text without state is nil", PokeAccess::Battle.field_event_text.nil?
end

# The day/night bands of both clocks: the v16 afternoon (12-20) covers the evening (17-20), so evening goes first;
# the modern one keeps them apart. The hour comes from the game's pbGetTimeNow, not the system clock.
Suite.define("battle: the evening is said on both day/night clocks") do
  clock = Module.new do
    class << self
      attr_accessor :bands
      def within?(name, time)
        lo, hi = bands[name]
        h = time.hour
        lo < hi ? (h >= lo && h < hi) : (h >= lo || h < hi)
      end
      def isMorning?(time); within?(:morning, time); end
      def isAfternoon?(time); within?(:afternoon, time); end
      def isEvening?(time); within?(:evening, time); end
      def isNight?(time); within?(:night, time); end
      def isDay?(time); within?(:day, time); end
    end
  end
  hour = 0
  Object.const_set(:PBDayNight, clock)
  Object.send(:define_method, :pbGetTimeNow) { Time.local(2026, 1, 1, hour) }
  Object.send(:private, :pbGetTimeNow)
  begin
    clock.bands = { :morning => [6, 12], :afternoon => [12, 20], :evening => [17, 20], :night => [20, 6], :day => [6, 20] }
    { 7 => :tod_morning, 13 => :tod_afternoon, 18 => :tod_evening, 22 => :tod_night }.each do |h, key|
      hour = h
      eq "v16 clock at #{h}h", PokeAccess::Battle.time_of_day, key
    end
    clock.bands = { :morning => [5, 10], :afternoon => [14, 17], :evening => [17, 20], :night => [20, 5], :day => [5, 20] }
    { 11 => :tod_day, 15 => :tod_afternoon, 18 => :tod_evening, 3 => :tod_night }.each do |h, key|
      hour = h
      eq "modern clock at #{h}h", PokeAccess::Battle.time_of_day, key
    end
  ensure
    Object.send(:remove_const, :PBDayNight)
    Object.send(:remove_method, :pbGetTimeNow)
  end
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

# A modern weather: a profile's declaration first, then the mod's table, the identifier last (the game's name is
# usually its own symbol, id.to_s).
Suite.define("battle: a modern weather is named from the mod's table, not from its own identifier") do
  bt = PokeAccess::Battle
  eq "a weather the mod has a word for is said in the player's language",
     bt.overworld_weather_name(:Sandstorm), PokeAccess::I18n.t(:w_sandstorm)
  eq "and so is the one whose identifier reads like a name already",
     bt.overworld_weather_name(:HeavyRain), PokeAccess::I18n.t(:w_heavy_rain)

  eq "an invented weather with no name of its own falls back to its identifier",
     bt.overworld_weather_name(:FogLeafG), "FogLeafG"

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
