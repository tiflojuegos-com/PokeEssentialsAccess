# FL's Punch Bag Game (PunchBagScene; Uranium's EV training dojos): the score window as it is written, each hit's
# stars, and a tick per step of the arrow whose pitch peaks at the bar's centre, where a hit scores most.
module PokeAccess
  module PunchBag
    @scene = nil

    # Runs the game loop with its scene held for the per-frame tick.
    def self.playing(scene)
      prev = @scene
      @scene = scene
      yield
    ensure
      @scene = prev
    end

    # The score window's text as written ("Score: 7 Hits: 2/10"), its lines as sentences.
    def self.score(scene)
      box = PokeAccess.sprite(scene, "scorebox")
      raw = box ? (box.text rescue "").to_s : ""
      PokeAccess.sentences(raw.split(/\r?\n/).map { |l| PokeAccess.clean(l) })
    end

    # The opening read: the score window and, while key hints are said, how the tick guides the hit.
    def self.opened(scene)
      hint = PokeAccess::I18n.t(:pbag_hint, :key => PokeAccess::KeyHints.key(:c, PokeAccess::I18n.t(:key_enter)))
      PokeAccess.sentences(PokeAccess::Verbosity.hints? ? [score(scene), hint] : [score(scene)])
    end

    # After a hit is scored: the stars it earned (the ones left lit), then the score window, interrupting.
    def self.scored(scene)
      stars = (0...5).count { |i| (PokeAccess.sprite(scene, "star#{i}").visible rescue false) }
      PokeAccess.speak(PokeAccess.sentences([PokeAccess::I18n.t(:pbag_stars, :n => stars), score(scene)]), true)
    end

    # Each frame of the loop: a tick when the arrow has moved while it is on show, its pitch by how near the bar's
    # centre it stands (the scoring distance).
    def self.poll
      s = @scene
      return unless s
      arrow = PokeAccess.sprite(s, "arrow")
      return unless arrow && (arrow.visible rescue false)
      x = (arrow.x rescue nil)
      return if x.nil? || PokeAccess.ivar(s, :@access_pbag_x) == x
      s.instance_variable_set(:@access_pbag_x, x)
      mid = PokeAccess.ivar(s, :@arrowXMiddle)
      span = (PokeAccess.const_at("PunchBagScene::BARLEFTSIZE") || 128).to_f
      return if mid.nil? || span <= 0
      PokeAccess::Spatial.gauge(1.0 - ((x - mid).abs / span))
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.read_on_open("PunchBagScene", :pbStartScene, :optional => true) do |scene|
  PokeAccess::PunchBag.opened(scene)
end
PokeAccess::Hooks.around_hook("PunchBagScene", :pbMain, :optional => true) do |scene, nxt, _a|
  PokeAccess::PunchBag.playing(scene) { nxt.call }
end
PokeAccess::Hooks.after_hook("PunchBagScene", :computeScore, :optional => true) do |scene, _r, _a|
  PokeAccess::PunchBag.scored(scene)
end
PokeAccess::Keys.on_frame { PokeAccess::PunchBag.poll }
