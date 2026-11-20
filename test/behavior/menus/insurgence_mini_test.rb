# Insurgence's races on the Sonata Tracks (games/insurgence/races.rb) over small tracks drawn like the game's: what
# comes in the player's column and beside it as each row comes into view, the rows left, the place and a booster
# picked up, and the info key's line.

# Only the profile's module is evaluated: its condition, info owner and per-frame poll belong to the Insurgence process.
path = File.join(Harness::ROOT, "games", "insurgence", "races.rb")
eval(Harness.source(path)[/^module PokeAccess\r?\n.*?^end\r?\n/m], TOPLEVEL_BINDING, path)

class InsurgenceMiniTest < PokeAccessTest
  # A track as TileWorld draws it, plus Golden Sands' soft sand ('s', terrain 3), Ice Path's ice ('i', terrain 12),
  # a ramp's tile ('^') and a fence ('f'), both shut northward as the game's are (passage 8): only a ramp's jump goes on.
  class RaceWorld < TileWorld
    # The ground layer's tile ids, one per terrain tag as TileWorld's, the added tags too.
    class Tiles
      def initialize(world); @world = world; end
      def [](x, y, layer); layer == 0 ? 1 + @world.terrain_tag(x, y) : 0; end
    end

    def data; @tiles ||= Tiles.new(self); end

    def terrain_tag(x, y, *_)
      { "s" => 3, "i" => 12 }[cell(x, y)] || super
    end

    def passable?(x, y, d = 0)
      return false if (cell(x, y) == "^" || cell(x, y) == "f") && d == 8
      super
    end
  end

  TRACK = 274
  KEYS = { "ins_race_start" => "ins_race_start %{n}", "ins_race_left" => "ins_race_left %{n}",
           "ins_race_place" => "ins_race_place %{n}", "ins_race_wall_left" => "ins_race_wall_left %{n} %{gap}",
           "ins_race_wall_right" => "ins_race_wall_right %{n} %{gap}",
           "ins_race_wall_both" => "ins_race_wall_both %{n} %{gap}", "ins_race_wall_closed" => "ins_race_wall_closed %{n}",
           "ins_race_boost" => "ins_race_boost %{n}", "ins_race_boost_left" => "ins_race_boost_left %{n}",
           "ins_race_boost_right" => "ins_race_boost_right %{n}", "ins_race_ramp" => "ins_race_ramp %{n}",
           "ins_race_finish" => "ins_race_finish %{n}", "ins_race_grass" => "ins_race_grass %{n}",
           "ins_race_sand" => "ins_race_sand %{n}", "ins_race_ice" => "ins_race_ice %{n}",
           "ins_race_clear" => "ins_race_clear", "ins_race_boosted" => "ins_race_boosted",
           "ins_race_ramp_below" => "ins_race_ramp_below",
           "ins_race_ramp_below_left" => "ins_race_ramp_below_left %{gap}",
           "ins_race_ramp_below_right" => "ins_race_ramp_below_right %{gap}",
           "ins_race_ramp_below_both" => "ins_race_ramp_below_both %{gap}" }

  # An open track: the finish line on row 1, the player ten rows south of it.
  OPEN = ["###########", "#.........#", "#.........#", "#.........#", "#.........#", "#.........#",
          "#.........#", "#.........#", "#.........#", "#.........#", "#.........#", "#....@....#",
          "#.........#", "#.........#", "###########"]

  # A wall four rows ahead with gaps one and two columns west and four east; the nearer west gap meets another wall
  # two rows past it.
  FORKED = ["###########", "#.........#", "#.........#", "#...#.....#", "#.........#", "###..####.#",
            "#.........#", "#.........#", "#.........#", "#....@....#", "###########"]

  def setup
    super
    table = PokeAccess::I18n.table(PokeAccess::I18n.lang)
    KEYS.each { |k, v| table[k] = v unless table.key?(k) || table.key?("#{k}.one") }
    @old_map = $game_map
    @old_player = $game_player
    race.reset
  end

  def teardown
    $game_map = @old_map
    $game_player = @old_player
    $game_switches[136] = false
    $game_switches[137] = false
    $game_variables[63] = 0
    $game_temp.message_window_showing = false
    race.reset
    PokeAccess::Pathfinder.invalidate_cache(true)
    PokeAccess::World::Epoch.touch(:tiles)
    super
  end

  test "the start says the finish line to the north with what is already in view, interrupting" do
    track(["###########", "#.........#", "#.........#", "#.........#", "#.........#", "###..######",
           "#.........#", "#.........#", "#.........#", "#.........#", "#.........#", "#....@....#",
           "###########"])
    race.update
    assert_equal [[line([:ins_race_start, { :n => 10 }], [:ins_race_wall_left, { :n => 6, :gap => 1 }]), true]],
                 SpeakCapture.log
  end

  test "moving along under a wall says nothing, lining up with its gap says the way is clear, and back under it the wall again" do
    track(["###########", "#.........#", "#.........#", "#.........#", "#.........#", "###..######",
           "#.........#", "#.........#", "#.........#", "#.........#", "#.........#", "#....@....#",
           "###########"])
    race.update
    SpeakCapture.clear
    step(6, 11)
    assert_nothing_spoken "the same wall, one column on"
    step(4, 11)
    assert_equal [[t(:ins_race_clear), true]], SpeakCapture.log
    SpeakCapture.clear
    step(5, 11)
    assert_equal [[t(:ins_race_wall_left, :n => 6, :gap => 1), true]], SpeakCapture.log
  end

  test "a wall's gap is said on the nearer side, on both when they are as near, and none past the reach" do
    near = ["###########", "#.........#", "#.........#", "#.........#", "#.........#", "#.#######.#",
            "#.........#", "#.........#", "#.........#", "#....@....#", "###########"]
    track(near)
    race.update
    assert_includes SpeakCapture.lines.join, t(:ins_race_wall_both, :n => 4, :gap => 4)
    race.reset
    SpeakCapture.clear
    track(["###########", "#.........#", "#.........#", "#.........#", "#.........#", "#########.#",
           "#.........#", "#.........#", "#.........#", "#....@....#", "###########"])
    race.update
    assert_includes SpeakCapture.lines.join, t(:ins_race_wall_right, :n => 4, :gap => 4)
    race.reset
    SpeakCapture.clear
    track(["###########", "#.........#", "#.........#", "#.........#", "#.........#", "###########",
           "#.........#", "#.........#", "#.........#", "#....@....#", "###########"])
    race.update
    assert_includes SpeakCapture.lines.join, t(:ins_race_wall_closed, :n => 4)
  end

  test "a gap is reached along the player's own row, and only through a column open all the way to the wall" do
    track(["###########", "#.........#", "#.........#", "#.........#", "#.........#", "#.#########",
           "#..#......#", "#.........#", "#.........#", "#....@....#", "###########"])
    race.update
    assert_includes SpeakCapture.lines.join, t(:ins_race_wall_left, :n => 4, :gap => 4)
    race.reset
    SpeakCapture.clear
    track(["###########", "#.........#", "#.........#", "#.........#", "#.........#", "#.#########",
           "#.........#", "##........#", "#.........#", "#....@....#", "###########"])
    race.update
    assert_includes SpeakCapture.lines.join, t(:ins_race_wall_closed, :n => 4)
  end

  test "of the gaps, the column open furthest north wins over a nearer one with a wall further on" do
    track(FORKED)
    race.update
    assert_equal [[line([:ins_race_start, { :n => 8 }], [:ins_race_wall_left, { :n => 4, :gap => 2 }]), true]],
                 SpeakCapture.log
  end

  test "lining up with a gap that meets a wall further on says that wall, and the way clear only where it is" do
    track(FORKED)
    race.update
    SpeakCapture.clear
    step(4, 9)
    assert_equal [[t(:ins_race_wall_left, :n => 6, :gap => 1), true]], SpeakCapture.log
    SpeakCapture.clear
    step(3, 9)
    assert_equal [[t(:ins_race_clear), true]], SpeakCapture.log
  end

  test "a booster ahead and one beside are each said once, a row of them once however the player moves along it" do
    track(OPEN)
    boost(5, 8)
    boost(4, 9)
    race.update
    assert_equal [[line([:ins_race_start, { :n => 10 }], [:ins_race_boost, { :n => 3 }],
                        [:ins_race_boost_left, { :n => 2 }]), true]], SpeakCapture.log
    SpeakCapture.clear
    step(5, 10)
    step(4, 10)
    assert_nothing_spoken "both boosters were said"
  end

  test "a row of boosters is one: the player under it hears it once, moving along it nothing" do
    track(OPEN)
    [4, 5, 6].each { |x| boost(x, 8) }
    race.update
    assert_equal [[line([:ins_race_start, { :n => 10 }], [:ins_race_boost, { :n => 3 }]), true]], SpeakCapture.log
    SpeakCapture.clear
    step(6, 11)
    step(4, 11)
    assert_nothing_spoken
  end

  test "a ground that slows or slides is said where it starts, nothing while the column keeps it" do
    track(["###########", "#.........#", "#.........#", "#.........#", "#.........#", "#....i....#",
           "#....s....#", "#....g....#", "#....g....#", "#.........#", "#.........#", "#....@....#",
           "###########"])
    race.update
    assert_equal [[line([:ins_race_start, { :n => 10 }], [:ins_race_grass, { :n => 3 }], [:ins_race_sand, { :n => 5 }]),
                   true]], SpeakCapture.log
    SpeakCapture.clear
    step(5, 9)
    assert_equal [[t(:ins_race_ice, :n => 4), true]], SpeakCapture.log
    SpeakCapture.clear
    step(5, 8)
    assert_equal [[t(:ins_race_finish, :n => 7), true]], SpeakCapture.log, "on the grass, the grass ahead is no news"
  end

  test "a ramp is said, opens its row of wall for the column and counts as the gap beside" do
    track(["###########", "#.........#", "#.........#", "#.........#", "#.........#", "#.........#",
           "#.........#", "#####^#####", "#.........#", "#.........#", "#.........#", "#....@....#",
           "###########"])
    ramp(5, 7)
    race.update
    assert_equal [[line([:ins_race_start, { :n => 10 }], [:ins_race_ramp, { :n => 4 }]), true]], SpeakCapture.log
    assert_equal [[:ramp, 7, 4]], race.column(5, 11)
    SpeakCapture.clear
    step(4, 11)
    assert_equal [[t(:ins_race_wall_right, :n => 4, :gap => 1), true]], SpeakCapture.log
  end

  test "a rival in the column is no wall" do
    track(OPEN)
    rival(1, 5, 9)
    race.update
    assert_equal [[t(:ins_race_start, :n => 10), true]], SpeakCapture.log
    assert_equal [], race.column(5, 11)
  end

  test "nothing past the rows in view is said" do
    track(OPEN)
    boost(5, 3)
    race.update
    assert_equal [[t(:ins_race_start, :n => 10), true]], SpeakCapture.log
    SpeakCapture.clear
    step(5, 10)
    assert_equal [[t(:ins_race_boost, :n => 7), true]], SpeakCapture.log
  end

  test "while a booster runs the rows in view reach further" do
    track(OPEN)
    boost(5, 2)
    $game_variables[63] = [20, 0, 0, 0]
    race.update
    assert_equal [[line([:ins_race_start, { :n => 10 }], [:ins_race_boost, { :n => 9 }]), true]], SpeakCapture.log
  end

  test "a ramp stepped onto from a side opens nothing: the way is to step on it from the south" do
    track(["###########", "#.........#", "#.........#", "#.........#", "#.........#", "#.........#",
           "#.........#", "####f^^f###", "#.........#", "#.........#", "#.........#", "#...@.....#",
           "###########"])
    ramp(5, 7)
    ramp(6, 7)
    race.update
    assert_equal [[line([:ins_race_start, { :n => 10 }], [:ins_race_wall_right, { :n => 5, :gap => 1 }]), true]],
                 SpeakCapture.log
    step(4, 8)
    SpeakCapture.clear
    step(4, 7)
    assert_nothing_spoken "into the fence: the same wall, already said"
    step(5, 7)
    assert_equal [[t(:ins_race_ramp_below), true]], SpeakCapture.log
    assert_equal [:wall, 6, 1], race.column(5, 7)[0], "standing on the ramp, north is shut"
    SpeakCapture.clear
    step(5, 8)
    assert_includes SpeakCapture.lines.join, t(:ins_race_clear)
  end

  test "on ice a press slides on, so the way past a wall is where a slide stops" do
    track(["###########", "#.........#", "#.........#", "#.........#", "#.........#", "#######.#.#",
           "#.........#", "#.........#", "#.........#", "#.........#", "#.........#", "#....@iii.#",
           "###########"])
    race.update
    assert_equal [[line([:ins_race_start, { :n => 10 }], [:ins_race_wall_right, { :n => 6, :gap => 4 }]), true]],
                 SpeakCapture.log
  end

  test "on ice the info key adds where each press leaves the player" do
    track(["###########", "#.........#", "#.........#", "#.........#", "#.........#", "#.........#",
           "#.........#", "#.........#", "#.........#", "#.........#", "#.........#", "#....@iii.#",
           "###########"])
    race.update
    ways = PokeAccess::Info.forced_ways
    refute_nil ways, "a press east slides on"
    assert_equal line([:ins_race_place, { :n => 1 }], [:ins_race_left, { :n => 10 }], [:ins_race_clear, {}]) +
                 ". #{ways}", race.info
  end

  test "the finish line is said as it comes into view, and on it nothing more" do
    track(OPEN)
    race.update
    SpeakCapture.clear
    step(5, 7)
    assert_equal [[t(:ins_race_finish, :n => 6), true]], SpeakCapture.log
    SpeakCapture.clear
    step(5, 1)
    race.update
    assert_nothing_spoken
  end

  test "the place is said once it has held, the first one unsaid" do
    track(OPEN)
    [[1, 3, 12], [2, 5, 12], [3, 7, 12]].each { |id, x, y| rival(id, x, y) }
    (PokeAccess::InsurgenceRace::PLACE_SETTLE + 1).times { race.update }
    SpeakCapture.clear
    $game_map.events[2].y = 10
    $game_map.events[3].y = 9
    (PokeAccess::InsurgenceRace::PLACE_SETTLE - 1).times { race.update }
    assert_nothing_spoken "a place that has not held yet"
    race.update
    assert_equal [[t(:ins_race_place, :n => 3), false]], SpeakCapture.log
    SpeakCapture.clear
    3.times { race.update }
    assert_nothing_spoken
  end

  test "the rows left are said once, halfway, after the column's news and not cut by the next" do
    rows = ["###########"] + Array.new(54) { "#.........#" } + ["###########"]
    rows[52] = "#....@....#"
    track(rows)
    boost(5, 44)
    boost(5, 43)
    race.update
    assert_equal [[t(:ins_race_start, :n => 51), true]], SpeakCapture.log
    SpeakCapture.clear
    step(5, 51)
    assert_equal [[t(:ins_race_boost, :n => 7), true], [t(:ins_race_left, :n => 50), false]], SpeakCapture.log
    SpeakCapture.clear
    step(5, 50)
    assert_equal [[t(:ins_race_boost, :n => 7), false]], SpeakCapture.log
    SpeakCapture.clear
    step(5, 49)
    step(5, 51)
    step(5, 26)
    step(5, 11)
    assert_nothing_spoken "said once, and no other mark"
  end

  test "a fence row moved along says its wall once" do
    track(["###########", "#.........#", "#.........#", "#.........#", "#.........#", "#.........#",
           "#.........#", "#fffff^fff#", "#.........#", "#.........#", "#.........#", "#..@......#",
           "###########"])
    ramp(6, 7)
    race.update
    step(3, 8)
    step(3, 7)
    SpeakCapture.clear
    step(4, 7)
    step(5, 7)
    assert_nothing_spoken
  end

  test "a slide on ice says nothing on the way, and reads where it stops" do
    track(["###########", "#.........#", "#.........#", "###.#######", "#.........#", "#....i....#",
           "#....i....#", "#....i....#", "#....i....#", "#....i....#", "#....i....#", "#....i....#",
           "#....@....#", "###########"])
    race.update
    assert_equal [[line([:ins_race_start, { :n => 11 }], [:ins_race_ice, { :n => 1 }]), true]], SpeakCapture.log
    SpeakCapture.clear
    sliding = true
    $game_player.define_singleton_method(:moving?) { sliding }
    11.downto(5) { |y| step(5, y) }
    assert_nothing_spoken "on the way"
    sliding = false
    step(5, 4)
    assert_equal [[t(:ins_race_wall_left, :n => 1, :gap => 2), true]], SpeakCapture.log
  end

  test "a booster said beside is not cut by the next line about the player's own column" do
    track(OPEN)
    boost(4, 4)
    boost(5, 3)
    boost(5, 2)
    race.update
    assert_equal [[line([:ins_race_start, { :n => 10 }], [:ins_race_boost_left, { :n => 7 }]), true]],
                 SpeakCapture.log
    SpeakCapture.clear
    step(5, 10)
    assert_equal [[t(:ins_race_boost, :n => 7), false]], SpeakCapture.log
    SpeakCapture.clear
    step(5, 9)
    assert_equal [[t(:ins_race_boost, :n => 7), true]], SpeakCapture.log
  end

  test "a booster picked up is said once while it runs, and again for the next" do
    track(OPEN)
    race.update
    SpeakCapture.clear
    $game_variables[63] = [20, 0, 0, 0]
    race.update
    assert_equal [[t(:ins_race_boosted), false]], SpeakCapture.log
    SpeakCapture.clear
    $game_variables[63] = [12, 0, 0, 0]
    race.update
    $game_variables[63] = [0, 0, 0, 0]
    race.update
    assert_nothing_spoken
    $game_variables[63] = [20, 0, 0, 0]
    race.update
    assert_equal [[t(:ins_race_boosted), false]], SpeakCapture.log
  end

  test "the info key says the place, the rows left and the nearest thing ahead" do
    track(["###########", "#.........#", "#.........#", "#.........#", "#.........#", "###..######",
           "#.........#", "#.........#", "#.........#", "#.........#", "#.........#", "#....@....#",
           "###########"])
    race.update
    assert_equal line([:ins_race_place, { :n => 1 }], [:ins_race_left, { :n => 10 }],
                      [:ins_race_wall_left, { :n => 6, :gap => 1 }]), race.info
    step(4, 11)
    assert_equal line([:ins_race_place, { :n => 1 }], [:ins_race_left, { :n => 10 }], [:ins_race_clear, {}]), race.info
  end

  test "the race runs once a map frame after the announcer's go, and off the tracks it is quiet and forgotten" do
    track(OPEN)
    $game_switches[137] = false
    tick
    assert_nothing_spoken "before the go"
    $game_switches[137] = true
    tick
    assert_equal [[t(:ins_race_start, :n => 10), true]], SpeakCapture.log
    SpeakCapture.clear
    race.poll
    assert_nothing_spoken "the same map frame"
    $game_map.map_id = 270
    tick
    assert_nothing_spoken "back on the Sonata Tracks"
    refute race.racing?
    $game_map.map_id = TRACK
    $game_switches[136] = false
    refute race.racing?
    $game_switches[136] = true
    assert race.racing?
    tick
    assert_equal [[t(:ins_race_start, :n => 10), true]], SpeakCapture.log
  end

  test "a message on screen holds the race's news" do
    track(OPEN)
    $game_temp.message_window_showing = true
    tick
    assert_nothing_spoken
    $game_temp.message_window_showing = false
    tick
    assert_equal [[t(:ins_race_start, :n => 10), true]], SpeakCapture.log
  end

  private

  def race
    PokeAccess::InsurgenceRace
  end

  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # Lines joined as the reader joins its parts.
  def line(*parts)
    PokeAccess.sentences(parts.map { |k, v| t(k, v) })
  end

  # Puts the race on a track drawn as rows, the player at the '@' facing north, the finish line along row 1, the race
  # running.
  def track(rows)
    world = RaceWorld.new(rows, TRACK)
    $game_map = world
    (1..9).each { |x| finish(x, 1) }
    $game_player = TileWorldPlayer.new(world.start[0], world.start[1])
    $game_player.direction = 8
    $game_switches[136] = true
    $game_switches[137] = true
    $game_variables[63] = [0, 0, 0, 0]
    PokeAccess::Pathfinder.invalidate_cache(true)
    PokeAccess::World::Epoch.touch(:tiles)
    SpeakCapture.clear
    world
  end

  # Moves the player to (x, y) and runs a frame of the race.
  def step(x, y)
    $game_player.x = x
    $game_player.y = y
    World.next_frame
    race.update
  end

  # A new map frame, polled.
  def tick
    PokeAccess::Frame.instance_variable_set(:@serial, PokeAccess::Frame.serial + 1)
    World.next_frame
    race.poll
  end

  def placed(id, x, y, name)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [TestPage.new(:through => true)])
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def boost(x, y); placed(100 + x * 20 + y, x, y, "Speed_Boost"); end

  def ramp(x, y); placed(400 + x * 20 + y, x, y, "RAMP"); end

  def finish(x, y); placed(700 + x, x, y, "Finish"); end

  # A rival, which stands in the way as the game's racers do.
  def rival(id, x, y)
    ev = placed(id, x, y, "Racer_2")
    ev.blocking = true
    ev
  end
end

# The Insurgence profile loaded whole, in a process of its own: what races.rb registers beside its module, the hold on
# the mod's cues while the race runs, the info key's owner and the poll each map frame.
class InsurgenceRaceProfileTest < ProfileProcessTest
  WORLD = <<-'RUBY'
    $VERBOSE = nil
    require File.join(Harness::ROOT, "test", "support", "tile_world")
    require File.join(Harness::ROOT, "test", "support", "world_builder")
  RUBY

  # An open track on Flower Fields' map, the finish line on row 1 and the player ten rows south of it; then a map frame
  # polled, the race on and off.
  PLAY = <<-'RUBY'
    def race_track
      rows = ["#####"] + Array.new(12) { "#...#" } + ["#####"]
      $game_map = TileWorld.new(rows, 274)
      (1..3).each do |x|
        $game_map.events[700 + x] = TestGameEvent.new(:id => 700 + x, :x => x, :y => 1, :name => "Finish",
                                                      :pages => [TestPage.new(:through => true)])
      end
      $game_player = TileWorldPlayer.new(2, 11)
      $game_switches[136] = true
      $game_switches[137] = true
      $game_variables[63] = [0, 0, 0, 0]
      PokeAccess::World::Epoch.dirty!
    end

    def map_frame
      PokeAccess::Frame.instance_variable_set(:@serial, PokeAccess::Frame.serial + 1)
      PokeAccess::World::Epoch.dirty!
      PokeAccess::Frame.run_pollers
    end

    race_track
    probe(:hold) { PokeAccess::Control.reason(:hold) }
    probe(:keys) { PokeAccess::Control.reason(:keys) }
    probe(:polled) { said { map_frame } }
    probe(:start_line) { PokeAccess::I18n.t(:ins_race_start, :n => 10) }
    probe(:info) { [PokeAccess::Info.map_text, PokeAccess::InsurgenceRace.info] }
    $game_switches[136] = false
    probe(:hold_off) { PokeAccess::Control.reason(:hold) }
    probe(:info_off) { PokeAccess::InsurgenceRace.info }
    probe(:polled_off) { said { map_frame } }
  RUBY

  profile "insurgence", WORLD, PLAY

  test "while the race runs the mod's cues, guides and soundscape hold, and the locator keys stay free" do
    assert_equal :insurgence_race, played(:hold)
    assert_nil played(:keys)
  end

  test "a map frame polls the race, which opens with the finish line" do
    assert_equal [[played(:start_line), true]], played(:polled)
  end

  test "the info key on the track says the race's line" do
    map_text, race_line = played(:info)
    refute_nil race_line
    assert_equal race_line, map_text
  end

  test "off the race nothing is held, owned or said" do
    assert_nil played(:hold_off)
    assert_nil played(:info_off)
    assert_equal [], played(:polled_off)
  end
end
