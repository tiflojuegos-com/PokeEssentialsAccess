# Infinite Fusion Hoenn's weather icons (games/infinitefusion_hoenn/weather.rb): the one that slides down on entering a
# map is said after the place's name, or at once on a map already named; the PokeRadar's once per picture.

# The entry icon as Hoenn builds it: its picture's path, and a sprite only when it drew one.
class WeatherIcon
  def initialize(path, drawn = true)
    @icon_path = path
    @sprite = drawn ? Object.new : nil
  end
end

# The PokeNav's apps, of which the radar is one: ifh_screens_gd_test.rb declares the same hierarchy in this process, and
# a radar with another superclass would not load beside it.
class PokeNavAppScene; end

# The PokeRadar app, whose header shows the weather's picture.
class PokeRadarAppScene < PokeNavAppScene
  attr_writer :path
  def initialize(path = nil); @sprites = {}; @path = path; end
  def showWeatherIcon; @sprites["weather"] = Struct.new(:name).new(@path); end
end

ifh_weather_path = File.join(Harness::ROOT, "games", "infinitefusion_hoenn", "weather.rb")
eval(Harness.source(ifh_weather_path), TOPLEVEL_BINDING, ifh_weather_path)

class IfhWeatherGdTest < PokeAccessTest
  PICTURES = "Graphics/Pictures/Weather/"

  test "a picture names its weather and, for the kinds that vary, its strength" do
    { "mapRain_light" => t(:if2_wx_light, :w => t(:w_rain)),
      "mapFog_medium" => t(:if2_wx_medium, :w => t(:w_fog)),
      "mapSun_heavy" => t(:if2_wx_heavy, :w => t(:w_sun)),
      "mapStrongWinds" => t(:w_strong_winds),
      "mapSand" => t(:w_sandstorm) }.each do |picture, words|
      assert_equal words, PokeAccess::IF2Weather.icon_words(PICTURES + picture), picture
    end
    assert_equal t(:w_snow), PokeAccess::IF2Weather.icon_words("mapSnow"), "a bare file name"
  end

  test "any other picture is no weather" do
    ["cloud", "mapCloudy", "mapRain_extreme", "minimapRain"].each do |picture|
      assert_nil PokeAccess::IF2Weather.icon_words(PICTURES + picture), picture
    end
    assert_nil PokeAccess::IF2Weather.icon_words(nil), "no picture at all"
  end

  test "the entry icon's weather follows the place's name, both queued" do
    enter(35)
    $game_map.map_id = 40
    WeatherIcon.new(PICTURES + "mapFog_medium")
    PokeAccess::Locator.announce_map_change
    assert_equal [["Mapa 40", false], [t(:if2_wx_medium, :w => t(:w_fog)), false]], SpeakCapture.log
  end

  test "a place named again does not bring its weather back" do
    enter(35)
    $game_map.map_id = 40
    WeatherIcon.new(PICTURES + "mapFog_medium")
    PokeAccess::Locator.announce_map_change
    PokeAccess::Locator.forget_map
    SpeakCapture.clear
    PokeAccess::Locator.announce_map_change
    assert_equal [["Mapa 40", false]], SpeakCapture.log
  end

  test "on a map already named, the icon's weather is said at once, queued" do
    enter(35)
    WeatherIcon.new(PICTURES + "mapRain_light")
    assert_equal [[t(:if2_wx_light, :w => t(:w_rain)), false]], SpeakCapture.log
  end

  test "an icon that drew no picture says nothing, then or with the place's name" do
    enter(35)
    WeatherIcon.new(PICTURES + "mapRain_light", false)
    $game_map.map_id = 40
    WeatherIcon.new(PICTURES + "mapFog_medium", false)
    PokeAccess::Locator.announce_map_change
    assert_equal [["Mapa 40", false]], SpeakCapture.log
  end

  test "an icon whose picture is no weather says nothing" do
    enter(35)
    WeatherIcon.new(PICTURES + "cloud")
    assert_nothing_spoken
  end

  test "a map left before its name was said takes its weather with it, for good" do
    enter(35)
    $game_map.map_id = 40
    WeatherIcon.new(PICTURES + "mapRain_light")
    $game_map.map_id = 999
    PokeAccess::Locator.announce_map_change
    assert_equal [["Mapa 999", false]], SpeakCapture.log, "the next map named without it"
    SpeakCapture.clear
    $game_map.map_id = 40
    PokeAccess::Locator.announce_map_change
    assert_equal [["Mapa 40", false]], SpeakCapture.log, "and its own map named again without it"
  end

  test "the PokeRadar's weather is said once per picture, queued" do
    scene = PokeRadarAppScene.new(PICTURES + "mapStorm_heavy")
    scene.showWeatherIcon
    scene.showWeatherIcon
    assert_equal [[t(:if2_wx_heavy, :w => t(:w_storm)), false]], SpeakCapture.log
  end

  test "the PokeRadar says the weather again when its picture changes" do
    scene = PokeRadarAppScene.new(PICTURES + "mapStorm_heavy")
    scene.showWeatherIcon
    scene.path = PICTURES + "mapSun_light"
    scene.showWeatherIcon
    assert_equal [t(:if2_wx_heavy, :w => t(:w_storm)), t(:if2_wx_light, :w => t(:w_sun))], SpeakCapture.lines
  end

  test "a PokeRadar header showing no weather picture says nothing" do
    [nil, PICTURES + "cloud"].each { |picture| PokeRadarAppScene.new(picture).showWeatherIcon }
    assert_nothing_spoken
  end

  private

  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # Enters map id as the locator names it, the weather module keeping nothing from before, the speech log cleared.
  def enter(id)
    PokeAccess::IF2Weather.instance_variable_set(:@pending, nil)
    PokeAccess::IF2Weather.instance_variable_set(:@announced, nil)
    $game_map.map_id = id
    PokeAccess::Locator.announce_map_change
    SpeakCapture.clear
  end
end
