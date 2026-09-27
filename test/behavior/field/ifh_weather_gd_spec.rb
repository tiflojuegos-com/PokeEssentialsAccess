# Infinite Fusion Hoenn's weather icons, gamedata pass: the one that slides down on entering a map is said after
# the place's name, and the PokeRadar's once per picture. The stand-ins keep the icon's own fields (@icon_path, and
# @sprite only when it drew one) and come before the profile file loads.
class WeatherIcon
  def initialize(path, drawn = true)
    @icon_path = path
    @sprite = drawn ? Object.new : nil
  end
end

# The radar is a PokeNav app, as the screens spec declares it too (one hierarchy for both files).
class PokeNavAppScene; end

class PokeRadarAppScene < PokeNavAppScene
  def initialize(path = nil); @sprites = {}; @path = path; end
  def showWeatherIcon; @sprites["weather"] = Struct.new(:name).new(@path); end
end

load File.expand_path("../../../games/infinitefusion_hoenn/weather.rb", File.dirname(__FILE__))

Suite.define("ifh weather: an icon's picture names the weather and, for the kinds that vary, its strength") do
  t = PokeAccess::I18n
  w = PokeAccess::IF2Weather
  eq "a light rain", w.icon_words("Graphics/Pictures/Weather/mapRain_light"),
     t.t(:if2_wx_light, :w => t.t(:w_rain))
  eq "a strong sun", w.icon_words("Graphics/Pictures/Weather/mapSun_heavy"), t.t(:if2_wx_heavy, :w => t.t(:w_sun))
  eq "a kind drawn at one strength only", w.icon_words("Graphics/Pictures/Weather/mapSand"), t.t(:w_sandstorm)
  eq "and any other picture is no weather", w.icon_words("Graphics/Pictures/Weather/cloud"), nil
end

# A map transfer loads the new map and builds the entry icon before the locator's next frame says the map's name.
Suite.define("ifh weather: the entry icon's weather follows the place's name") do
  t = PokeAccess::I18n
  fog = t.t(:if2_wx_medium, :w => t.t(:w_fog))
  $game_map.map_id = 35
  PokeAccess::Locator.announce_map_change
  $game_map.map_id = 40
  WeatherIcon.new("Graphics/Pictures/Weather/mapFog_medium")
  SpeakCapture.clear
  PokeAccess::Locator.announce_map_change
  eq "the place, then its weather, both queued", SpeakCapture.log,
     [[PokeAccess::Locator.map_name(40), false], [fog, false]]
  SpeakCapture.clear
  PokeAccess::Locator.announce_map_change
  silent "and the weather is said once"
  WeatherIcon.new("Graphics/Pictures/Weather/mapFog_medium", false)
  PokeAccess::Locator.announce_map_change
  silent "an icon with no picture drawn says nothing"
end

Suite.define("ifh weather: an icon on a map already named is said at once, one kept for another map never") do
  t = PokeAccess::I18n
  rain = t.t(:if2_wx_light, :w => t.t(:w_rain))
  $game_map.map_id = 35
  PokeAccess::Locator.announce_map_change
  SpeakCapture.clear
  WeatherIcon.new("Graphics/Pictures/Weather/mapRain_light")
  eq "after sleeping outdoors, the weather right away, queued", SpeakCapture.log, [[rain, false]]
  $game_map.map_id = 40
  WeatherIcon.new("Graphics/Pictures/Weather/mapRain_light")
  $game_map.map_id = 999
  SpeakCapture.clear
  PokeAccess::Locator.announce_map_change
  eq "a map left before its name was said takes its weather with it", SpeakCapture.log,
     [[PokeAccess::Locator.map_name(999), false]]
  $game_map.map_id = 40
  SpeakCapture.clear
  PokeAccess::Locator.announce_map_change
  eq "and does not bring it back", SpeakCapture.log, [[PokeAccess::Locator.map_name(40), false]]
end

Suite.define("ifh weather: the PokeRadar's weather icon is said once per picture") do
  t = PokeAccess::I18n
  scene = PokeRadarAppScene.new("Graphics/Pictures/Weather/mapStorm_heavy")
  SpeakCapture.clear
  scene.showWeatherIcon
  scene.showWeatherIcon
  eq "queued after the header, and not again on the header's repaints", SpeakCapture.log,
     [[t.t(:if2_wx_heavy, :w => t.t(:w_storm)), false]]
end
