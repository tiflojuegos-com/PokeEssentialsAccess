# Royal's jump-rope minigame on route 6 (JumpMinigame::Play, bo4p5687's "Minigame Jump"). The rope is only drawn, so
# a tick marks the time to jump: the earliest frame from which a jump is still in the air when the rope passes under
# the Pokemon (the end of phase 2, where the game counts it), so a jump on the tick, or a reaction up to the Pokemon's
# time in the air later, clears it. The jump counter, "faster" and the end are said as painted.
module PokeAccess
  module RoyalJumpRope
    # Pixels pkmnJump moves the Pokemon each frame, up and down.
    JUMP_STEP = 5

    # Frames a jump keeps the game's @jump on, from the one it is pressed to the one it lands: pkmnJump raises the
    # sprite from the ground (@storeH) until its first opaque row passes the rope's top (YRopeT), then drops it back.
    # A sprite taller than that gap never leaves the ground (1). Worked out once per game.
    def self.airtime(play)
      cached = PokeAccess.ivar(play, :@pa_airtime)
      return cached if cached
      gap = PokeAccess.ivar(play, :@storeH).to_i -
            (JumpMinigame::Play::YRopeT - play.hPkmn(PokeAccess.ivar(play, :@storeBm)).to_i)
      n = gap < 0 ? 1 : (2 * (gap / JUMP_STEP)) + 2
      play.instance_variable_set(:@pa_airtime, n)
      n
    end

    # Frames until the rope passes under the Pokemon from the state drawRope left: each phase moves @storeMove by
    # @comba_vel per frame, 0 up to @top behind (0), back to 0 in front (1), 0 down to @bot in front (2, which ends
    # in the pass) and back behind (3). Nil without a speed.
    def self.frames_to_pass(play)
      rot = PokeAccess.ivar(play, :@rot)
      move = PokeAccess.ivar(play, :@storeMove).to_i
      vel = PokeAccess.ivar(play, :@comba_vel).to_i
      top = PokeAccess.ivar(play, :@top).to_i
      bot = PokeAccess.ivar(play, :@bot).to_i
      return nil if vel <= 0 || !rot.is_a?(Integer)
      lower = (bot / vel) + 1
      upper = (top / vel) + 1
      case rot
      when 2 then ((bot - move) / vel) + 1
      when 1 then (move / vel) + 1 + lower
      when 0 then ((top - move) / vel) + 1 + upper + lower
      else (move / vel) + 1 + upper + upper + lower
      end
    end

    # After each rope frame: the tick once per pass, when the pass is no more frames away than the Pokemon stays in
    # the air, so the input read on the next frame is the first whose jump clears it; a pass (phase 2 turning into 3)
    # makes way for the next one's tick. Nothing once the game is over.
    def self.rope(play)
      return if PokeAccess.ivar(play, :@over)
      rot = PokeAccess.ivar(play, :@rot)
      play.instance_variable_set(:@pa_rope_cued, false) if rot == 3 && PokeAccess.ivar(play, :@pa_rope_rot) == 2
      play.instance_variable_set(:@pa_rope_rot, rot)
      return if PokeAccess.ivar(play, :@pa_rope_cued)
      left = frames_to_pass(play)
      return if left.nil? || left > airtime(play)
      play.instance_variable_set(:@pa_rope_cued, true)
      PokeAccess::Spatial.gauge(1.0)
    rescue StandardError
      nil
    end

    # The counter as drawPoints paints it ("3 saltos"), through the game's _INTL as the build translates it.
    def self.count_text(n)
      "#{n} #{_INTL(n == 1 ? "salto" : "saltos")}"
    end

    # Whether drawPoints paints "faster" for a count: every 5 jumps up to 10, then every 10.
    def self.faster?(n)
      n > 0 && ((n % 5 == 0 && n < 10) || n % 10 == 0)
    end

    # After each points frame: the counter when it moved, with "faster" when the game paints it.
    def self.points(play)
      n = PokeAccess.ivar(play, :@timesJ).to_i
      return if n == PokeAccess.ivar(play, :@pa_jumps).to_i || PokeAccess.ivar(play, :@over)
      play.instance_variable_set(:@pa_jumps, n)
      parts = [count_text(n)]
      parts.push(_INTL("¡Más rápido!")) if faster?(n)
      PokeAccess.speak_clean(PokeAccess.sentences(parts), true)
    rescue StandardError
      nil
    end

    # The end as checkOver paints it, "¡Se acabó!" over the final count, said as it starts.
    def self.over(play)
      return unless PokeAccess.ivar(play, :@over)
      n = PokeAccess.ivar(play, :@timesJ).to_i
      PokeAccess.speak_clean(PokeAccess.sentences([_INTL("¡Se acabó!"), count_text(n)]), true)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("royal") do
  after("JumpMinigame::Play", :drawRope, :optional => true) { |play, _r, _a| PokeAccess::RoyalJumpRope.rope(play) }
  after("JumpMinigame::Play", :drawPoints, :optional => true) { |play, _r, _a| PokeAccess::RoyalJumpRope.points(play) }
  before("JumpMinigame::Play", :checkOver, :optional => true) { |play, _a| PokeAccess::RoyalJumpRope.over(play) }
end
