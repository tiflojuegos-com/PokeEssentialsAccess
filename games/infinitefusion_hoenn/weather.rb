# Hoenn's dynamic weather as its icons show it: the one that slides down beside the place's banner on entering a map
# or after sleeping outdoors (WeatherIcon), and the PokeRadar's, each a picture of the weather's kind and, for most
# kinds, of its strength.
module PokeAccess
  module IF2Weather
    # Each weather picture's kind, by its base name.
    KINDS = {
      "mapSun" => :w_sun, "mapRain" => :w_rain, "mapFog" => :w_fog, "mapWind" => :w_wind, "mapStorm" => :w_storm,
      "mapSand" => :w_sandstorm, "mapSnow" => :w_snow, "mapHeavyRain" => :w_heavy_rain,
      "mapStrongWinds" => :w_strong_winds, "mapHarshSun" => :w_harsh_sun, "mapAsh" => :w_ash
    }
    # The strength suffixes the pictures of the kinds that vary carry.
    LEVELS = { "light" => :if2_wx_light, "medium" => :if2_wx_medium, "heavy" => :if2_wx_heavy }
    ICON = /(?:\A|\/)(map[A-Za-z]+?)(?:_(light|medium|heavy))?\z/
    @pending = nil
    @announced = nil

    # The weather a weather picture shows, or nil for any other picture.
    def self.icon_words(path)
      m = ICON.match(path.to_s)
      kind = m ? KINDS[m[1]] : nil
      return nil unless kind
      w = PokeAccess::I18n.t(kind)
      m[2] ? PokeAccess::I18n.t(LEVELS[m[2]], :w => w) : w
    end

    # The map on screen as the locator tells maps apart: its id and the map object, which a load rebuilds.
    def self.current_map
      [($game_map.map_id rescue nil), ($game_map.__id__ rescue nil)]
    end

    # Notes the map whose name the locator is about to say.
    def self.announcing
      @announced = current_map
    end

    # An entry icon's weather: said at once, queued, when its map's name has been said already (after sleeping
    # outdoors), else kept for that name; nothing when the icon drew no picture.
    def self.entered(icon)
      return unless PokeAccess.ivar(icon, :@sprite)
      t = icon_words(PokeAccess.ivar(icon, :@icon_path))
      return unless t
      here = current_map
      return PokeAccess.speak(t, false) if @announced == here
      @pending = [here, t]
    end

    # After the locator's map line: says, queued, the weather kept for the map just named; one kept for another map
    # is dropped.
    def self.flush
      kept = @pending
      return unless kept
      return unless @announced == current_map
      @pending = nil
      PokeAccess.speak(kept[1], false) if kept[0] == @announced
    end

    # The PokeRadar's weather icon, said once per picture while the app is open.
    def self.radar(scene)
      icon = PokeAccess.sprite(scene, "weather")
      path = (icon.name rescue nil)
      t = icon_words(path)
      PokeAccess::Cursor.announce(scene, :if2_radar_weather, path, false) { t } if t
    end
  end
end

PokeAccess::Events.on(:map_changed) { |_mid| PokeAccess::IF2Weather.announcing }

PokeAccess::Game.define("infinitefusion_hoenn") do
  after("WeatherIcon", :initialize) { |icon, _r, _a| PokeAccess::IF2Weather.entered(icon) }
  override("PokeAccess::Locator", :announce_map_change) do |_mod, original, _args|
    r = original.call
    PokeAccess::IF2Weather.flush
    r
  end
  after("PokeRadarAppScene", :showWeatherIcon) { |s, _r, _a| PokeAccess::IF2Weather.radar(s) }
end
