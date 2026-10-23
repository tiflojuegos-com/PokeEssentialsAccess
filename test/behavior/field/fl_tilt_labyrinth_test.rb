# FL's Tilt Labyrinth (plugins/fl_tilt_labyrinth.rb) over stand-ins of its scene, screen, board, ball and labyrinth: the
# opening, the goal's tone by the way the ball rolls and from the side the goal lies on across the board's turn, the
# holes, the time's warnings, the end and the info key's line.
module FlTiltSpec
  Ball = Struct.new(:grid_pos, :at_hole_this_frame)
  Board = Struct.new(:ball, :labyrinth, :angle, :remaining_balls)

  # The game's labyrinth as the reader asks it: a grid of 0 floor, 1 wall, 2 hole, 3 entrance and 4 exit.
  class Lab
    attr_reader :grid, :width, :height, :hole_pos_array, :exit_pos_array

    def initialize(grid)
      @grid = grid
      @height = grid.length
      @width = grid[0].length
      @hole_pos_array = cells(2)
      @exit_pos_array = cells(4)
    end

    def get(x, y); @grid[y][x]; end

    def passable?(x, y)
      x >= 0 && y >= 0 && x < @width && y < @height && get(x, y) != 1
    end

    private

    def cells(kind)
      out = []
      @grid.each_with_index { |row, y| row.each_with_index { |v, x| out.push([x, y]) if v == kind } }
      out
    end
  end

  # The game's screen as the reader asks it: the board, the clock and the end flags.
  class Screen
    attr_accessor :board, :time_count, :max_time, :completed

    def initialize(board, max_time)
      @board = board
      @max_time = max_time
      @time_count = 0.0
      @completed = false
    end

    def has_time_limit?; @max_time > 0; end
    def time_limit_triggered?; has_time_limit? && @time_count >= @max_time; end
    def ball_limit_triggered?; @board.remaining_balls ? @board.remaining_balls <= 0 : false; end
  end

  class Scene
    def initialize(screen); @screen = screen; end
  end
end

class FlTiltLabyrinthTest < PokeAccessTest
  # Labyrinth 1 of the game, and small ones for one question each: a way round that the straight line misleads, a hole
  # on a way, two exits where the nearest in a straight line is not the nearest by the way, and a ball on a hole.
  LAB1 = [[0, 3, 0, 0, 0], [0, 0, 0, 0, 0], [0, 1, 0, 0, 0], [0, 1, 0, 0, 0], [0, 1, 1, 1, 0], [0, 0, 0, 0, 0],
          [0, 0, 0, 0, 0], [1, 1, 1, 1, 0], [4, 0, 0, 0, 0]]
  DETOUR = [[0, 0, 0, 0, 0], [1, 1, 1, 1, 0], [4, 0, 0, 0, 0]]
  HOLED = [[3, 0, 2, 0, 0], [0, 1, 1, 1, 0], [4, 0, 0, 0, 0]]
  FORK = [[4, 1, 0, 0, 0, 4], [0, 0, 0, 0, 0, 0]]
  NEAREST = [[0, 0, 2, 0, 0, 4], [0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0], [4, 0, 0, 0, 0, 0]]

  test "the opening says the time of a timed game, the balls as painted, where the goal lies and how to play, queued" do
    scene = scene_on(LAB1, [1, 0], :time => 60, :balls => 3)
    paint(scene, [["1:00", 480, 12], ["Balls: 2", 8, 12]])
    PokeAccess::FLTilt.opened(scene)
    expected = PokeAccess.sentences([t(:tilt_time_left, :t => "1:00"), "Balls: 2",
                                     goal_line([[:dir_down, 8], [:dir_left, 1]]), t(:tilt_hint)])
    assert_equal [[expected, false]], SpeakCapture.log
  end

  test "a game with no time limit opens without its clock, and no ball limit paints no balls" do
    scene = scene_on(LAB1, [1, 0])
    paint(scene, [["0:00", 480, 12]])
    PokeAccess::FLTilt.opened(scene)
    expected = PokeAccess.sentences([goal_line([[:dir_down, 8], [:dir_left, 1]]), t(:tilt_hint)])
    assert_equal [[expected, false]], SpeakCapture.log
  end

  test "without key hints the opening leaves out how to play" do
    PokeAccess::Config.verbosity = :brief
    scene = scene_on(LAB1, [1, 0], :time => 60)
    paint(scene, [["1:00", 480, 12]])
    PokeAccess::FLTilt.opened(scene)
    expected = PokeAccess.sentences([t(:tilt_time_left, :t => "1:00"), goal_line([[:dir_down, 8], [:dir_left, 1]])])
    assert_equal [[expected, false]], SpeakCapture.log
  end

  test "a timed game whose clock has not been painted opens without a time" do
    scene = scene_on(LAB1, [1, 0], :time => 60)
    PokeAccess::FLTilt.opened(scene)
    expected = PokeAccess.sentences([goal_line([[:dir_down, 8], [:dir_left, 1]]), t(:tilt_hint)])
    assert_equal [[expected, false]], SpeakCapture.log
  end

  test "a scene it cannot read is not timed" do
    assert_equal false, PokeAccess::FLTilt.timed?(Object.new)
  end

  test "a scene it cannot read opens on how to play alone" do
    PokeAccess::FLTilt.opened(Object.new)
    assert_equal [[t(:tilt_hint), false]], SpeakCapture.log
  end

  test "a goal under the ball is said as close" do
    scene = scene_on(LAB1, [0, 8])
    across, down = PokeAccess::FLTilt.bearing(scene)
    assert_equal t(:tilt_goal_close), PokeAccess::FLTilt.goal_line(across, down)
  end

  test "the legs to the goal are said longest first, the vertical one first when equal" do
    tilt = PokeAccess::FLTilt
    assert_equal [[:dir_down, 8], [:dir_left, 1]], tilt.legs(-1.2, 7.6)
    assert_equal [[:dir_right, 5], [:dir_up, 2]], tilt.legs(5.0, -2.0)
    assert_equal [[:dir_up, 3], [:dir_right, 3]], tilt.legs(2.6, -3.4)
    assert_equal [[:dir_left, 4]], tilt.legs(-4.0, 0.4)
    assert_equal [], tilt.legs(0.4, -0.4)
  end

  test "the goal lies by the screen's picture: a quarter turn of the board brings what lay to the left below the ball" do
    scene = scene_on(LAB1, [3, 8])
    { 0 => [[:dir_left, 3]], 90 => [[:dir_down, 3]], 180 => [[:dir_right, 3]], -90 => [[:dir_up, 3]] }.each do |angle, want|
      board_of(scene).angle = angle
      assert_equal want, legs_of(scene), "the board turned #{angle} degrees"
    end
  end

  test "both legs turn with the board, the vertical and the across one trading places as the board goes round" do
    scene = scene_on(LAB1, [3, 6])
    turned = { 0 => [[:dir_left, 3], [:dir_down, 2]], 90 => [[:dir_down, 3], [:dir_right, 2]],
               180 => [[:dir_right, 3], [:dir_up, 2]], -90 => [[:dir_up, 3], [:dir_left, 2]],
               45 => [[:dir_down, 4], [:dir_left, 1]] }
    turned.each do |angle, want|
      board_of(scene).angle = angle
      assert_equal want, legs_of(scene), "the board turned #{angle} degrees"
    end
  end

  test "where no way leads from the ball's tile the goal is the exit nearest in a straight line" do
    scene = scene_on(NEAREST, [2, 0])
    assert_equal [[:dir_right, 3]], legs_of(scene), "the right exit is three tiles off, the one below to the left more"
  end

  test "without a way from the ball's tile the goal is the nearest exit in a straight line, whatever the ball and the exits" do
    rng = Random.new(5)
    scene = scene_on(LAB1, [0, 0])
    PokeAccess::FLTilt.state(scene).route = {}
    lab = Struct.new(:exit_pos_array)
    checked = 0
    80.times do
      exits = [[rng.rand(9), rng.rand(9)], [rng.rand(9), rng.rand(9)], [rng.rand(9), rng.rand(9)]].uniq
      pos = [rng.rand(9), rng.rand(9)]
      gaps = exits.map { |e| (e[0] - pos[0]) ** 2 + (e[1] - pos[1]) ** 2 }
      next unless gaps.select { |g| g == gaps.min }.length == 1
      assert_equal exits[gaps.index(gaps.min)], PokeAccess::FLTilt.target(scene, lab.new(exits), pos)
      checked += 1
    end
    assert_operator checked, :>, 40, "enough cases had a single nearest exit"
  end

  test "the goal is the exit the ball's way leads to, not the nearest in a straight line" do
    scene = scene_on(FORK, [2, 0])
    assert_equal [[:dir_right, 3]], legs_of(scene), "the left exit is two tiles off but four to roll, the right three and three"
  end

  test "the route map leaves out walls and holes and counts steps from the nearest exit" do
    map = PokeAccess::FLTilt.route_map(FlTiltSpec::Lab.new(HOLED))
    assert_equal [[3, 0, 7], [1, 0, 3], [0, 2, 0]], [[3, 0], [1, 0], [0, 2]].map { |x, y| [x, y, map[[x, y]][0]] }
    assert_nil map[[2, 0]], "the hole"
    assert_nil map[[1, 1]], "the wall"
  end

  test "the route map spreads from an exit every way, walls and holes aside" do
    map = PokeAccess::FLTilt.route_map(FlTiltSpec::Lab.new([[0, 0, 0], [0, 4, 0], [0, 0, 0]]))
    steps = [0, 1, 2].map { |y| [0, 1, 2].map { |x| map[[x, y]][0] } }
    assert_equal [[2, 1, 2], [1, 0, 1], [2, 1, 2]], steps
  end

  test "the ball is as far as the labyrinth reaches at the end of its longest way, and on the goal at the exit" do
    near = [[[[3, 4]], [[0, 0], [1, 0]]], [[[3, 0, 4]], [[0, 0], [1, 0], [2, 0]]]].map do |grid, positions|
      scene = scene_on(grid, [0, 0])
      positions.map do |pos|
        board_of(scene).ball.grid_pos = pos
        PokeAccess::FLTilt.closeness(scene, 1.0)
      end
    end
    assert_equal [[0.0, 1.0], [0.0, 0.5, 1.0]], near
  end

  test "the tone rises as the way to the goal shortens, not as the straight line does" do
    scene = scene_on(DETOUR, [0, 0])
    sounded = tones_for(scene, [[0, 0], [4, 1], [1, 2], [0, 2]])
    assert_equal [["pa_guide_c", 80], ["pa_guide_l", 115], ["pa_guide_l", 143], ["pa_guide_c", 150]], sounded
  end

  test "where no way leads from the ball's tile the tone follows the straight line" do
    scene = scene_on(HOLED, [2, 0])
    near = PokeAccess::FLTilt.closeness(scene, Math.sqrt(8))
    assert_in_delta 1.0 - Math.sqrt(8) / Math.sqrt(34), near, 1e-9
  end

  test "the tone is the chime of the side the goal lies on, the middle when it is nearly in line" do
    tilt = PokeAccess::FLTilt
    assert_equal [:center, :center, :right, :left],
                 [tilt.side(0.4, 10.0), tilt.side(1.9, 10.0), tilt.side(2.1, 10.0), tilt.side(-2.1, 10.0)]
    assert_equal [:center, :right, :left], [tilt.side(0.4, 1.0), tilt.side(0.6, 1.0), tilt.side(-0.6, 1.0)]
    assert_equal [:center, :center, :center], [tilt.side(0.5, 1.0), tilt.side(-0.5, 1.0), tilt.side(2.0, 10.0)]
  end

  test "the chime follows the board's turn: the goal to the left, then below the ball, then to its right" do
    files = [0, 90, 180].map do |angle|
      tones_for(scene_on(LAB1, [3, 8], :angle => angle), [[3, 8]]).map { |file, _pitch| file }
    end
    assert_equal [["pa_guide_l"], ["pa_guide_c"], ["pa_guide_r"]], files
  end

  test "the tone plays at the minigame's volume" do
    PokeAccess::Config.minigame_volume = 33
    scene = scene_on(DETOUR, [0, 0])
    volumes = nil
    with_clock(10.0) do
      with_cue_log do |log|
        PokeAccess::FLTilt.playing(scene) { PokeAccess::FLTilt.poll }
        volumes = log.map { |entry| entry[1] }
      end
    end
    assert_equal [33], volumes
  end

  test "a tone sounds at once on a new tile and then every period while the ball stays on it" do
    scene = scene_on(DETOUR, [0, 0])
    period = PokeAccess::FLTilt::PERIOD
    moves = [[0.0, [0, 0]], [0.2, [0, 0]], [period - 0.01, [0, 0]], [period, [0, 0]], [period + 0.05, [4, 0]],
             [period + 0.1, [4, 0]], [period * 2 + 0.05, [4, 0]]]
    assert_equal [1, 1, 1, 2, 3, 3, 4], tone_counts(scene, moves)
  end

  test "a ball that falls to the tile below sounds at once, as one that rolls to the side does" do
    scene = scene_on(LAB1, [1, 0])
    assert_equal [1, 1, 2, 3], tone_counts(scene, [[0.0, [1, 0]], [0.1, [1, 0]], [0.2, [1, 1]], [0.25, [2, 1]]])
  end

  test "a ball between tiles counts for the nearest one" do
    scene = scene_on(DETOUR, [0, 0])
    moves = [[10.0, [0.2, 0.3]], [10.1, [0.4, 0.45]], [10.2, [0.6, 0.0]]]
    assert_equal [1, 1, 2], tone_counts(scene, moves)
  end

  test "the pulse of every frame drives the tone while the game's loop runs, and only then" do
    scene = scene_on(DETOUR, [0, 0])
    got = []
    with_clock(10.0) do
      with_cue_log do |log|
        PokeAccess::Frame.run_pollers
        got.push(chimes(log).length)
        PokeAccess::FLTilt.playing(scene) { PokeAccess::Frame.run_pollers }
        got.push(chimes(log).length)
        PokeAccess::Frame.run_pollers
        got.push(chimes(log).length)
      end
    end
    assert_equal [0, 1, 1], got
  end

  test "no tone talks over a message on the screen" do
    scene = scene_on(DETOUR, [0, 0])
    played = nil
    with_clock(10.0) do
      with_cue_log do |log|
        with_message { PokeAccess::FLTilt.playing(scene) { PokeAccess::FLTilt.poll } }
        played = log.length
      end
    end
    assert_equal 0, played
  end

  test "a labyrinth with no exit has no goal to sound" do
    scene = scene_on([[3, 0, 0]], [0, 0])
    played = nil
    with_clock(10.0) do
      with_cue_log do |log|
        PokeAccess::FLTilt.playing(scene) { PokeAccess::FLTilt.poll }
        played = log.length
      end
    end
    assert_equal 0, played
  end

  test "a ball that has reached the goal sounds no more" do
    scene = scene_on(DETOUR, [0, 0])
    board_of(scene).ball = nil
    played = nil
    with_clock(10.0) do
      with_cue_log do |log|
        PokeAccess::FLTilt.playing(scene) { PokeAccess::FLTilt.poll }
        played = log.length
      end
    end
    assert_equal 0, played
  end

  test "the seconds left are said as 30, 10 and 5 are crossed, once each and cutting in" do
    scene = scene_on(LAB1, [1, 0], :time => 40)
    spoken_at = []
    with_clock(10.0) do
      PokeAccess::FLTilt.playing(scene) do
        [31.0, 30.1, 29.9, 20.0, 10.5, 10.0, 5.5, 5.0, 0.1].each_with_index do |left, i|
          screen_of(scene).time_count = 40 - left
          before = SpeakCapture.log.length
          PokeAccess::FLTilt.poll
          spoken_at.push(i) if SpeakCapture.log.length > before
        end
      end
    end
    assert_equal [2, 5, 7], spoken_at, "30 left at 29.9, 10 on reaching 10.0, 5 on reaching 5.0"
    assert_equal [true, true, true], SpeakCapture.log.map { |_text, interrupt| interrupt }
  end

  test "the warnings a short game's limit has already passed are not said" do
    scene = scene_on(LAB1, [1, 0], :time => 20)
    with_clock(10.0) do
      PokeAccess::FLTilt.playing(scene) do
        [0.0, 5.0, 9.9, 10.1, 14.9, 15.1].each do |spent|
          screen_of(scene).time_count = spent
          PokeAccess::FLTilt.poll
        end
      end
    end
    assert_equal 2, SpeakCapture.log.length, "10 left and 5 left, not 30"
  end

  test "a game with no time limit says no warning" do
    scene = scene_on(LAB1, [1, 0])
    with_clock(10.0) do
      PokeAccess::FLTilt.playing(scene) do
        [0.0, 20.0, 100.0].each do |spent|
          screen_of(scene).time_count = spent
          PokeAccess::FLTilt.poll
        end
      end
    end
    assert_nothing_spoken
  end

  test "a ball into a hole says the hole and the balls left as painted, cutting in" do
    scene = scene_on(LAB1, [1, 0], :balls => 3)
    paint(scene, [["1:00", 480, 12], ["Balls: 1", 8, 12]])
    ball_of(scene).at_hole_this_frame = true
    PokeAccess::FLTilt.sounds(scene)
    assert_equal [[PokeAccess.sentences([t(:tilt_hole), "Balls: 1"]), true]], SpeakCapture.log
  end

  test "a hole in a game with no ball limit says only the hole" do
    scene = scene_on(LAB1, [1, 0])
    ball_of(scene).at_hole_this_frame = true
    PokeAccess::FLTilt.sounds(scene)
    assert_equal [[t(:tilt_hole), true]], SpeakCapture.log
  end

  test "no hole is said for a ball rolling, for the last ball's fall or after the goal" do
    rolling = scene_on(LAB1, [1, 0], :balls => 2)
    PokeAccess::FLTilt.sounds(rolling)
    last = scene_on(LAB1, [1, 0], :balls => 0)
    ball_of(last).at_hole_this_frame = true
    PokeAccess::FLTilt.sounds(last)
    done = scene_on(LAB1, [1, 0])
    board_of(done).ball = nil
    PokeAccess::FLTilt.sounds(done)
    assert_nothing_spoken
  end

  test "the end is said by what ended the loop, cutting in; a cancel says nothing" do
    ends = [[:goal, lambda { |scene| screen_of(scene).completed = true }],
            [:time, lambda { |scene| screen_of(scene).time_count = 61.0 }],
            [:balls, lambda { |scene| board_of(scene).remaining_balls = 0 }],
            [:cancel, lambda { |_scene| nil }]]
    said = ends.map do |kind, end_it|
      scene = scene_on(LAB1, [1, 0], :time => 60, :balls => 2)
      end_it.call(scene)
      SpeakCapture.clear
      PokeAccess::FLTilt.finished(scene)
      [kind, SpeakCapture.log.dup]
    end
    assert_equal [[:goal, [[t(:tilt_win), true]]], [:time, [[t(:tilt_time_up), true]]],
                  [:balls, [[t(:tilt_no_balls), true]]], [:cancel, []]], said
  end

  test "reaching the goal in the last second still ends on the goal" do
    scene = scene_on(LAB1, [1, 0], :time => 60)
    screen_of(scene).time_count = 61.0
    screen_of(scene).completed = true
    PokeAccess::FLTilt.finished(scene)
    assert_equal [[t(:tilt_win), true]], SpeakCapture.log
  end

  test "the info key holds the time, the balls and where the goal lies, current as the ball rolls" do
    scene = scene_on(LAB1, [1, 0], :time => 60, :balls => 3)
    paint(scene, [["0:45", 480, 12], ["Balls: 2", 8, 12]])
    info = []
    with_clock(10.0) do |set|
      with_cue_log do
        PokeAccess::FLTilt.playing(scene) do
          PokeAccess::FLTilt.poll
          info.push(PokeAccess::Info.info_text)
          set.call(10.1)
          ball_of(scene).grid_pos = [0, 6]
          paint(scene, [["0:44", 480, 12]])
          PokeAccess::FLTilt.poll
          info.push(PokeAccess::Info.info_text)
        end
      end
    end
    first = PokeAccess.sentences([t(:tilt_time_left, :t => "0:45"), "Balls: 2", goal_line([[:dir_down, 8], [:dir_left, 1]])])
    second = PokeAccess.sentences([t(:tilt_time_left, :t => "0:44"), "Balls: 2", goal_line([[:dir_down, 2]])])
    assert_equal [first, second], info
  end

  test "the info key of a game with no time limit gives the time spent" do
    scene = scene_on(LAB1, [1, 0])
    paint(scene, [["0:12", 480, 12]])
    line = nil
    with_clock(10.0) do
      with_cue_log do
        PokeAccess::FLTilt.playing(scene) do
          PokeAccess::FLTilt.poll
          line = PokeAccess::Info.info_text
        end
      end
    end
    assert_equal PokeAccess.sentences([t(:tilt_time_spent, :t => "0:12"), goal_line([[:dir_down, 8], [:dir_left, 1]])]), line
  end

  test "the info line leaves with the game's loop" do
    scene = scene_on(LAB1, [1, 0])
    with_clock(10.0) do
      with_cue_log { PokeAccess::FLTilt.playing(scene) { PokeAccess::FLTilt.poll } }
    end
    assert_nil PokeAccess::Info.info_text
  end

  test "what the game paints is kept as the time and the balls, whatever the order, and a repaint of the time keeps the balls" do
    scene = scene_on(LAB1, [1, 0], :balls => 3)
    paint(scene, [["Balls: 2", 8, 12], ["1:05", 480, 12]])
    paint(scene, [["1:04", 480, 12]])
    run = PokeAccess::FLTilt.state(scene)
    assert_equal ["1:04", "Balls: 2"], [run.time_text, run.balls_text]
  end

  test "painted rows with nothing in them are left out" do
    scene = scene_on(LAB1, [1, 0])
    paint(scene, [["  ", 8, 12], ["0:07", 480, 12]])
    run = PokeAccess::FLTilt.state(scene)
    assert_equal ["0:07", nil], [run.time_text, run.balls_text]
  end

  private

  def t(key, args = {}); PokeAccess::I18n.t(key, args); end

  # A scene over a labyrinth, its ball at pos; opts :angle (the board's turn), :time (the limit in seconds) and :balls.
  def scene_on(grid, pos, opts = {})
    ball = FlTiltSpec::Ball.new(pos.dup, false)
    board = FlTiltSpec::Board.new(ball, FlTiltSpec::Lab.new(grid), opts.fetch(:angle, 0), opts[:balls])
    FlTiltSpec::Scene.new(FlTiltSpec::Screen.new(board, opts.fetch(:time, 0)))
  end

  def screen_of(scene); PokeAccess::FLTilt.screen_of(scene); end
  def board_of(scene); PokeAccess::FLTilt.board_of(scene); end
  def ball_of(scene); PokeAccess::FLTilt.ball_of(scene); end

  # What the scene's draw_text painted, as rows of [text, x, y], kept as the hook keeps them.
  def paint(scene, rows)
    PokeAccess::FLTilt.painted(scene, rows.map { |text, x, y| [text, :positions, x, y] })
  end

  # The legs from the ball to the goal.
  def legs_of(scene)
    across, down = PokeAccess::FLTilt.bearing(scene)
    PokeAccess::FLTilt.legs(across, down)
  end

  # The goal as the reader words it for these legs.
  def goal_line(legs)
    where = legs.map { |dir, n| t(:tilt_leg, :dir => t(dir), :n => n) }.join("; ")
    t(:tilt_goal, :where => where)
  end

  # The chimes in a sound log.
  def chimes(log)
    log.select { |entry| cue_name(entry).start_with?("pa_guide") }
  end

  # The chimes a ball sounds, as [file, pitch], as it is moved over each position in turn inside the game's loop, a
  # second apart.
  def tones_for(scene, positions)
    got = nil
    with_clock(10.0) do |set|
      with_cue_log do |log|
        PokeAccess::FLTilt.playing(scene) do
          positions.each_with_index do |pos, i|
            set.call(10.0 + i)
            ball_of(scene).grid_pos = pos.dup
            PokeAccess::FLTilt.poll
          end
        end
        got = chimes(log).map { |entry| [cue_name(entry), entry[2]] }
      end
    end
    got
  end

  # How many tones have sounded after each [time, ball position] move of the ball inside the game's loop.
  def tone_counts(scene, moves)
    counts = []
    with_clock(10.0) do |set|
      with_cue_log do |log|
        PokeAccess::FLTilt.playing(scene) do
          moves.each do |now, pos|
            set.call(now)
            ball_of(scene).grid_pos = pos.dup
            PokeAccess::FLTilt.poll
            counts.push(chimes(log).length)
          end
        end
      end
    end
    counts
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

  # Runs the block with a message on the screen, as the exit question is.
  def with_message
    was = $game_temp.message_window_showing
    $game_temp.message_window_showing = true
    yield
  ensure
    $game_temp.message_window_showing = was
  end
end
