# FL's Punch Bag Game from 1.2 on (PunchBag::Scene, opened by PunchBag.play; punch_bag.rb reads the older PunchBagScene):
# a tick per step of the arrow whose pitch peaks at the bar's centre, where a hit scores most; each hit's stars and the
# score window as it is written.
module PokeAccess
  module PunchBagV12
    @scene = nil

    # The score window's text as written ("Score: 7 Hits: 2/10"), its lines as sentences.
    def self.score(scene)
      box = PokeAccess.sprite(scene, "scorebox")
      raw = box ? (box.text rescue "").to_s : ""
      PokeAccess.sentences(raw.split(/\r?\n/).map { |l| PokeAccess.clean(l) })
    end

    # Holds the game while its loop runs (the block), with the score window it opens with and how the tick guides a hit.
    def self.playing(scene)
      @scene = scene
      hint = PokeAccess::I18n.t(:pbag_hint, :key => PokeAccess::KeyHints.key(:c, PokeAccess::I18n.t(:key_enter)))
      line = PokeAccess::Verbosity.hints? ? PokeAccess.sentences([score(scene), hint]) : score(scene)
      PokeAccess::Info.set_info(:text, score(scene), score(scene))
      PokeAccess.speak(line, false)
      yield
    ensure
      @scene = nil
    end

    # After a hit: the stars it earned, then the score window as it now reads.
    def self.hit(scene, stars)
      PokeAccess::Info.set_info(:text, score(scene), score(scene))
      PokeAccess.speak(PokeAccess.sentences([PokeAccess::I18n.t(:pbag_stars, :n => stars.to_i), score(scene)]), true)
    end

    # Per frame: a tick each time the shown arrow moves, 1.0 on the centre and 0.0 at either end of the bar.
    def self.poll
      s = @scene
      return unless s
      arrow = PokeAccess.sprite(s, "arrow")
      return unless arrow && (arrow.visible rescue false)
      x = PokeAccess.ivar(s, :@arrowX)
      mid = PokeAccess.ivar(s, :@arrowXMiddle)
      return unless x.is_a?(Numeric) && mid.is_a?(Numeric)
      return if PokeAccess.ivar(s, :@access_pbag_x) == x.round
      s.instance_variable_set(:@access_pbag_x, x.round)
      half = (PokeAccess.const_at("PunchBag::Scene::BAR_LEFT_SIZE") || 128).to_f
      PokeAccess::Sound.gauge(1.0 - ((x - mid).abs / half))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Hooks.around_hook("PunchBag::Scene", :pbMain, :optional => true) do |scene, nxt, _a|
  PokeAccess::PunchBagV12.playing(scene) { nxt.call }
end
PokeAccess::Hooks.after_hook("PunchBag::Scene", :pbDrawStars, :optional => true) do |scene, _r, args|
  PokeAccess::PunchBagV12.hit(scene, args[0])
end
PokeAccess::Frame.each_pulse { PokeAccess::PunchBagV12.poll }
PokeAccess::Hooks.clear_info_on("PunchBag::Scene", :pbEndScene)
