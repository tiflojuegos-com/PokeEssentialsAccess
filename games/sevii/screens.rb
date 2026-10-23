module PokeAccess
  # Sevii's own paint over stock screens: the Pokegear's clock, the old Day-Care Checker of FL its Day-Care app opens,
  # and the back hint its region map backgrounds draw.
  module SeviiScreens
    # The clock a repaint drew, without its seconds ("03:27 PM"), or nil when it drew none.
    def self.time_text(pairs)
      t = PokeAccess.clean(PokeAccess::PaintCapture.laid_out(pairs).join(" "))
      t.empty? ? nil : t.sub(/(\d{1,2}:\d{2}):\d{2}/, '\1')
    end

    # A repaint of the Pokegear's clock (once a second): the time goes on the info key, and the first one a Pokegear
    # paints, as it opens, is said too, queued behind the focused option.
    def self.clock(scene, pairs)
      t = time_text(pairs)
      return unless t
      first = PokeAccess::Cursor.current(scene, :sv_clock).nil?
      PokeAccess::Cursor.changed?(scene, :sv_clock, t)
      PokeAccess::Info.set_info(:text, t)
      PokeAccess.speak(t, false) if first
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The Day-Care Checker as painted: each Pokemon's "Name Lv. N" with its sex sign, in screen order, then the egg
    # while its picture is up; or that the Day-Care holds no one.
    def self.daycare_text(scene, pairs)
      parts = PokeAccess::PaintCapture.laid_out(pairs).map { |raw| PokeAccess.clean(raw) }.reject { |t| t.empty? }
      parts.push(PokeAccess::I18n.t(:dcheck_egg)) if PokeAccess.sprite(scene, "egg")
      parts.empty? ? PokeAccess::I18n.t(:dcheck_empty) : PokeAccess.sentences(parts)
    end

    # Says the Day-Care Checker as it opens, queued behind the fade, and keeps it on the info key until it closes.
    def self.daycare_opened(scene, pairs)
      t = daycare_text(scene, pairs)
      PokeAccess::Info.set_info(:text, t)
      PokeAccess.speak(t, false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The back hint the region map backgrounds draw ("X BACK"), with the key the B button is on now.
    def self.map_back_hint
      PokeAccess::I18n.t(:sv_map_back, :key => PokeAccess::KeyHints.key(:b, "X"))
    end
  end
end

PokeAccess::Game.define("sevii") do
  # updateDateIfNecessary runs from main and on every frame, and answers true when it repainted the clock.
  around("Scene_Pokegear", :updateDateIfNecessary) do |scene, nxt, _a|
    r = nil
    pairs = PokeAccess::PaintCapture.sample { r = nxt.call }
    PokeAccess::SeviiScreens.clock(scene, pairs) if r
    r
  end

  # startScene paints the whole screen, then fades it in; the egg is a picture with no text.
  around("DayCareCheckerScene", :startScene) do |scene, nxt, _a|
    r = nil
    pairs = PokeAccess::PaintCapture.sample { r = nxt.call }
    PokeAccess::SeviiScreens.daycare_opened(scene, pairs)
    r
  end
  before("DayCareCheckerScene", :endScene) { |_s, _a| PokeAccess::Info.clear_text }

  # The map's loop starts once its opening reads are queued: the hint goes after them, while key hints are said.
  before("PokemonRegionMapScene", :pbMapScene) do |_s, _a|
    PokeAccess.speak(PokeAccess::SeviiScreens.map_back_hint, false) if PokeAccess::Verbosity.hints?
  end
end
