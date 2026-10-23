# FL's Ball Catch Game (plugins/fl_ball_catch.rb) over a stand-in of its scene: the score as painted on opening and as
# catches change it, the catcher's tick as it steps, the tone of the lowest ball still to catch by its side and its
# height, a word for each ball that gets past and the final score.
module FlCatchSpec
  Bitmap = Struct.new(:width, :height)
  Sprite = Struct.new(:x, :y, :visible, :bitmap)
  Params = Struct.new(:columns, :balls)

  # The game's scene as the reader asks it: its sprites, the catcher's column, the score and the paint of the score.
  class Scene
    X_START = 56
    X_GAIN = 64
    Y_START = -40

    attr_accessor :score

    def initialize(columns = 7)
      @params = Params.new(columns, 50)
      @score = 0
      @playerColumn = columns / 2
      @sprites = { "player" => Sprite.new(0, 318, true, Bitmap.new(80, 44)) }
    end

    def column=(column); @playerColumn = column; end

    def ball(n); @sprites["ball#{n}"]; end

    def drop(n, column, y)
      @sprites["ball#{n}"] = Sprite.new(X_START + X_GAIN * column, y, true, Bitmap.new(20, 20))
    end

    def catch!(n)
      ball(n).visible = false
      @score += 1
      pbDrawText
    end

    def hide!(n); ball(n).visible = false; end

    def pbDrawText
      pbDrawTextPositions(nil, [["Score: #{@score}/50", 8, 14, false, nil, nil]])
    end
  end
end

class FlBallCatchTest < PokeAccessTest
  test "the opening says the score as painted and how the sounds guide the catcher, queued" do
    opening(FlCatchSpec::Scene.new)
    assert_equal [[PokeAccess.sentences(["Score: 0/50", t(:bcatch_hint)]), false]], SpeakCapture.log
  end

  test "without key hints the opening says the score alone" do
    PokeAccess::Config.verbosity = :brief
    opening(FlCatchSpec::Scene.new)
    assert_equal [["Score: 0/50", false]], SpeakCapture.log
  end

  test "the info key holds the score from the opening" do
    opening(FlCatchSpec::Scene.new)
    assert_equal "Score: 0/50", PokeAccess::Info.info_text
  end

  test "a scene it cannot read opens on how the sounds guide alone" do
    PokeAccess::FLBallCatch.opened(Object.new, [])
    assert_equal [[t(:bcatch_hint), false]], SpeakCapture.log
  end

  test "the catcher ticks when it steps, from the side of the board it stands on and higher the further right" do
    scene = started
    steps = [[2, "pa_ledge_l", 96], [1, "pa_ledge_l", 83], [0, "pa_ledge_l", 70], [1, "pa_ledge_l", 83],
             [2, "pa_ledge_l", 96], [3, "pa_ledge_c", 110], [4, "pa_ledge_r", 123], [5, "pa_ledge_r", 136],
             [6, "pa_ledge_r", 150]]
    got = steps.map do |column, _file, _pitch|
      sounds { scene.column = column; frame(scene) }.map { |file, _vol, pitch| [column, file, pitch] }[0]
    end
    assert_equal steps, got
  end

  test "a board of an even number of columns has no middle one to tick from" do
    scene = started(6)
    files = [2, 3].map { |column| sounds { scene.column = column; frame(scene) }[0][0] }
    assert_equal ["pa_ledge_l", "pa_ledge_r"], files
  end

  test "a board of two columns ticks its two ends, the lowest and the highest pitch" do
    scene = started(2)
    got = [0, 1].map { |column| sounds { scene.column = column; frame(scene) }[0] }
    assert_equal [["pa_ledge_l", 60, 70], ["pa_ledge_r", 60, 150]], got
  end

  test "the catcher is silent while it stays on its column" do
    scene = started
    assert_equal [], sounds { 3.times { frame(scene) } }
  end

  test "the catcher's first frame ticks nothing, since it has not stepped" do
    scene = FlCatchSpec::Scene.new
    assert_equal [], sounds { frame(scene) }
  end

  test "a falling ball sounds from the side it falls on, the catcher's column against its own" do
    scene = started
    files = [1, 3, 5].map do |column|
      scene.drop(0, column, 100)
      sounds { frame(scene) }.map { |file, _vol, _pitch| file }[0]
    end
    assert_equal ["pa_guide_l", "pa_guide_c", "pa_guide_r"], files
  end

  test "the ball's tone rises as it nears the floor, from 80 to the channel's 150" do
    pitches = [-40, 139, 318].map do |y|
      scene = started
      scene.drop(0, 5, y)
      sounds { frame(scene) }.map { |_file, _vol, pitch| pitch }[0]
    end
    assert_equal [80, 115, 150], pitches
  end

  test "the tone is the lowest ball's when several fall" do
    scene = started
    scene.drop(0, 1, 100)
    scene.drop(1, 5, 200)
    got = sounds { frame(scene) }
    assert_equal [["pa_guide_r", 60, 80 + ((240.0 / 358) * 70).to_i]], got
  end

  test "a ball is in reach down to the catcher's own height and no further" do
    got = [362, 363].map do |y|
      scene = started
      scene.drop(0, 5, y)
      [sounds { frame(scene) }.length, SpeakCapture.lines.length]
    end
    assert_equal [[1, 0], [0, 1]], got, "a tone and no word at that height, a word and no tone below it"
  end

  test "the ball's tone stays between 80 and 150 whatever its height" do
    pitches = [-100, 340].map do |y|
      scene = started
      scene.drop(0, 5, y)
      sounds { frame(scene) }.map { |_file, _vol, pitch| pitch }[0]
    end
    assert_equal [80, 150], pitches
  end

  test "a ball past the catcher is no longer sounded, and the next one takes the tone" do
    scene = started
    scene.drop(0, 1, 380)
    scene.drop(1, 5, 100)
    got = sounds { frame(scene) }.map { |file, _vol, _pitch| file }
    assert_equal ["pa_guide_r"], got
  end

  test "with no ball in reach the tone is silent" do
    scene = started
    scene.drop(0, 5, 380)
    assert_equal [], sounds { frame(scene) }
  end

  test "the tone repeats every gap while the ball falls, at once when its side changes or a new ball is lowest" do
    scene = started
    scene.drop(0, 5, 100)
    counts = []
    with_clock(10.0) do |set|
      with_cue_log do |log|
        [[10.0, nil], [10.05, nil], [10.13, nil], [10.15, :step_in], [10.2, nil], [10.3, :lower]].each do |now, event|
          set.call(now)
          scene.column = 5 if event == :step_in
          scene.drop(1, 2, 250) if event == :lower
          frame(scene)
          counts.push(guides(log).length)
        end
      end
    end
    assert_equal [1, 1, 2, 3, 3, 4], counts
  end

  test "a ball that takes over from another in the same column sounds at once" do
    scene = started
    scene.drop(0, 5, 100)
    counts = []
    with_clock(10.0) do |set|
      with_cue_log do |log|
        [[10.0, nil], [10.01, :swap]].each do |now, event|
          set.call(now)
          if event == :swap
            scene.hide!(0)
            scene.drop(1, 5, 200)
          end
          frame(scene)
          counts.push(guides(log).length)
        end
      end
    end
    assert_equal [1, 2], counts
  end

  test "the tone repeats exactly when the gap is over" do
    scene = started
    scene.drop(0, 5, 100)
    gap = PokeAccess::FLBallCatch::GAP
    counts = []
    with_clock(0.0) do |set|
      with_cue_log do |log|
        [0.0, gap - 0.01, gap].each do |now|
          set.call(now)
          frame(scene)
          counts.push(guides(log).length)
        end
      end
    end
    assert_equal [1, 1, 2], counts
  end

  test "the tones play at the minigame's volume" do
    PokeAccess::Config.minigame_volume = 25
    scene = started
    scene.drop(0, 5, 100)
    assert_equal [25], sounds { frame(scene) }.map { |_file, vol, _pitch| vol }
  end

  test "a catch says the score as painted, cutting in, and the info key holds it" do
    scene = started
    scene.drop(0, 3, 330)
    with_clock(10.0) { frame(scene) { scene.catch!(0) } }
    assert_equal [["Score: 1/50", true]], SpeakCapture.log
    assert_equal "Score: 1/50", PokeAccess::Info.info_text
  end

  test "catches in a run are said at most every score gap, the latest score once the gap has passed" do
    scene = started
    scene.drop(0, 3, 330)
    scene.drop(1, 3, 330)
    scene.drop(2, 3, 330)
    got = []
    with_clock(10.0) do |set|
      [[10.0, 0], [10.5, 1], [11.0, nil], [11.6, nil], [12.0, 2], [13.6, nil]].each do |now, catching|
        set.call(now)
        frame(scene) { scene.catch!(catching) } if catching
        frame(scene) unless catching
        got.push(SpeakCapture.lines.dup)
      end
    end
    assert_equal [["Score: 1/50"], ["Score: 1/50"], ["Score: 1/50"], ["Score: 1/50", "Score: 2/50"],
                  ["Score: 1/50", "Score: 2/50"], ["Score: 1/50", "Score: 2/50", "Score: 3/50"]], got
  end

  test "a ball that gets past the catcher says a word for it, cutting in, and a ball caught does not" do
    scene = started
    scene.drop(0, 1, 400)
    frame(scene)
    lost = SpeakCapture.log.dup
    SpeakCapture.clear
    scene.drop(1, 3, 330)
    with_clock(10.0) { frame(scene) { scene.catch!(1) } }
    assert_equal [[[t(:bcatch_lost), true]], [["Score: 1/50", true]]], [lost, SpeakCapture.log]
  end

  test "a ball is said to have got past once, however many frames it takes to leave the screen" do
    scene = started
    scene.drop(0, 1, 400)
    3.times { |i| scene.ball(0).y = 400 + i * 20; frame(scene) }
    scene.hide!(0)
    frame(scene)
    assert_equal [[t(:bcatch_lost), true]], SpeakCapture.log
  end

  test "two balls past the catcher in one frame say the word once" do
    scene = started
    scene.drop(0, 1, 400)
    scene.drop(1, 5, 420)
    frame(scene)
    assert_equal [[t(:bcatch_lost), true]], SpeakCapture.log
  end

  test "a ball caught and another past in one frame say both" do
    scene = started
    scene.drop(0, 1, 400)
    scene.drop(1, 3, 330)
    with_clock(10.0) { frame(scene) { scene.catch!(1) } }
    assert_equal [[t(:bcatch_lost), true], ["Score: 1/50", true]], SpeakCapture.log
  end

  test "balls getting past one after the other in the same column are said apart" do
    scene = started
    scene.drop(0, 1, 400)
    frame(scene)
    scene.drop(1, 1, 400)
    frame(scene)
    assert_equal [[t(:bcatch_lost), true], [t(:bcatch_lost), true]], SpeakCapture.log
  end

  test "a catch does not hide the next ball to get past" do
    scene = started
    scene.drop(0, 3, 330)
    with_clock(10.0) { frame(scene) { scene.catch!(0) } }
    SpeakCapture.clear
    scene.drop(1, 1, 400)
    with_clock(20.0) { frame(scene) }
    assert_equal [[t(:bcatch_lost), true]], SpeakCapture.log
  end

  test "a sprite the game reuses for the next ball can get a ball past again, and a fresh ball is not past" do
    scene = started
    scene.drop(0, 1, 400)
    frame(scene)
    SpeakCapture.clear
    scene.drop(0, 5, -40)
    frame(scene)
    assert_nothing_spoken
    scene.ball(0).y = 400
    frame(scene)
    assert_equal [[t(:bcatch_lost), true]], SpeakCapture.log
  end

  test "a score owed is said as soon as the gap is over, and once" do
    scene = started
    scene.drop(0, 3, 330)
    scene.drop(1, 3, 330)
    gap = PokeAccess::FLBallCatch::SCORE_GAP
    heard = []
    with_clock(0.0) do |set|
      [[0.0, 0], [0.5, 1], [gap - 0.01, nil], [gap, nil], [gap * 2, nil], [gap * 3, nil]].each do |now, catching|
        set.call(now)
        frame(scene) { scene.catch!(catching) } if catching
        frame(scene) unless catching
        heard.push(SpeakCapture.lines.length)
      end
    end
    assert_equal [1, 1, 1, 2, 2, 2], heard
  end

  test "the final score is said queued as the scene ends, and the info key is cleared" do
    scene = started
    scene.drop(0, 3, 330)
    with_clock(10.0) { frame(scene) { scene.catch!(0) } }
    SpeakCapture.clear
    PokeAccess::FLBallCatch.finished(scene)
    assert_equal [["Score: 1/50", false]], SpeakCapture.log
    assert_nil PokeAccess::Info.info_text
  end

  test "a score that rose with nothing painted keeps the last text said, and says nothing new" do
    scene = started
    scene.score = 1
    with_clock(10.0) { frame(scene) }
    assert_nothing_spoken
    assert_equal "Score: 0/50", PokeAccess::Info.info_text
  end

  test "a scene with no catcher sprite still ticks its steps and says its score" do
    scene = FlCatchSpec::Scene.new
    scene.instance_variable_get(:@sprites).delete("player")
    opening(scene)
    frame(scene)
    SpeakCapture.clear
    scene.drop(0, 3, 330)
    played = sounds { scene.column = 4; frame(scene) { scene.catch!(0) } }
    assert_equal [["pa_ledge_r", 60, 123]], played
    assert_equal [["Score: 1/50", true]], SpeakCapture.log
  end

  test "a scene that never painted a score ends in silence, its info line gone" do
    PokeAccess::Info.set_info(:text, "left over")
    PokeAccess::FLBallCatch.finished(Object.new)
    assert_nothing_spoken
    assert_nil PokeAccess::Info.info_text
  end

  test "a frame of a scene it cannot read says and sounds nothing" do
    sounded = sounds { PokeAccess::FLBallCatch.frame(Object.new, []) }
    assert_equal [], sounded
    assert_nothing_spoken
  end

  test "the balls on show are the visible sprites, by their number" do
    scene = started
    scene.drop(0, 1, 50)
    scene.drop(1, 2, 60)
    scene.drop(2, 3, 70)
    scene.hide!(1)
    assert_equal [[0, 120, 50], [2, 248, 70]], PokeAccess::FLBallCatch.balls(scene)
  end

  test "a column is read from the ball's x by the game's spacing" do
    scene = FlCatchSpec::Scene.new
    assert_equal [0, 3, 6], [56, 248, 440].map { |x| PokeAccess::FLBallCatch.column_of(scene, x) }
  end

  private

  def t(key, args = {}); PokeAccess::I18n.t(key, args); end

  # What the opening hook says for a scene: the game's pbStartScene paints its score once, sampled as the hook does.
  def opening(scene)
    rows = PokeAccess::PaintCapture.sample { scene.pbDrawText }
    PokeAccess::FLBallCatch.opened(scene, rows)
  end

  # A scene whose opening has been read, so the reader holds its score and column; the speech of it cleared.
  def started(columns = 7)
    scene = FlCatchSpec::Scene.new(columns)
    opening(scene)
    frame(scene)
    SpeakCapture.clear
    scene
  end

  # One frame as the applyCollisions hook runs it: the paint the block makes, then the frame's reading.
  def frame(scene)
    rows = PokeAccess::PaintCapture.sample { yield if block_given? }
    PokeAccess::FLBallCatch.frame(scene, rows)
  end

  # The flat sounds the block plays, as [file, volume, pitch], the mod's clock stopped at 10 s.
  def sounds
    got = nil
    with_clock(10.0) do
      with_cue_log do |log|
        yield
        got = log.map { |entry| [cue_name(entry), entry[1], entry[2]] }
      end
    end
    got
  end

  # The guide's chimes in a sound log.
  def guides(log)
    log.select { |entry| cue_name(entry).start_with?("pa_guide") }
  end

  # Runs the block with the mod's clock at start, a setter for it handed to the block, the real clock put back after.
  def with_clock(start)
    now = start
    real = PokeAccess.method(:clock)
    PokeAccess.define_singleton_method(:clock) { now }
    yield lambda { |t| now = t }
  ensure
    PokeAccess.define_singleton_method(:clock, real)
  end
end
