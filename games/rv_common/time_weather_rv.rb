module PokeAccess
  # The Time & Weather app of the engine Reborn, Rejuvenation and Desolation share (Scene_TimeWeather): the time, the
  # date, the place and when the weather changes are painted, the weather now and next only as pictures. It opens
  # saying all of it, and the frame the arrows move says the part it lands on.
  module TimeWeatherRV
    # What pbTimeText last painted on the scene, in reading order: time, date, place, then the weather row (the
    # change time, which Rejuvenation paints after a "current weather" label).
    def self.rows(scene)
      PokeAccess.ivar(scene, :@access_tw_rows) || []
    end

    # Keeps what pbTimeText painted; the first paint of a scene says the whole screen.
    def self.painted(scene, pairs)
      first = PokeAccess.ivar(scene, :@access_tw_rows).nil?
      rows = PokeAccess::PaintCapture.laid_out(pairs).map { |t| PokeAccess.clean(t) }.reject { |t| t.empty? }
      scene.instance_variable_set(:@access_tw_rows, rows)
      PokeAccess.speak(summary(scene), true) if first
    end

    # The whole screen: its title, the time, the date, the place and both weathers.
    def self.summary(scene)
      head = (PokeAccess.sprite(scene, "header").text rescue nil)
      PokeAccess.sentences([head].concat(rows(scene)[0, 3]).push(part(scene, 2), part(scene, 3)))
    end

    # The part the selection frame is on: 1 the time, 2 the weather now, 3 the next one and when it comes.
    def self.part(scene, sel)
      case sel
      when 1 then rows(scene)[0]
      when 2 then PokeAccess::I18n.t(:rv_tw_now, :w => PokeAccess.ivar(scene, :@weatherType))
      when 3
        at = (rows(scene)[3..-1] || []).map { |r| r[/\d{1,2}:\d{2}/] }.compact.last
        PokeAccess::I18n.t(:rv_tw_next, :at => at.to_s, :w => PokeAccess.ivar(scene, :@nextWeatherType))
      end
    end

    # Hooks the paint of the app and its frame.
    def self.bind
      PokeAccess::Hooks.around_hook("Scene_TimeWeather", :pbTimeText, :optional => true) do |scene, nxt, _a|
        r = nil
        pairs = PokeAccess::PaintCapture.sample { r = nxt.call }
        PokeAccess::TimeWeatherRV.painted(scene, pairs)
        r
      end
      PokeAccess::Hooks.after_hook("Scene_TimeWeather", :update, :hook_container => true, :optional => true) do |scene, _r, _a|
        sel = PokeAccess.ivar(scene, :@selection)
        if sel.is_a?(Integer) && sel > 0
          PokeAccess::Cursor.announce(scene, :rv_tw_frame, sel) { PokeAccess::TimeWeatherRV.part(scene, sel) }
        end
      end
    end
  end
end

PokeAccess::TimeWeatherRV.bind if PokeAccess::DataRV.engine?
