# The fishing minigame (FishingMinigame, FishingRing, LifeBar): a ring shrinks over a painted band and the action key
# strikes as it crosses it. Everything is drawn, so a chime tells when to strike, and each ring's end says the two life
# bars and the combo. The press is judged by the ring's size, so the chime sounds ahead of the middle of the best band.
module PokeAccess
  module ClaraFishing
    # Seconds before the ring reaches the middle of the best band that its chime sounds.
    CUE_LEAD = 0.2
    # The ring's size at the middle of that band, should the game's RADIUS_MAX_PERFECT be missing.
    BEST_SIZE = 240

    @game = nil

    def self.hold(game); @game = game; end

    # The game's loop over: nothing to chime, and the bars leave the info key.
    def self.release
      @game = nil
      PokeAccess::Info.clear_text
    end

    # As the game's graphics are built: what it is and the key, queued; the info key holds the bars.
    def self.opened(game)
      PokeAccess::Info.set_info(:text, bars(game))
      hint = PokeAccess::I18n.t(:clara_fish_hint, :key => PokeAccess::KeyHints.key(:c, "C"))
      PokeAccess.speak(PokeAccess::Verbosity.with_hint(PokeAccess::I18n.t(:clara_fish_title), hint), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Each frame of the game: the chime of the ring in play, once per ring.
    def self.poll
      ring = @game && PokeAccess.ivar(@game, :@ring)
      return if ring.nil? || ring.instance_variable_get(:@access_cued) || !due?(ring)
      ring.instance_variable_set(:@access_cued, true)
      cue
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Whether the ring is within CUE_LEAD seconds of the band's middle: its size falls by its speed (a zoom a frame)
    # times its picture's width each frame.
    def self.due?(ring)
      pic = PokeAccess.ivar(ring, :@sprite)
      width = pic.bitmap.width
      best = PokeAccess.const_at("RADIUS_MAX_PERFECT") || BEST_SIZE
      width * pic.zoom_x - best <= CUE_LEAD * Graphics.frame_rate * ring.speed * width
    end

    # The guide's flat chime at the minigames' volume; the word, cutting in, with those sounds off.
    def self.cue
      vol = PokeAccess::Sound::Mixer.volume(:minigame)
      return PokeAccess.speak(PokeAccess::I18n.t(:clara_fish_now), true) unless vol && vol > 0
      PokeAccess::Sound.flat(PokeAccess::Sound::Catalog.entry(:guide), 8, vol)
    end

    # A ring over: the two bars and the combo, cutting in, and the info key holds them.
    def self.scored(game)
      line = bars(game)
      PokeAccess::Info.set_info(:text, line)
      PokeAccess.speak(line, true)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The foe's bar and the player's, each by the name it paints, then the combo the game paints, from one on.
    def self.bars(game)
      parts = %w[enemyBar playerBar].map { |key| bar(PokeAccess.sprite(game, key)) }.compact
      combo = PokeAccess.ivar_i(game, :@combo)
      parts.push(PokeAccess::I18n.t(:clara_fish_combo, :n => combo)) if combo > 0
      parts.join(", ")
    end

    # A life bar, which paints only its name and a gauge, as its name and what is left of it.
    def self.bar(life_bar)
      return nil if life_bar.nil?
      left = [life_bar.life.to_i, 0].max
      PokeAccess::I18n.t(:clara_fish_bar, :name => PokeAccess.clean(PokeAccess.ivar(life_bar, :@name).to_s), :n => left,
                         :max => life_bar.maxLife.to_i)
    end
  end
end

PokeAccess::Game.define("clara_common") do
  after("FishingMinigame", :createGraphics, :optional => true) { |game, _r, _a| PokeAccess::ClaraFishing.opened(game) }
  after("FishingMinigame", :refresh, :optional => true) { |game, _r, _a| PokeAccess::ClaraFishing.scored(game) }
  around("FishingMinigame", :update, :optional => true) do |game, nxt, _a|
    PokeAccess::ClaraFishing.hold(game)
    begin
      nxt.call
    ensure
      PokeAccess::ClaraFishing.release
    end
  end
  poll_each_frame { PokeAccess::ClaraFishing.poll }
end
