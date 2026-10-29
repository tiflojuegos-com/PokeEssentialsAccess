# When and where each emitter sounds (Sound::Scheduler), against a shadow of the dll: one ping a frame and its
# occlusion, the winds and loops placed, the readings brought by events that walk, and when the frame falls silent.
class SchedulerTest < PokeAccessTest
  Scheduler = PokeAccess::Sound::Scheduler
  Scene = PokeAccess::Sound::Scene
  Config = PokeAccess::Config

  test "pings one emitter a frame, of the kind that has waited longest" do
    with_engine do |dll, sch|
      scene_with(:npc => [[4, 4]], :door => [[16, 16]])
      { [10.0, 1.0] => [[4, 4]], [1.0, 10.0] => [[16, 16]] }.each do |(people, doors), want|
        dll.log.clear
        last_pinged(sch, 100.0, :npc => people, :door => doors)
        sch.ping(100.0)
        assert_equal want, dll.tiles, "the people last pinged #{people} s ago, the doors #{doors} s ago"
      end
    end
  end

  test "lets a kind wait out its own pace after it pings" do
    Config.audio3d_freq_npc = 92
    with_engine do |dll, sch|
      scene_with(:npc => [[4, 4], [16, 16]])
      got = [10.0, 10.1, 10.25].map { |t| dll.log.clear; sch.ping(t); dll.tiles }
      assert_equal [[[4, 4]], [], [[16, 16]]], got, "a pace of a quarter second, the next person beyond the alternation"
    end
  end

  test "sends nothing for a scene with no emitter" do
    with_engine do |dll, sch|
      [{}, { :npc => [] }].each do |emitters|
        scene_with(emitters)
        sch.ping(10.0)
        assert_equal [], dll.log, "for #{emitters.inspect}"
      end
    end
  end

  test "takes the nearest few of a kind in turns, wrapping round" do
    with_engine do |dll, sch|
      scene_with(:npc => [[4, 4], [4, 12], [12, 4]])
      [10.0, 11.0, 12.0, 13.0].each { |t| sch.ping(t) }
      assert_equal [[4, 4], [4, 12], [12, 4], [4, 4]], dll.tiles
    end
  end

  test "holds back, inside the gap after a ping, an emitter within the alternation distance of it" do
    rows = [[5, [6, 9], 0.0, []], [5, [10, 9], 0.0, []], [5, [11, 9], 0.0, [[11, 9]]], [5, [5, 14], 0.0, []],
            [5, [5, 15], 0.0, [[5, 15]]], [5, [6, 9], 0.25, [[6, 9]]], [1, [7, 9], 0.0, [[7, 9]]], [1, [6, 9], 0.0, []]]
    with_engine do |dll, sch|
      rows.each_with_index do |(alt, at, ago, want), i|
        Config.audio3d_alt_dist = alt
        assert_equal want, ping_after(dll, sch, 100.0 * (i + 1), [5, 9], at, ago),
                     "#{at.inspect} #{ago} s after a ping at [5, 9], alternating within #{alt}"
      end
    end
  end

  test "muffles an emitter behind a wall in occlude mode only" do
    { [:occlude, [6, 1]] => [[:npc, 80]], [:occlude, [3, 1]] => [[:npc, 0]],
      [:hear, [6, 1]] => [[:npc, 0]], [:hide, [6, 1]] => [[:npc, 0]] }.each do |(mode, at), want|
      with_sound_engine do |dll|
        $game_map.load_grid(["#########", "#@..#...#", "#########"])
        Config.audio3d_occlusion = mode
        Scheduler.occlude(:npc, at)
        assert_equal want, dll.by_sound(:occl), "#{at.inspect} in #{mode} mode"
      end
    end
  end

  test "sends an emitter's occlusion again only when it changes" do
    with_sound_engine do |dll|
      $game_map.load_grid(["#########", "#@..#...#", "#########"])
      Config.audio3d_occlusion = :occlude
      got = [[6, 1], [6, 1], [3, 1]].map { |at| dll.log.clear; Scheduler.occlude(:npc, at); dll.by_sound(:occl) }
      assert_equal [[[:npc, 80]], [], [[:npc, 0]]], got
    end
  end

  test "muffles a ping behind a wall before it sounds on its tile" do
    with_engine do |dll, sch|
      $game_map.load_grid(["#########", "#@..#...#", "#########"])
      Config.audio3d_occlusion = :occlude
      scene_with(:npc => [[6, 1]])
      sch.ping(10.0)
      n = PokeAccess::Sound::Pa3d.channels[:npc]
      assert_equal [[:occl, [n, 80]], [:set, [n, 600, 100, 85, 1]]], dll.log
    end
  end

  test "muffles nothing with no player on the map" do
    with_sound_engine do |dll|
      Config.audio3d_occlusion = :occlude
      without_player { Scheduler.occlude(:npc, [6, 1]) }
      assert_equal [], dll.log
    end
  end

  test "places each wind on its wall at a volume falling off with the distance as set" do
    Config.audio3d_wind = 60
    { 0 => { :wind_e => [8, 5, 60], :wind_s => [5, 7, 60], :wind_w => [4, 5, 60] },
      50 => { :wind_e => [8, 5, 20], :wind_s => [5, 7, 30], :wind_w => [4, 5, 60] },
      100 => { :wind_e => [8, 5, 6], :wind_s => [5, 7, 15], :wind_w => [4, 5, 60] } }.each do |falloff, want|
      with_engine do |dll, sch|
        Config.audio3d_wall_falloff = falloff
        walls_read(:wind_n => nil, :wind_e => 3, :wind_s => 2, :wind_w => 1)
        sch.winds(5, 5)
        assert_equal want, placed(dll), "with a falloff of #{falloff}"
      end
    end
  end

  test "stops the wind of each side with no wall in range" do
    with_engine do |dll, sch|
      walls_read(:wind_n => nil, :wind_e => nil, :wind_s => nil, :wind_w => 1)
      sch.winds(5, 5)
      assert_equal [:wind_n, :wind_e, :wind_s], dll.stopped
    end
  end

  test "stops every wind switched off or at volume 0 with walls all round, and plays them from volume 1" do
    all = [:wind_n, :wind_e, :wind_s, :wind_w]
    at_one = [[:wind_n, 5, 4, 1], [:wind_e, 6, 5, 1], [:wind_s, 5, 6, 1], [:wind_w, 4, 5, 1]]
    { [false, 55] => [all, []], [true, 0] => [all, []], [true, 1] => [[], at_one] }.each do |(on, vol), want|
      with_engine do |dll, sch|
        Config.sound_wind = on
        Config.audio3d_wind = vol
        walls_read(:wind_n => 1, :wind_e => 1, :wind_s => 1, :wind_w => 1)
        sch.winds(5, 5)
        assert_equal want, [dll.stopped, dll.played], "the wind #{on ? 'on' : 'off'} at volume #{vol}"
      end
    end
  end

  test "sends a wind's order again only when it changes" do
    Config.audio3d_wind = 60
    with_engine do |dll, sch|
      walls_read(:wind_n => nil, :wind_e => 3, :wind_s => 2, :wind_w => 1)
      sch.winds(5, 5)
      dll.log.clear
      sch.winds(5, 5)
      assert_equal [], dll.log, "the same walls again send nothing"
      Config.audio3d_wall_falloff = 100
      sch.winds(5, 5)
      assert_equal [[[:wind_e, 8, 5, 6], [:wind_s, 5, 7, 15]], []], [dll.played, dll.stopped],
                   "a steeper falloff sends the farther winds alone"
    end
  end

  test "places a loop on its tile, and stops it with no tile or no volume" do
    stopped = [[], [:water]]
    rows = { [[7, 9], 44] => [[[:water, 7, 9, 44]], []], [[7, 9], 1] => [[[:water, 7, 9, 1]], []],
             [nil, 44] => stopped, [[7, 9], 0] => stopped }
    rows.each do |(at, vol), want|
      with_sound_engine do |dll|
        Scheduler.place_loop(:water, at, vol)
        assert_equal want, [dll.played, dll.stopped], "#{at.inspect} at volume #{vol}"
      end
    end
  end

  test "repeats the shore's cue every SHORE_PERIOD seconds, not every frame, and none with no shore read" do
    with_engine do |dll, sch, sc|
      sc.instance_variable_set(:@shore, [2, 1])
      times = [10.0, 11.0, 10.0 + Scheduler::SHORE_PERIOD]
      got = times.map { |t| dll.log.clear; sch.shore(t); dll.played }
      assert_equal [[[:shore, 2, 1, 40]], [], [[:shore, 2, 1, 40]]], got, "at #{times.inspect}"
      sc.instance_variable_set(:@shore, nil)
      dll.log.clear
      sch.shore(20.0)
      assert_equal [], dll.log, "with no shore in range"
    end
  end

  test "stops the water once its sound is switched off" do
    with_sound_engine do |dll|
      Config.sound_water = false
      Scheduler.place_loop(:water, [7, 9], PokeAccess::Sound::Mixer.volume(:water))
      assert_equal [[], [:water]], [dll.played, dll.stopped]
    end
  end

  test "gives no turn to a kind switched off or at volume 0, the next kind taking the frame's ping" do
    { [true, 85] => [[4, 4]], [true, 1] => [[4, 4]], [false, 85] => [[16, 16]],
      [true, 0] => [[16, 16]] }.each do |(on, vol), want|
      with_engine do |dll, sch|
        Config.sound_people = on
        Config.audio3d_npc = vol
        scene_with(:npc => [[4, 4]], :door => [[16, 16]])
        last_pinged(sch, 100.0, :npc => 10.0, :door => 1.0)
        sch.ping(100.0)
        assert_equal want, dll.tiles, "the people #{on ? 'on' : 'off'} at volume #{vol}"
      end
    end
  end

  test "reads a walker again where she went once the gap after the last reading has passed" do
    with_frame do |_dll, sch|
      she, led = two_people_read(sch)
      she.x = 8
      led.y = 9
      at_time(10.25) { sch.tick }
      assert_equal [[8, 5], [5, 9]], Scene.emitters[:npc], "her and the others where they now stand"
    end
  end

  test "reads a walker again no sooner than the gap after the last reading" do
    with_frame do |_dll, sch|
      she, _led = two_people_read(sch)
      she.x = 8
      at_time(10.2) { sch.tick }
      assert_equal [[7, 5], [5, 8]], Scene.emitters[:npc]
    end
  end

  test "reads nothing again when only a person who does not walk was moved" do
    with_frame do |_dll, sch|
      _she, led = two_people_read(sch)
      led.y = 9
      at_time(11.0) { sch.tick }
      assert_equal [[7, 5], [5, 8]], Scene.emitters[:npc]
    end
  end

  test "tells the engine a source falls silent past the sonar's range by the fade" do
    { 12 => [[14]], 20 => [[22]] }.each do |range, want|
      with_frame do |dll, sch|
        Config.audio3d_range = range
        sch.tick
        assert_equal want, dll.args(:range), "a sonar range of #{range}"
      end
    end
  end

  test "tells the engine the range again only when it changes" do
    with_frame do |dll, sch|
      sch.tick
      sch.tick
      Config.audio3d_range = 20
      sch.tick
      assert_equal [[14], [22]], dll.args(:range)
    end
  end

  test "never asks an older dll without the range, the air or the HRTF entry point for it" do
    [:range, :air, :hrtf].each do |entry|
      with_trainer do
        with_sound_engine(true, 44100, [entry]) do |dll|
          asked = asked_of(dll)
          with_soundscape { |sch| sch.tick }
          refute_includes asked, entry, "a dll without #{entry}"
        end
      end
    end
  end

  test "tells the engine whether the air absorbs distant sounds, as set" do
    { true => [[1]], false => [[0]] }.each do |on, want|
      with_frame do |dll, sch|
        Config.audio3d_air = on
        sch.tick
        assert_equal want, dll.args(:air), "with the air's absorption #{on ? 'on' : 'off'}"
      end
    end
  end

  test "tells the engine whether to spatialize through the HRTF, as set" do
    { true => [[1]], false => [[0]] }.each do |on, want|
      with_frame do |dll, sch|
        Config.audio3d_hrtf = on
        sch.tick
        assert_equal want, dll.args(:hrtf), "with the HRTF #{on ? 'on' : 'off'}"
      end
    end
  end

  test "sends the HRTF switch again only when it changes" do
    with_frame do |dll, sch|
      sch.tick
      sch.tick
      Config.audio3d_hrtf = false
      sch.tick
      assert_equal [[1], [0]], dll.args(:hrtf)
    end
  end

  test "sets the engine's master volume to the positional master volume" do
    with_frame do |dll, sch|
      Config.audio3d_volume = 35
      sch.tick
      assert_equal [[35]], dll.args(:master)
    end
  end

  test "keeps the guide's and the walls' sounds within the engine's reach under a short sonar range" do
    { [1, 3, 3] => [[5]], [4, 6, 3] => [[8]], [1, 3, 6] => [[8]] }.each do |(range, guide, walls), want|
      with_frame do |dll, sch|
        Config.audio3d_range = range
        Config.guide_distance = guide
        Config.audio3d_wall_range = walls
        sch.tick
        assert_equal want, dll.args(:range), "a sonar range of #{range}, the guide at #{guide}, walls felt at #{walls}"
      end
    end
  end

  test "plays the game's music again on the first frame the soundscape plays, once" do
    with_frame do |_dll, sch|
      with_bgm_muted do |plays|
        sch.tick
        sch.tick
        assert_equal [[:bgm, "Route"]], plays
      end
    end
  end

  test "plays again on booting what the game plays, a surf's music and background sound rather than the map's" do
    with_frame do |_dll, sch|
      with_bgm_muted("Surf", "Waves") do |plays|
        sch.tick
        assert_equal [[:bgm, "Surf"], [:bgs, "Waves"]], plays
      end
    end
  end

  test "reads the scene again when an event comes or goes near the player standing still" do
    with_frame do |_dll, sch|
      at_time(10.0) { sch.tick }
      person(1, 7, 5, "ana")
      World.next_frame
      at_time(11.0) { sch.tick }
      assert_equal [[7, 5]], Scene.emitters[:npc], "one who came"
      $game_map.events.delete(1)
      World.next_frame
      at_time(12.0) { sch.tick }
      assert_nil Scene.emitters[:npc], "and went"
    end
  end

  test "stops the guide's held tone when control is lost, whatever the sound navigation that plays it" do
    [:full, :basic].each do |nav|
      with_frame do |dll, sch|
        Config.sound_nav = nav
        sch.tick
        PokeAccess::Sound.hold(:guide_hold, :dir => 6)
        PokeAccess::Events.emit(:control_lost, :message)
        assert_equal 0, dll.states[:guide_hold], "with sound navigation #{nav}"
      end
    end
  end

  test "stops the guide's held tone when the mod is switched off" do
    with_frame do |dll, sch|
      sch.tick
      PokeAccess::Sound.hold(:guide_hold, :dir => 6)
      shut(:mod) { sch.tick }
      assert_equal 0, dll.states[:guide_hold]
    end
  end

  test "with sound navigation switched off under the guide's held tone, the next frame stops it and it starts no more" do
    with_frame do |dll, sch|
      sch.tick
      PokeAccess::Sound.hold(:guide_hold, :dir => 6)
      Config.sound_nav = :off
      sch.tick
      held = PokeAccess::Sound.hold(:guide_hold, :dir => 6)
      assert_equal [0, false], [dll.states[:guide_hold], held]
    end
  end

  test "plays the rest of the frame when one part of it fails" do
    with_frame do |dll, sch|
      person(1, 6, 5, "ana")
      failing(Scene, :read_water) { sch.tick }
      assert_equal [[6, 5]], dll.tiles, "the ping still sounds"
    end
  end

  test "plays nothing, and raises nothing, when the frame's control check fails" do
    with_frame do |dll, sch|
      person(1, 6, 5, "ana")
      silenced(dll, sch)
      failing(PokeAccess::Control, :reason) { sch.tick }
      assert_equal [false, []], [sch.active?, dll.log]
    end
  end

  test "plays nothing while the engine cannot boot" do
    with_trainer do
      with_sound_engine(false, 44100, [:init]) do |dll|
        with_soundscape do |sch|
          person(1, 6, 5, "ana")
          sch.silence_all
          sch.tick
          assert_equal [false, []], [sch.active?, dll.log]
        end
      end
    end
  end

  test "says once that positional sound is off when the engine cannot boot, never while sound navigation is off" do
    with_trainer do
      with_sound_engine(false, 44100, [:init]) do
        with_soundscape do |sch|
          PokeAccess::Config.sound_nav = :off
          sch.tick
          off = [PokeAccess::Sound::Pa3d.boot_tried?, SpeakCapture.lines.dup]
          PokeAccess::Config.sound_nav = :full
          3.times { sch.tick }
          assert_equal [[false, []], [PokeAccess::I18n.t(:audio3d_unavailable)]], [off, SpeakCapture.lines]
        end
      end
    end
  end

  test "stops every channel when the player leaves the map" do
    with_frame do |dll, sch|
      person(1, 6, 5, "ana")
      sch.tick
      without_player { sch.tick }
      assert_equal [false, []], [sch.active?, sounding(dll)]
    end
  end

  test "sends nothing on a frame that falls silent while the soundscape already is" do
    [:player, :mod, :nav].each do |gate|
      with_frame do |dll, sch|
        silenced(dll, sch)
        shut(gate) { sch.tick }
        assert_equal [], dll.log, "with the #{gate} gate shut"
      end
    end
  end

  test "falls silent when control is lost, and reads the scene afresh when it returns" do
    with_frame do |dll, sch|
      ana = person(1, 6, 5, "ana")
      sch.tick
      PokeAccess::Events.emit(:control_lost, :message)
      assert_equal [false, []], [sch.active?, sounding(dll)], "silent at once"
      ana.x = 7
      sch.tick
      assert_equal [[7, 5]], Scene.emitters[:npc], "back in control, the scene is read where things now stand"
    end
  end

  test "sends nothing when control is lost while the soundscape is silent" do
    with_frame do |dll, sch|
      silenced(dll, sch)
      PokeAccess::Events.emit(:control_lost, :message)
      assert_equal [], dll.log
    end
  end

  private

  # Runs the block on a booted shadow engine and a cleared soundscape: |dll, scheduler, scene|.
  def with_engine
    with_sound_engine { |dll| with_soundscape { |sch, sc| yield dll, sch, sc } }
  end

  # Runs the block as the map frame runs: a trainer on the map, a booted shadow engine, a cleared soundscape.
  def with_frame
    with_trainer { with_engine { |dll, sch, sc| yield dll, sch, sc } }
  end

  # Runs the block with a trainer, without whom the frame holds the soundscape.
  def with_trainer
    was = $Trainer
    $Trainer = Object.new
    yield
  ensure
    $Trainer = was
  end

  # Silences the soundscape, every channel stopped as the engine was told, and clears what it was sent.
  def silenced(dll, sch)
    sch.silence_all
    dll.log.clear
  end

  # Sets what the scene read: the emitters by kind, [[x, y], ...] nearest first.
  def scene_with(emitters)
    Scene.instance_variable_set(:@emitters, emitters)
  end

  # Sets what the scene read of the walls: each wind's distance to its wall, nil for an open side.
  def walls_read(walls)
    Scene.instance_variable_set(:@wall, walls)
  end

  # Sets how many seconds before now each kind last pinged, with no ping of any kind just before.
  def last_pinged(sch, now, ago)
    times = {}
    ago.each { |kind, s| times[kind] = now - s }
    sch.instance_variable_set(:@ptime, times)
    sch.instance_variable_set(:@last_ping_any, nil)
  end

  # The tiles a person at `at` pings with, ago seconds after a door at `last` pinged at t.
  def ping_after(dll, sch, t, last, at, ago)
    scene_with(:door => [last])
    sch.ping(t)
    dll.log.clear
    scene_with(:npc => [at])
    sch.ping(t + ago)
    dll.tiles
  end

  # Each wind placed, as { wind => [x, y, volume] }.
  def placed(dll)
    out = {}
    dll.played.each { |id, x, y, v| out[id] = [x, y, v] }
    out
  end

  # The channels whose last order was not a stop.
  def sounding(dll)
    st = dll.states
    PokeAccess::Sound::Pa3d.channels.keys.reject { |k| st[k] == 0 }
  end

  # Records every entry point the mod asks the shadow for, those it lacks included.
  def asked_of(dll)
    asked = []
    dll.define_singleton_method(:call) { |name, *args| asked.push(name); super(name, *args) }
    asked
  end

  # A person (a trainer event) at (x, y) with a sprite of her own, her page walking her about at random if walks.
  def person(id, x, y, sprite, walks = false)
    ev = World.event(:kind => :trainer, :id => id, :x => x, :y => y)
    ev.character_name = sprite
    ev.instance_variable_get(:@page).move_type = walks ? 1 : 0
    ev
  end

  # A walker at (7, 5) and a person who does not walk at (5, 8), read by a frame at 10 s: [walker, person].
  def two_people_read(sch)
    she = person(1, 7, 5, "ana", true)
    led = person(2, 5, 8, "bea")
    at_time(10.0) { sch.tick }
    [she, led]
  end

  # Runs the block with the mod's clock stopped at t seconds.
  def at_time(t)
    real = PokeAccess.method(:clock)
    PokeAccess.define_singleton_method(:clock) { t }
    yield
  ensure
    PokeAccess.define_singleton_method(:clock, real)
  end

  # Runs the block with no player on the map.
  def without_player
    was = $game_player
    $game_player = nil
    yield
  ensure
    $game_player = was
  end

  # Runs the block with one of the frame's gates shut: the :player gone, the :mod switched off or sound :nav off.
  def shut(gate)
    keys = PokeAccess::Keys
    was = [keys.enabled, Config.sound_nav, $game_player]
    keys.instance_variable_set(:@enabled, false) if gate == :mod
    Config.sound_nav = :off if gate == :nav
    $game_player = nil if gate == :player
    yield
  ensure
    keys.instance_variable_set(:@enabled, was[0])
    Config.sound_nav = was[1]
    $game_player = was[2]
  end

  # Runs the block with a module's method failing with an error.
  def failing(mod, name)
    real = mod.method(name)
    mod.define_singleton_method(name) { |*_a| raise "#{name} fails" }
    yield
  ensure
    mod.define_singleton_method(name, real)
  end

  # Runs the block as before the soundscape's first frame, the game playing bgm and bgs (nil for none) over a map whose
  # own music is another, recording each one the game is told to play (|plays|, as [:bgm or :bgs or :map, name]).
  def with_bgm_muted(bgm = "Route", bgs = nil)
    was = [Scheduler.instance_variable_get(:@bgm_restored), $game_system]
    Scheduler.instance_variable_set(:@bgm_restored, false)
    plays = []
    sys = Object.new
    sys.define_singleton_method(:playing_bgm) { bgm }
    sys.define_singleton_method(:playing_bgs) { bgs }
    sys.define_singleton_method(:bgm_play) { |b| plays.push([:bgm, b]) }
    sys.define_singleton_method(:bgs_play) { |b| plays.push([:bgs, b]) }
    $game_system = sys
    $game_map.define_singleton_method(:autoplay) { plays.push([:map, "Route"]) }
    yield plays
  ensure
    $game_map.singleton_class.send(:remove_method, :autoplay)
    Scheduler.instance_variable_set(:@bgm_restored, was[0])
    $game_system = was[1]
  end
end
