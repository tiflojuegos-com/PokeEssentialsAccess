# Anil's punch bag (FL's Punch Bag Game, rewritten inside Anil's Misc Scripts for proportional EV training): a tick
# whose pitch rises as the swinging arrow nears the bar's centre, where a hit scores most, and after each hit the
# stars it earned with the score window as painted. Its loop is held by an around-hook and read per frame.
module PokeAccess
  module AnilPunchBag
    @scene = nil

    # Holds the game while its loop runs, saying the score window it opens with.
    def self.hold(scene)
      @scene = scene
      t = score(scene)
      PokeAccess.speak(t, false) unless t.empty?
    end

    def self.release; @scene = nil; end

    # The score window's text as painted ("Puntos: 12 Golpe: 3/10"), cleaned.
    def self.score(scene)
      box = PokeAccess.sprite(scene, "scorebox")
      PokeAccess.clean((box.text rescue "").to_s)
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
      return if PokeAccess.ivar(s, :@pa_arrow_x) == x.round
      s.instance_variable_set(:@pa_arrow_x, x.round)
      half = (PokeAccess.const_at("PunchBag::Scene::BAR_LEFT_SIZE") || 128).to_f
      PokeAccess::Spatial.gauge(1.0 - ((x - mid).abs / half))
    rescue StandardError
      nil
    end

    # After a hit: the stars it earned, then the score window as it now reads.
    def self.hit(scene, stars)
      PokeAccess.speak(PokeAccess.sentences([PokeAccess::I18n.t(:stars_count, :n => stars.to_i), score(scene)]), true)
    end
  end
end

PokeAccess::Game.define("anil") do
  around("PunchBag::Scene", :pbMain, :optional => true) do |scene, nxt, _a|
    PokeAccess::AnilPunchBag.hold(scene)
    begin
      nxt.call
    ensure
      PokeAccess::AnilPunchBag.release
    end
  end
  after("PunchBag::Scene", :pbDrawStars, :optional => true) { |scene, _r, args| PokeAccess::AnilPunchBag.hit(scene, args[0]) }
  poll_each_frame { PokeAccess::AnilPunchBag.poll }
end
