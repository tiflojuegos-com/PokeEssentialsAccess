# Tunia's hacking levels with the puzzle assist: stopped on a station, the way on to the next; on a crossing of the
# marcianitos' rounds, wait while a start now would meet one, go with the way once it keeps clear and what the arrival
# brought has been heard, and wait again when the go is missed; a long way told with the wait, its go short; stop once
# an arrival on a waiting spot with a round right past it, whose tile before waits as it does, and none on a go's way;
# a tight crossing told once; the waiting spots listed with the assist alone, and each level's stations chained from
# its start to its breach.
class RevivalHackGdTest < PokeAccessTest
  Route = Struct.new(:list, :repeat)
  Move = Struct.new(:code, :parameters)
  # Tuniatruco 1's marcianito: six right, a second's wait, eight down, wait, six left, wait, eight up, wait.
  ROUND = [3] * 6 + [[15, 20]] + [1] * 8 + [[15, 20]] + [2] * 6 + [[15, 20]] + [4] * 8 + [[15, 20]]
  # Each level's breach, by its event's tile in the game's maps.
  BREACHES = { 15 => [14, 8], 16 => [14, 8], 17 => [14, 8], 158 => [14, 8], 159 => [14, 8], 160 => [14, 8],
               161 => [14, 8], 162 => [14, 8], 248 => [16, 9], 249 => [26, 10], 250 => [16, 7], 251 => [9, 9] }

  def setup
    super
    Harness.load_puzzles("revival")
    PokeAccess::Config.puzzle_assist = true
    $game_map.map_id = 15
    [:@stay, :@braked, :@route, :@route_from, :@tight, :@read_until, :@last_line].each do |v|
      hack.instance_variable_set(v, nil)
    end
    World.next_frame
  end

  test "the start says the way to the first waiting spot" do
    start = PokeAccess::RevivalHack::STATIONS[15][0]
    stand(start)
    assert_equal [[t(:rv_hack_lead, :way => way(start)), false]], tick
    assert_equal [], tick
  end

  test "a crossing says wait while a start would meet the marcianito, go with its way once clear, and wait if missed" do
    crossing = PokeAccess::RevivalHack::STATIONS[15][1]
    marcianito(17, 18, 19)
    stand(crossing)
    assert_equal [[t(:rv_hack_wait), false]], tick
    settle
    marcianito(15, 10, 1, :timer => 0.0)
    assert_equal [[t(:rv_hack_go, :way => way(crossing)), true]], tick
    assert_equal [], tick
    marcianito(17, 18, 19)
    assert_equal [], tick
    PokeAccess::RevivalHack.instance_variable_get(:@stay)[:at] -= 1.0
    assert_equal [[t(:rv_hack_wait), true]], tick
  end

  test "with a reader that cannot tell, holds the go until what the mod sent it can have been read" do
    crossing = PokeAccess::RevivalHack::STATIONS[15][1]
    marcianito(15, 10, 1, :timer => 0.0)
    stand(crossing)
    assert_equal [[t(:rv_hack_wait), false]], tick
    stay[:since] -= 1.0
    assert_equal [], tick
    hack.instance_variable_set(:@read_until, hack.clock - 0.1)
    assert_equal [[t(:rv_hack_go, :way => way(crossing)), true]], tick
  end

  test "with a reader that tells, holds the go while it talks and goes as it falls quiet" do
    talking = true
    reader(lambda { talking }) do
      crossing = PokeAccess::RevivalHack::STATIONS[15][1]
      marcianito(15, 10, 1, :timer => 0.0)
      stand(crossing)
      assert_equal [[t(:rv_hack_wait), false]], tick
      stay[:since] -= 1.0
      hack.instance_variable_set(:@read_until, hack.clock - 0.1)
      assert_equal [], tick
      talking = false
      assert_equal [[t(:rv_hack_go, :way => way(crossing)), true]], tick
    end
  end

  test "a long way is told with the wait, and its go is short once that has been read" do
    start = long_wait
    assert_equal [[t(:rv_hack_wait_way, :way => way(start)), false]], tick
    $game_map.events.delete(2)
    settle
    assert_equal [[t(:rv_hack_go_short), true]], tick
  end

  test "a way told with the wait and cut by another line goes again with the go" do
    start = long_wait
    assert_equal [[t(:rv_hack_wait_way, :way => way(start)), false]], tick
    PokeAccess.speak("info", true)
    $game_map.events.delete(2)
    settle
    assert_equal [[t(:rv_hack_go, :way => way(start)), true]], tick
  end

  test "a go due before the way told with the wait has been read goes with the way" do
    reader(lambda { true }) do
      start = long_wait
      assert_equal [[t(:rv_hack_wait_way, :way => way(start)), false]], tick
      $game_map.events.delete(2)
      stay[:since] -= 1.0
      assert_equal [], tick
      hack.instance_variable_set(:@last_line, hack.clock - PokeAccess::RevivalHack::HOLD_MAX)
      assert_equal [[t(:rv_hack_go, :way => way(start)), true]], tick
    end
  end

  test "says stop once an arrival onto a waiting spot with a round past it, through the still pulses of a held key" do
    assert_equal [t(:rv_hack_stop)], held_walk(16, 22, 8, 3)
    stand([16, 23])
    tick
    PokeAccess::Config.puzzle_assist = false
    assert_equal [], held_walk(16, 22, 8, 3)
  end

  test "the tile before a braking spot waits and goes as the spot does, a step longer, with no stop on its way" do
    marcianito(17, 18, 19)
    stand([16, 20])
    assert_equal [[t(:rv_hack_wait), false]], tick
    settle
    marcianito(15, 10, 1, :timer => 0.0)
    before = [16, 20, [8] + PokeAccess::RevivalHack::STATIONS[15][1][2]]
    assert_equal [[t(:rv_hack_go, :way => way(before)), true]], tick
    assert_equal [], held_walk(16, 20, 8, 2)
  end

  test "a tight crossing says so once a session, from its waiting spot or the tile before it" do
    $game_map.map_id = 251
    World.next_frame
    tight = PokeAccess::RevivalHack::STATIONS[251].find { |s| s[3] && s[3] < PokeAccess::RevivalHack::TIGHT }
    marcianito(tight[0], tight[1] - 1, 0, :round => [])
    stand([tight[0], tight[1] + 1])
    assert_equal [[t(:rv_hack_wait), false], [t(:rv_hack_tight), false]], tick
    stand(tight)
    assert_equal [[t(:rv_hack_wait), false]], tick
    stand([tight[0], tight[1] + 2])
    tick
    stand(tight)
    assert_equal [[t(:rv_hack_wait), false]], tick
  end

  test "says nothing without the assist, and lists the waiting spots with it alone" do
    stand(PokeAccess::RevivalHack::STATIONS[15][1])
    marcianito(15, 10, 1, :timer => 0.0)
    PokeAccess::Config.puzzle_assist = false
    assert_equal [], tick
    refute_includes names, t(:rv_hack_wait_spot, :n => 1)
    PokeAccess::Config.puzzle_assist = true
    assert_includes names, t(:rv_hack_wait_spot, :n => 1)
  end

  test "every level's stations run from its start to its breach, each way ending on the next station" do
    PokeAccess::RevivalHack::LEVELS.each do |map, (_breach, start)|
      list = PokeAccess::RevivalHack::STATIONS[map]
      assert_equal start, list[0][0, 2], "Map#{map} starts elsewhere"
      list.each_cons(2) { |a, b| assert_equal b[0, 2], steps(a), "Map#{map} breaks at #{a[0, 2].inspect}" }
      assert_equal BREACHES[map], steps(list.last), "Map#{map} ends off its breach"
      assert list.any? { |s| s[3] }, "Map#{map} has no crossing"
    end
  end

  private

  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # The way on from a station, as said.
  def way(station)
    PokeAccess::Routes::Text.steps(station[2])
  end

  # The tile a station's way ends on.
  def steps(station)
    delta = PokeAccess::RevivalHack::DELTA
    station[2].inject(station[0, 2]) { |(x, y), d| [x + delta[d][0], y + delta[d][1]] }
  end

  # Puts the player still on a station's tile.
  def stand(station)
    $game_player.x = station[0]
    $game_player.y = station[1]
  end

  def hack; PokeAccess::RevivalHack; end

  # The stay on the station the player stands on.
  def stay; hack.instance_variable_get(:@stay); end

  # Makes the station the player stands on long enough ago, and what the mod has sent read by now.
  def settle
    stay[:since] -= 1.0
    stay[:told] -= 60.0 if stay[:told]
    hack.instance_variable_set(:@read_until, hack.clock - 0.1)
  end

  # Runs the block with a reader whose speaking? answers what talk gives.
  def reader(talk)
    real = PokeAccess.method(:speaking?)
    PokeAccess.define_singleton_method(:speaking?) { talk.call }
    yield
  ensure
    PokeAccess.define_singleton_method(:speaking?, real)
  end

  # Puts the player on Tuniatruco 11's start, a way of five legs, behind a marcianito standing on its first step.
  def long_wait
    $game_map.map_id = 250
    World.next_frame
    start = hack::STATIONS[250][0]
    marcianito(start[0], start[1] - 1, 0, :round => [])
    stand(start)
    start
  end

  # Walks the player from (x, y) n steps toward dir with the key held, pulse by pulse as v21 runs it: three pulses into
  # each step, then the still one before the next step starts, a map frame after each; what it said, in order.
  def held_walk(x, y, dir, n)
    moving = false
    $game_player.define_singleton_method(:moving?) { moving }
    $game_player.direction = dir
    $game_player.x = x
    $game_player.y = y
    $game_player.instance_variable_set(:@move_time, 0.25)
    said = []
    n.times do
      $game_player.x += PokeAccess::RevivalHack::DELTA[dir][0]
      $game_player.y += PokeAccess::RevivalHack::DELTA[dir][1]
      moving = true
      [0.0, 0.1, 0.2].each { |tm| said.concat(pulse(tm)) }
      moving = false
      said.concat(pulse(nil))
    end
    said
  ensure
    $game_player.singleton_class.send(:remove_method, :moving?)
    $game_player.send(:remove_instance_variable, :@move_time)
    $game_player.send(:remove_instance_variable, :@move_timer)
  end

  # One pulse with the player's step timer at tm, then a map frame: the texts it said.
  def pulse(tm)
    $game_player.instance_variable_set(:@move_timer, tm)
    SpeakCapture.clear
    PokeAccess::RevivalHack.tick
    PokeAccess::Frame.instance_variable_set(:@serial, PokeAccess::Frame.serial + 1)
    SpeakCapture.log.map { |l| l[0] }
  end

  # A marcianito at (x, y), its round (Tuniatruco 1's unless opts[:round]) on at command index, stepping
  # (opts[:timer]) or between steps.
  def marcianito(x, y, index, opts = {})
    page = TestPage.new(:trigger => 2, :sprite => "minijuegotuniamarcianito", :list => [TestCmd.new(201, [])])
    ev = TestGameEvent.new(:id => 2, :x => x, :y => y, :pages => [page], :active_page => page)
    round = opts[:round] || ROUND
    list = round.map { |c| c.is_a?(Array) ? Move.new(c[0], [c[1]]) : Move.new(c, []) } + [Move.new(0, [])]
    ev.instance_variable_set(:@move_route, Route.new(list, true))
    ev.instance_variable_set(:@move_route_index, index)
    ev.instance_variable_set(:@move_time, 0.1)
    ev.instance_variable_set(:@move_timer, opts[:timer])
    ev.instance_variable_set(:@wait_count, 0.0)
    $game_map.events[2] = ev
  end

  # A pulse of the cue after a map frame has run: what it said.
  def tick
    SpeakCapture.clear
    PokeAccess::RevivalHack.tick
    PokeAccess::Frame.instance_variable_set(:@serial, PokeAccess::Frame.serial + 1)
    PokeAccess::RevivalHack.tick
    SpeakCapture.log.dup
  end

  # The names the puzzles category lists now.
  def names
    World.next_frame
    PokeAccess::Puzzles.category_targets.map(&:name)
  end
end
