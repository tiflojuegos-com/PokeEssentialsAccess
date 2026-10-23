# Battle's pure helpers: weather names (battle, overworld, a profile's, the game's), the time of day, the Mega cue,
# the level-up gains, the ability splash line, and the Safari and Poke Radar parts of the field report.
class BattleHelpersTest < PokeAccessTest
  Battle = PokeAccess::Battle
  T = PokeAccess::I18n
  # A Pokemon's six stats, as the level-up line reads them.
  Stats = Struct.new(:totalhp, :attack, :defense, :spatk, :spdef, :speed)
  # A battler, as the ability splash line reads it.
  Battler = Struct.new(:pbThis, :abilityName)
  # A Safari or Bug Contest as pbSafariState and pbBugContestState answer them: whether it runs, balls and steps left.
  Minigame = Struct.new(:running, :ballcount, :steps) do
    def inProgress?
      running
    end
  end
  # A Safari whose state cannot tell whether it runs.
  UnsureSafari = Struct.new(:ballcount, :steps) do
    def inProgress?
      raise "no safari data"
    end
  end
  # A weather's GameData entry: its name and the real_name it is translated from, or only the latter.
  WeatherData = Struct.new(:name, :real_name)
  WeatherRealName = Struct.new(:real_name)

  test "names a battle weather from a gen-6 number or a modern symbol" do
    keys = { 1 => :w_sun, 3 => :w_sandstorm, :Sun => :w_sun, :HeavyRain => :w_heavy_rain, :SUNNYDAY => :w_sun }
    keys.each { |id, key| assert_equal T.t(key), Battle.weather_name(id), "for #{id.inspect}" }
  end

  test "has no battle weather name for none or an id it does not know" do
    [nil, 0, :None, 99, :Fog].each { |id| assert_nil Battle.weather_name(id), "for #{id.inspect}" }
  end

  test "says a profile's battle weather, by key or as the profile writes it" do
    with_table(PokeAccess::Config.weather_names, 9 => :w_aroma, 10 => "Miasma") do
      assert_equal T.t(:w_aroma), Battle.weather_name(9), "a key"
      assert_equal "Miasma", Battle.weather_name(10), "a literal"
    end
  end

  test "names a gen-6 overworld weather by PBFieldWeather's numbers, not the battle's" do
    { 1 => :w_rain, 2 => :w_storm, 4 => :w_blizzard, 7 => :w_sun }.each do |id, key|
      assert_equal T.t(key), Battle.overworld_weather_name(id), "for #{id}"
    end
  end

  test "has no overworld weather name for none, Clear or a number it does not know" do
    [nil, 0, :None, :Clear, 99].each { |id| assert_nil Battle.overworld_weather_name(id), "for #{id.inspect}" }
  end

  test "names a modern overworld weather from the mod's words, not from its identifier" do
    { :Sandstorm => :w_sandstorm, :HeavyRain => :w_heavy_rain, :Rain => :w_rain }.each do |id, key|
      assert_equal T.t(key), Battle.overworld_weather_name(id), "for #{id}"
    end
  end

  test "asks a profile's overworld names first, for a number or a symbol" do
    names = { 1 => :w_storm, 8 => :w_shadow_sky, :Rain => :w_snow, :FogLeafG => :w_sandstorm }
    with_table(PokeAccess::Config.field_weather_names, names.merge(10 => "Fuego")) do
      names.each { |id, key| assert_equal T.t(key), Battle.overworld_weather_name(id), "for #{id.inspect}" }
      assert_equal "Fuego", Battle.overworld_weather_name(10), "a literal"
    end
  end

  test "says an invented weather by the name the game gives it" do
    said = { WeatherData.new("Niebla de hojas", "Leaf Fog") => "Niebla de hojas",
             WeatherData.new("", "Bruma") => "Bruma", WeatherRealName.new("Bruma") => "Bruma" }
    said.each do |data, name|
      with_game_weathers(:FogLeafG => data) do
        assert_equal name, Battle.overworld_weather_name(:FogLeafG), "for #{data.inspect}"
      end
    end
  end

  test "says an invented weather by its identifier when the game gives it no other name" do
    [WeatherData.new("FogLeafG", "FogLeafG"), WeatherData.new("", "")].each do |data|
      with_game_weathers(:FogLeafG => data) do
        assert_equal "FogLeafG", Battle.overworld_weather_name(:FogLeafG), "for #{data.inspect}"
      end
    end
    with_game_weathers({}) { assert_equal "FogLeafG", Battle.overworld_weather_name(:FogLeafG), "unknown to the game" }
    with_constant(:GameData, nil) { assert_equal "FogLeafG", Battle.overworld_weather_name(:FogLeafG), "no GameData" }
  end

  test "says no time of day where the game keeps no clock" do
    with_constant(:PBDayNight, nil) { assert_nil Battle.time_of_day }
  end

  test "says the evening before the v16 afternoon that covers it" do
    bands = { :morning => [6, 12], :afternoon => [12, 20], :evening => [17, 20], :night => [20, 6], :day => [6, 20] }
    with_constant(:PBDayNight, day_night(bands)) do
      { 7 => :tod_morning, 13 => :tod_afternoon, 18 => :tod_evening, 22 => :tod_night }.each do |hour, key|
        at_hour(hour) { assert_equal key, Battle.time_of_day, "at #{hour}h" }
      end
    end
  end

  test "keeps the modern clock's bands apart, the broad day saying the hours between them" do
    bands = { :morning => [5, 10], :afternoon => [14, 17], :evening => [17, 20], :night => [20, 5], :day => [5, 20] }
    said = { 6 => :tod_morning, 11 => :tod_day, 15 => :tod_afternoon, 18 => :tod_evening, 3 => :tod_night }
    with_constant(:PBDayNight, day_night(bands)) do
      said.each { |hour, key| at_hour(hour) { assert_equal key, Battle.time_of_day, "at #{hour}h" } }
    end
  end

  test "skips a band the clock cannot answer" do
    cases = { [{ :night => [20, 6], :day => [6, 20] }, 22] => :tod_night, [{ :day => [6, 20] }, 12] => :tod_day }
    cases.each do |(bands, hour), key|
      with_constant(:PBDayNight, day_night(bands)) do
        at_hour(hour) { assert_equal key, Battle.time_of_day, "#{bands.keys.inspect} at #{hour}h" }
      end
    end
    with_constant(:PBDayNight, day_night({})) { at_hour(12) { assert_nil Battle.time_of_day, "a clock with no bands" } }
  end

  test "reads the clock at the game's own now" do
    asked = []
    with_constant(:PBDayNight, night_watch(asked)) do
      game_now = Time.local(2026, 1, 1, 3)
      GameFunctions.with(:pbGetTimeNow => lambda { game_now }) { Battle.time_of_day }
      assert_equal [game_now], asked
    end
  end

  test "reads the clock at the computer's time where the game keeps no now of its own" do
    asked = []
    with_constant(:PBDayNight, night_watch(asked)) do
      before = Time.now
      Battle.time_of_day
      after = Time.now
      assert_equal 1, asked.length, "asked once"
      assert_operator asked[0], :>=, before
      assert_operator asked[0], :<=, after
    end
  end

  test "announces the Mega button registered or cancelled" do
    assert_equal :bt_mega_on, Battle.mega_key(1, 2), "registered"
    assert_equal :bt_mega_off, Battle.mega_key(2, 1), "cancelled"
  end

  test "keeps quiet as the Mega button comes up, stays put or hides" do
    [[nil, 1], [0, 1], [0, 2], [1, 1], [2, 2], [1, 0], [2, 0]].each do |last, now|
      assert_nil Battle.mega_key(last, now), "from #{last.inspect} to #{now}"
    end
  end

  test "answers the keys it is given for another mechanic's button" do
    assert_equal :bt_ultra_on, Battle.mega_key(1, 2, :bt_ultra_on, :bt_ultra_off), "registered"
    assert_equal :bt_ultra_off, Battle.mega_key(2, 1, :bt_ultra_on, :bt_ultra_off), "cancelled"
  end

  test "lists each stat that grew with its gain, in the summary's order" do
    assert_equal gains([:st_hp, 3], [:st_atk, 2], [:st_spdef, 2], [:st_speed, 3]),
                 Battle.levelup_text(Stats.new(48, 30, 28, 25, 24, 33), 45, 28, 28, 25, 22, 30)
  end

  test "leaves out a stat it has no old or no new value for" do
    no_speed = Struct.new(:totalhp, :attack, :defense, :spatk, :spdef).new(48, 30, 28, 25, 24)
    assert_equal gains([:st_hp, 3], [:st_spdef, 2]), Battle.levelup_text(no_speed, 45, nil, 28, 25, 22, 30)
  end

  test "has no level-up line when no stat grew or there is no Pokemon" do
    assert_nil Battle.levelup_text(Stats.new(48, 30, 28, 25, 24, 33), 48, 30, 28, 25, 24, 33), "no stat grew"
    assert_nil Battle.levelup_text(nil, 45, 28, 28, 25, 22, 30), "no Pokemon"
  end

  test "says the battler and its ability as the splash comes up" do
    assert_equal T.t(:bt_ability, :name => "Pikachu enemigo", :ability => "Electricidad Estática"),
                 PokeAccess::BattleScene.ability_text(Battler.new("Pikachu enemigo", "Electricidad Estática"))
  end

  test "says the text the splash shows in place of the battler's ability" do
    assert_equal T.t(:bt_ability, :name => "Zoroark enemigo", :ability => "Ilusión"),
                 PokeAccess::BattleScene.ability_text(Battler.new("Zoroark enemigo", "Presión"), "Ilusión")
  end

  test "has no splash line without a battler or an ability to say" do
    unreadable = Class.new { def pbThis; "Pikachu enemigo"; end; def abilityName; raise "no ability data"; end }.new
    battlers = { "no battler" => nil, "an empty ability" => Battler.new("Pikachu enemigo", ""),
                 "no ability" => Battler.new("Pikachu enemigo", nil), "an ability it cannot read" => unreadable }
    battlers.each { |what, battler| assert_nil PokeAccess::BattleScene.ability_text(battler), what }
  end

  test "reports nothing when no Safari, contest or radar chain is on" do
    with_pokemon_temp(nil) { assert_nil Battle.field_event_text }
  end

  test "reports a running Safari's balls and steps left" do
    with_minigames(Minigame.new(true, 12, 300), nil) do
      assert_equal [T.t(:safari_balls, :n => 12), T.t(:safari_steps, :n => 300)].join(", "), Battle.field_event_text
    end
  end

  test "leaves out the steps of a Safari that counts none, but says the last one left" do
    balls = T.t(:safari_balls, :n => 12)
    { 0 => balls, nil => balls, 1 => [balls, T.t(:safari_steps, :n => 1)].join(", ") }.each do |steps, said|
      with_minigames(Minigame.new(true, 12, steps), nil) do
        assert_equal said, Battle.field_event_text, "#{steps.inspect} steps"
      end
    end
  end

  test "reports nothing for a running Safari with neither balls nor steps to tell" do
    with_minigames(Minigame.new(true, nil, 0), nil) { assert_nil Battle.field_event_text }
  end

  test "leaves to the radar chain a Safari or contest that is not running or cannot tell whether it is" do
    idle = Minigame.new(false, 12, 300)
    with_radar_data([:PIKACHU, 12, 3, []]) do
      [[idle, idle], [UnsureSafari.new(12, 300), nil]].each do |safari, contest|
        with_minigames(safari, contest) do
          assert_equal T.t(:radar_chain, :n => 3), Battle.field_event_text, "#{safari.class.name}, #{contest.inspect}"
        end
      end
    end
  end

  test "reports the Poke Radar chain from the radar state of either era" do
    with_radar_data([:PIKACHU, 12, 3, [[4, 5, 0, false]]]) do
      assert_equal T.t(:radar_chain, :n => 3), Battle.field_event_text, "from v20 on"
    end
    with_pokemon_temp(Struct.new(:pokeradar).new([:PIKACHU, 12, 1, [[4, 5, 0, false]]])) do
      assert_equal T.t(:radar_chain, :n => 1), Battle.field_event_text, "before v20"
    end
  end

  test "reports no chain before the radar has one, or from a radar state it cannot read" do
    no_count = [:PIKACHU, 12, Object.new, []]
    [[:PIKACHU, 12, 0, []], [:PIKACHU, 12, nil, []], no_count, { 2 => 4 }, true].each do |data|
      with_radar_data(data) { assert_nil Battle.field_event_text, "for #{data.inspect}" }
    end
  end

  private

  # The level-up line for [stat key, gain] pairs, as the game's level-up panel lists them.
  def gains(*pairs)
    pairs.map { |key, n| T.t(:lvl_stat, :stat => T.t(key), :n => n) }.join(", ")
  end

  # Runs the block with entries merged into a Config name table, then puts the table back as it was.
  def with_table(table, entries)
    was = table.dup
    table.update(entries)
    yield
  ensure
    table.replace(was)
  end

  # Runs the block with a GameData::Weather whose get answers data[id], raising for an id it lacks as the game's does.
  def with_game_weathers(data)
    weather = Module.new
    weather.define_singleton_method(:get) { |id| data.fetch(id) }
    game_data = Module.new
    game_data.const_set(:Weather, weather)
    with_constant(:GameData, game_data) { yield }
  end

  # A PBDayNight answering is<Band>? for each band given (name => [from, to) hours, wrapping past midnight) by the
  # hour of the time asked; a band left out has no method, as on a clock that lacks it.
  def day_night(bands)
    asks = { :morning => :isMorning?, :afternoon => :isAfternoon?, :evening => :isEvening?, :night => :isNight?,
             :day => :isDay? }
    clock = Module.new
    bands.each do |band, (from, to)|
      clock.define_singleton_method(asks[band]) do |time|
        from < to ? (time.hour >= from && time.hour < to) : (time.hour >= from || time.hour < to)
      end
    end
    clock
  end

  # A PBDayNight that knows only the night, which it says it always is, noting each time it is asked about.
  def night_watch(asked)
    clock = Module.new
    clock.define_singleton_method(:isNight?) do |time|
      asked.push(time)
      true
    end
    clock
  end

  # Runs the block with the game's pbGetTimeNow at hour o'clock.
  def at_hour(hour)
    GameFunctions.with(:pbGetTimeNow => lambda { Time.local(2026, 1, 1, hour) }) { yield }
  end

  # Runs the block with pbSafariState answering safari and pbBugContestState contest.
  def with_minigames(safari, contest)
    GameFunctions.with(:pbSafariState => lambda { safari }, :pbBugContestState => lambda { contest }) { yield }
  end

  # Runs the block with v20's radar state ($game_temp.poke_radar_data) answering data and no older one.
  def with_radar_data(data)
    $game_temp.define_singleton_method(:poke_radar_data) { data }
    with_pokemon_temp(nil) { yield }
  ensure
    $game_temp.singleton_class.send(:remove_method, :poke_radar_data)
  end

  # Runs the block with $PokemonTemp, where the radar kept its state before v20, set to temp.
  def with_pokemon_temp(temp)
    was = $PokemonTemp
    $PokemonTemp = temp
    yield
  ensure
    $PokemonTemp = was
  end

  # Runs the block with the top-level constant name set to value, or missing for nil, then puts back what was there.
  def with_constant(name, value)
    had = Object.const_defined?(name, false)
    was = had ? Object.send(:remove_const, name) : nil
    Object.const_set(name, value) unless value.nil?
    yield
  ensure
    Object.send(:remove_const, name) if Object.const_defined?(name, false)
    Object.const_set(name, was) if had
  end
end
