# FL's Ball Catch Game (BallCatch::Scene, read ahead of any game that ships it): the score as painted, a tick for each
# step of the catcher, a tone for the lowest ball still to catch and a word for each ball that gets past.
module PokeAccess
  module FLBallCatch
    # Seconds between the falling ball's tones, and between the score's readings.
    GAP = 0.12
    SCORE_GAP = 1.5

    # The pre-panned files of the ball's tone and of the catcher's step, by side.
    GUIDE = { :left => "pa_guide_l", :center => "pa_guide_c", :right => "pa_guide_r" }
    STEP = { :left => "pa_ledge_l", :center => "pa_ledge_c", :right => "pa_ledge_r" }

    # The side a ball falls on by how its column compares with the catcher's.
    SIDES = { -1 => :left, 0 => :center, 1 => :right }

    # The catcher's step is pitched from STEP_LOW up by STEP_SPAN across the columns.
    STEP_LOW = 70
    STEP_SPAN = 80

    # The most ball sprites the reader walks.
    LIMIT = 100

    # What the reader keeps on the scene: the score and its text, when it was last said and whether one is owed, the
    # catcher's column, the ball and clock of the last tone, and the balls already said to have got past.
    Run = Struct.new(:score, :score_text, :spoke_at, :owed, :column, :key, :tone_at, :missed)

    # What the reader keeps on a scene.
    def self.state(scene)
      PokeAccess.ivar(scene, :@access_catch) || scene.instance_variable_set(:@access_catch, Run.new)
    end

    # What pbDrawText painted, as the game words it ("Score: 3/50").
    # param rows the painted rows as PaintCapture.sample gives them
    def self.painted(rows)
      PokeAccess.sentences(rows.map { |r| PokeAccess.clean(r[0]) })
    end

    # Says the opening, queued: the score as painted and, with hints, how the sounds guide the catcher.
    # param rows what pbStartScene painted
    def self.opened(scene, rows)
      run = state(scene)
      run.score = PokeAccess.ivar(scene, :@score).to_i
      run.score_text = painted(rows)
      PokeAccess::Info.set_info(:text, run.score_text) unless run.score_text.empty?
      hint = PokeAccess::Verbosity.hints? ? PokeAccess::I18n.t(:bcatch_hint) : nil
      PokeAccess.speak(PokeAccess.sentences([run.score_text, hint]), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The balls on show as [sprite number, x, y]; the game reuses its sprites, so a number names a ball while it falls.
    def self.balls(scene)
      out = []
      i = 0
      while i < LIMIT && (sprite = PokeAccess.sprite(scene, "ball#{i}"))
        out.push([i, sprite.x, sprite.y]) if sprite.visible
        i += 1
      end
      out
    rescue StandardError => e
      PokeAccess.swallowed(e)
      []
    end

    # The column a ball falls in, from its x and the game's spacing of the columns.
    def self.column_of(scene, x)
      ((x - scene.class::X_START).to_f / scene.class::X_GAIN).round
    end

    # The lowest a ball can be and still be caught: the catcher's own height.
    def self.floor_of(player)
      player.y + player.bitmap.height
    end

    # The lowest ball not yet past the catcher, or nil.
    def self.lowest(after, player)
      floor = floor_of(player)
      after.select { |b| b[2] <= floor }.max_by { |b| b[2] }
    end

    # How near the floor a ball is, 0.0 as it appears to 1.0 at the catcher.
    def self.depth(scene, y, player)
      top = scene.class::Y_START
      [[(y - top).to_f / (player.y - top), 0.0].max, 1.0].min
    end

    # Plays a pre-panned file at a pitch and the minigame's volume.
    def self.play(file, pitch)
      PokeAccess::Sound::Flat.play(file, PokeAccess::Sound::Mixer.volume(:minigame), pitch)
    end

    # One frame of the loop, after the balls moved: what was caught or got past, the catcher's step, the ball's tone and
    # the score owed.
    # param rows what the frame painted
    def self.frame(scene, rows)
      run = state(scene)
      now = PokeAccess.clock
      after = balls(scene)
      settle(scene, run, after, rows)
      step(scene, run)
      guide(scene, run, after, now)
      flush(run, now)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Takes what this frame settled: a score the catch raised, and the balls that have got past the catcher.
    def self.settle(scene, run, after, rows)
      score = PokeAccess.ivar(scene, :@score).to_i
      note_caught(run, rows) if score > (run.score || score)
      run.score = score
      note_missed(scene, run, after)
    end

    # Keeps the score a catch painted for the info key and owes it to the speech.
    def self.note_caught(run, rows)
      text = painted(rows)
      return if text.empty?
      run.score_text = text
      run.owed = true
      PokeAccess::Info.set_info(:text, text)
    end

    # Says a word, cutting in, when a ball has got past the catcher; each ball once, however long it takes to leave.
    def self.note_missed(scene, run, after)
      player = PokeAccess.sprite(scene, "player")
      return unless player
      floor = floor_of(player)
      past = after.select { |b| b[2] > floor }.map { |b| b[0] }
      known = run.missed || []
      PokeAccess.speak(PokeAccess::I18n.t(:bcatch_lost), true) if past.any? { |i| !known.include?(i) }
      run.missed = past
    end

    # The catcher's tick when it moved a column: from the side of the board it stands on, higher the further right.
    def self.step(scene, run)
      column = PokeAccess.ivar(scene, :@playerColumn)
      was = run.column
      run.column = column
      return unless was && column && was != column
      last = PokeAccess.ivar(scene, :@params).columns.to_i - 1
      mid = last / 2.0
      side = column < mid ? :left : (column > mid ? :right : :center)
      play(STEP[side], STEP_LOW + (column * STEP_SPAN) / last)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The tone of the lowest ball the catcher can still reach, from the side it falls on and higher the nearer the floor;
    # at once when the side or the ball changes, else every GAP seconds.
    def self.guide(scene, run, after, now)
      player = PokeAccess.sprite(scene, "player")
      column = PokeAccess.ivar(scene, :@playerColumn)
      ball = player && column ? lowest(after, player) : nil
      unless ball
        run.key = nil
        return
      end
      side = SIDES[column_of(scene, ball[1]) <=> column]
      key = [ball[0], side]
      return unless key != run.key || run.tone_at.nil? || now - run.tone_at >= GAP
      run.key = key
      run.tone_at = now
      near = depth(scene, ball[2], player)
      play(GUIDE[side], PokeAccess::Sound::GAUGE_LOW + (near * PokeAccess::Sound::GAUGE_SPAN).to_i)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Says the score a catch left, at most every SCORE_GAP seconds, so a run of catches does not pile up speech.
    def self.flush(run, now)
      return unless run.owed && (run.spoke_at.nil? || now - run.spoke_at >= SCORE_GAP)
      run.owed = false
      run.spoke_at = now
      PokeAccess.speak(run.score_text, true)
    end

    # The loop's end: the final score as painted, queued after the game's own message, and the info line gone.
    def self.finished(scene)
      text = state(scene).score_text
      PokeAccess.speak(text, false) unless text.nil? || text.empty?
      PokeAccess::Info.clear_text
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Hooks.around_hook("BallCatch::Scene", :pbStartScene, :optional => true) do |scene, nxt, _a|
  r = nil
  rows = PokeAccess::PaintCapture.sample { r = nxt.call }
  PokeAccess::FLBallCatch.opened(scene, rows)
  r
end
PokeAccess::Hooks.around_hook("BallCatch::Scene", :applyCollisions, :optional => true) do |scene, nxt, _a|
  r = nil
  rows = PokeAccess::PaintCapture.sample { r = nxt.call }
  PokeAccess::FLBallCatch.frame(scene, rows)
  r
end
PokeAccess::Hooks.before_hook("BallCatch::Scene", :pbEndScene, :optional => true) do |scene, _a|
  PokeAccess::FLBallCatch.finished(scene)
end
