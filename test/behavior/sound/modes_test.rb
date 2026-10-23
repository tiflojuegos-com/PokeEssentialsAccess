# What a soundscape frame (Sound::Scheduler.tick) leaves playing per sound_nav mode, under a message, with the mod off
# and over an ice slide; which step plays, and where the one-shot cues (Sound.cue) play, against a shadow of the dll.
class ModesTest < PokeAccessTest
  Scheduler = PokeAccess::Sound::Scheduler
  Sound = PokeAccess::Sound
  Scene = PokeAccess::Sound::Scene
  # A corridor one tile high, the player at its west end.
  CORRIDOR = ["#########",
              "#@......#",
              "#########"]
  # The corridor with water at its east end, in the sonar's range: a full frame leaves the water loop playing.
  SHORE = ["#########",
           "#@.....~#",
           "#########"]
  # A sea with land at its west end (afloat_at_sea puts the player on the water at (7, 1)).
  SEA = ["##########",
         "#..~~~~~~#",
         "##########"]

  test "sound_nav reads as three distinct modes" do
    { :full => [true, false], :basic => [false, false], :off => [false, true] }.each do |mode, (full, off)|
      PokeAccess::Config.sound_nav = mode
      assert_equal [full, off], [Scheduler.nav_full?, Scheduler.nav_off?], "#{mode}: full, off"
    end
  end

  test "in full mode a frame pings the person, blows a wind toward each near wall and stops the water" do
    in_corridor do |dll, sch|
      sch.tick
      assert_equal [1, 1, 0, 1, 1, 0], dll.states.values_at(:npc, :wind_n, :wind_e, :wind_s, :wind_w, :water),
                   "the person, the winds north, east, south and west, and the water"
      assert_equal true, Scheduler.active?
    end
  end

  test "in full mode a frame plays the water loop on the nearest water in range, at the water's volume" do
    PokeAccess::Config.audio3d_water = 40
    in_corridor(SHORE) do |dll, sch|
      sch.tick
      assert_equal [[:water, 7, 1, 40]], dll.played.select { |id, _x, _y, _vol| id == :water }
    end
  end

  test "afloat a frame plays the shore's cue on the nearest land, the water kept on the player" do
    afloat_at_sea do |dll, sch|
      sch.tick
      assert_equal [[:water, 7, 1, 70], [:shore, 2, 1, 40]], shore_and_water(dll), "the land five tiles west"
    end
  end

  test "afloat the shore's volume row sets its cue's volume" do
    PokeAccess::Config.audio3d_shore = 25
    afloat_at_sea do |dll, sch|
      sch.tick
      assert_equal [[:water, 7, 1, 70], [:shore, 2, 1, 25]], shore_and_water(dll)
    end
  end

  test "on land a frame plays no shore's cue" do
    in_corridor(SHORE) do |dll, sch|
      sch.tick
      assert_equal [[:water, 7, 1, 70]], shore_and_water(dll)
    end
  end

  test "afloat with the surf's sound reverted a frame plays no shore's cue, the water as it was" do
    PokeAccess::Config.revert_surf_sound = true
    afloat_at_sea do |dll, sch|
      sch.tick
      assert_equal [[:water, 7, 1, 70]], shore_and_water(dll)
    end
  end

  test "a frame of the soundscape leaves the listener to the navigation stage" do
    in_corridor do |dll, sch|
      sch.tick
      assert_equal [], dll.args(:listener)
    end
  end

  test "in basic mode a frame stops every emitter and ambience, keeping the engine for steps and bumps" do
    in_corridor(SHORE) do |dll, sch|
      sch.tick
      PokeAccess::Config.sound_nav = :basic
      sch.tick
      st = dll.states
      assert_equal [], ambience_ids.reject { |id| st[id] == 0 }, "every emitter and ambience channel is stopped"
      assert_equal({}, Scene.emitters, "nothing is left read to ping next frame")
      assert_nil st[:step], "the step's channel is never touched"
      assert_equal true, Scheduler.active?, "the engine stays up, so steps and bumps still pan"
    end
  end

  test "in off mode a frame stops every channel, the steps' included, and the soundscape goes inactive" do
    in_corridor do |dll, sch|
      sch.tick
      PokeAccess::Config.sound_nav = :off
      sch.tick
      assert_equal [], still_playing(dll)
      assert_equal false, Scheduler.active?
    end
  end

  test "the step's frame puts the listener on the new tile before the step plays there" do
    with_trainer do
      with_sound_engine do |dll|
        $game_map.load_grid(["######", "#@...#", "######"])
        PokeAccess::Frame.run_stage(:nav)
        dll.log.clear
        $game_player.x = 2
        PokeAccess::Frame.run_stage(:nav)
        assert_equal [[:listener, 2, 1], [:step, 2, 1]], placements(dll)
      end
    end
  end

  test "a step plays the water's sound afloat or diving, the grass's on grass and the ground's elsewhere" do
    { :surfing => :fstep_water, :diving => :fstep_water, :grass => :grass, :ground => :step }.each do |where, sound|
      $PokemonGlobal.surfing = where == :surfing
      $PokemonGlobal.diving = where == :diving
      $game_map.set_terrain(6, 5, where == :grass ? 2 : 0)
      with_sound_engine do |dll|
        walk([5, 5], [6, 5])
        assert_equal [sound], dll.played.map(&:first), where.to_s
      end
    end
  end

  test "a step plays whichever way the player moves" do
    { [5, 4] => "north", [5, 6] => "south", [4, 5] => "west" }.each do |tile, way|
      with_sound_engine do |dll|
        walk([5, 5], tile)
        assert_equal [:step], dll.played.map(&:first), way
      end
    end
  end

  test "a step plays once on arriving at a tile, a frame that stays on it playing none" do
    with_sound_engine do |dll|
      walk([5, 5], [6, 5], [6, 5])
      assert_equal [:step], dll.played.map(&:first)
    end
  end

  test "a step on land plays the ground's sound in a game whose global state has no diving" do
    with_sound_engine do |dll|
      without_diving { walk([5, 5], [6, 5]) }
      assert_equal [:step], dll.played.map(&:first)
    end
  end

  test "with sound navigation off a step plays nothing" do
    PokeAccess::Config.sound_nav = :off
    with_sound_engine do |dll|
      walk([5, 5], [6, 5])
      assert_equal [], dll.played
    end
  end

  test "silencing the emitters stops the pings and the ambience and spares the steps', bumps' and guide's channels" do
    in_corridor(SHORE) do |dll, sch|
      sch.tick
      Scheduler.silence_emitters
      st = dll.states
      assert_equal [], ambience_ids.reject { |id| st[id] == 0 }, "every kind the sonar pings, the water and the winds"
      assert_equal [], [:step, :grass, :fstep_water, :wall, :interact, :guide].reject { |id| st[id].nil? },
                   "the steps', bumps' and guide's channels are left alone"
      assert_equal({}, Scene.emitters, "the emitters read are dropped")
    end
  end

  test "after the emitters are silenced, the next full frame reads the scene again without a step" do
    in_corridor do |_dll, sch|
      sch.tick
      Scheduler.silence_emitters
      sch.tick
      assert_equal [[4, 1]], Scene.emitters[:npc]
    end
  end

  test "a message on screen stops every channel, the soundscape inactive and the reason counted" do
    in_corridor do |dll, sch|
      sch.tick
      Scheduler.gate_report
      with_message { sch.tick }
      assert_equal [], still_playing(dll)
      assert_equal false, Scheduler.active?
      assert_equal "0/1 playing by=message:1", Scheduler.gate_report, "the diagnostic's count"
    end
  end

  test "the first bump after a message closes plays through the engine" do
    PokeAccess::Config.wall_volume = 64
    in_corridor do |dll, sch|
      with_message { sch.tick }
      dll.log.clear
      assert_equal :engine, Sound.cue(:wall, :dir => 4)
      assert_equal [[:wall, 0, 1, 64]], dll.played
    end
  end

  test "switched off with Ctrl+Alt+F8, the soundscape stops every channel and stays quiet" do
    in_corridor do |dll, sch|
      sch.tick
      Scheduler.gate_report
      with_mod_off do
        sch.tick
        assert_equal [], still_playing(dll), "every channel is stopped"
        assert_equal false, Scheduler.active?
        assert_equal "0/1 playing by=mod_off:1", Scheduler.gate_report, "the diagnostic's count"
        dll.log.clear
        sch.tick
        assert_equal [], dll.log, "a frame with the mod off orders nothing"
      end
    end
  end

  test "switched back on, the soundscape reads the scene where the player stands without a step" do
    in_corridor do |dll, sch, npc|
      sch.tick
      with_mod_off { sch.tick }
      npc.x = 6
      sch.tick
      assert_equal [[6, 1]], Scene.emitters[:npc], "the person who moved meanwhile is where she is now"
      assert_equal 1, dll.states[:wind_w], "and the wall beside the player blows its wind again"
    end
  end

  test "switched back on, the person pings again once her pace comes round" do
    PokeAccess::Config.audio3d_npc = 66
    in_corridor do |dll, sch|
      sch.tick
      with_mod_off { sch.tick }
      sch.tick
      paces_come_round
      dll.log.clear
      sch.tick
      assert_equal [[:npc, 4, 1, 66]], dll.played
    end
  end

  test "an ice slide is read where it stops, not on the tiles it carries the player over" do
    PokeAccess::Config.audio3d_range = 2
    with_trainer do
      with_sound_engine do
        with_soundscape do |sch, _sc|
          $game_map.load_grid(["##########", "#@.......#", "##########"])
          (2..6).each { |x| $game_map.set_terrain(x, 1, 12) }
          World.event(:kind => :trainer, :id => 1, :x => 4, :y => 1)
          World.event(:kind => :trainer, :id => 2, :x => 8, :y => 1)
          sch.tick
          with_slide do
            [2, 3, 4].each { |x| $game_player.x = x; sch.tick }
            assert_nil Scene.emitters[:npc], "carried over the ice, the reading stays where the slide began"
          end
          $game_player.x = 7
          sch.tick
          assert_equal [[8, 1]], Scene.emitters[:npc], "read once where the slide stops"
        end
      end
    end
  end

  test "a bump plays one tile toward the push, at the wall volume" do
    PokeAccess::Config.wall_volume = 64
    with_sound_engine do |dll|
      { 6 => [6, 5], 4 => [4, 5], 8 => [5, 4], 2 => [5, 6] }.each do |dir, (x, y)|
        dll.log.clear
        assert_equal :engine, Sound.cue(:wall, :dir => dir), "toward #{dir}"
        assert_equal [[:wall, x, y, 64]], dll.played, "toward #{dir}"
      end
    end
  end

  test "bumping into something to interact with plays the interact cue on its tile" do
    PokeAccess::Config.wall_volume = 64
    with_sound_engine do |dll|
      assert_equal :engine, Sound.cue(:interact, :dir => 4)
      assert_equal [[:interact, 4, 5, 64]], dll.played
    end
  end

  test "a cue plays nothing at volume 0 and plays at volume 1" do
    { 0 => [false, []], 1 => [:engine, [[:wall, 6, 5, 1]]] }.each do |volume, (answer, played)|
      PokeAccess::Config.wall_volume = volume
      with_sound_engine do |dll|
        assert_equal answer, Sound.cue(:wall, :dir => 6), "at volume #{volume}"
        assert_equal played, dll.played, "at volume #{volume}"
      end
    end
  end

  test "the guide's chime plays guide_distance tiles to the left or right" do
    PokeAccess::Config.guide_distance = 4
    with_sound_engine do |dll|
      { 6 => [9, 5], 4 => [1, 5] }.each do |dir, (x, y)|
        dll.log.clear
        assert_equal :engine, Sound.cue(:guide, :dir => dir, :vol => 70), "toward #{dir}"
        assert_equal [[:guide, x, y, 70]], dll.played, "toward #{dir}"
      end
    end
  end

  test "with sound navigation off, the guide plays flat and holds no tone, though the engine was started before" do
    PokeAccess::Config.guide_distance = 4
    with_sound_engine do |dll|
      PokeAccess::Config.sound_nav = :off
      held = nil
      plays = flat_plays do
        assert_equal :flat, Sound.cue(:guide, :dir => 6, :vol => 70)
        held = Sound.hold(:guide_hold, :dir => 6, :vol => 70)
      end
      assert_equal [[["pa_guide_r", 70, 100]], false, []], [plays, held, dll.played]
    end
  end

  test "a guide distance of zero is held to one tile, never onto the player" do
    PokeAccess::Config.guide_distance = 0
    with_sound_engine do |dll|
      Sound.cue(:guide, :dir => 6, :vol => 70)
      assert_equal [[:guide, 6, 5, 70]], dll.played
    end
  end

  test "a step plays on the player's own tile at the step volume" do
    PokeAccess::Config.footstep_volume = 55
    with_sound_engine do |dll|
      assert_equal :engine, Sound.cue(:grass)
      assert_equal [[:grass, 5, 5, 55]], dll.played
    end
  end

  test "a sound the catalog does not have plays nothing, whatever volume it is given" do
    with_sound_engine do |dll|
      assert_equal false, Sound.cue(:nope)
      assert_equal false, Sound.cue(:nope, :dir => 6, :vol => 50)
      assert_equal [], dll.log
    end
  end

  test "without the engine, a bump plays its pre-panned file toward the push" do
    PokeAccess::Config.wall_volume = 64
    with_sound_engine(false) do
      plays = flat_plays do
        [4, 6, 8, 2].each { |dir| assert_equal :flat, Sound.cue(:wall, :dir => dir), "toward #{dir}" }
      end
      assert_equal [["pa3d_wall_l", 64, 100], ["pa3d_wall_r", 64, 100],
                    ["pa3d_wall_c", 64, 120], ["pa3d_wall_c", 64, 80]], plays, "west, east, ahead high and behind low"
    end
  end

  test "an ice slide that leaves control free plays the step onto the ice and none on the tiles slid" do
    with_sound_engine do |dll|
      walk([5, 5], [5, 6])
      with_v21_slide do
        [[5, 7], [5, 8]].each do |x, y|
          $game_player.x = x
          $game_player.y = y
          PokeAccess::Sound::Feedback.footstep
        end
      end
      assert_equal [[:step, 5, 6, 80]], dll.played
    end
  end

  test "a move the game makes while it holds control plays no step when control returns" do
    with_sound_engine do |dll|
      walk([5, 5])
      PokeAccess::Events.emit(:control_lost, :message)
      $game_player.y = 9
      PokeAccess::Sound::Feedback.footstep
      assert_equal [], dll.played
    end
  end

  test "without the engine, steps alternate between their full pitch and nine tenths of it" do
    PokeAccess::Config.footstep_volume = 55
    with_sound_engine(false) do
      plays = flat_plays { 3.times { Sound.cue(:step) } }
      assert_equal [["pa_step", 55]] * 3, plays.map { |file, vol, _p| [file, vol] }
      assert_includes [[100, 90, 100], [90, 100, 90]], plays.map { |_f, _v, pitch| pitch }
    end
  end

  private

  # Runs the block (given the dll's shadow, the scheduler and the person) on the corridor grid with a person three
  # tiles east of the player, a trainer standing in for the game's, the engine booted and the soundscape fresh.
  def in_corridor(grid = CORRIDOR)
    with_trainer do
      with_sound_engine do |dll|
        with_soundscape do |sch, _sc|
          $game_map.load_grid(grid)
          npc = World.event(:kind => :trainer, :id => 1, :x => 4, :y => 1)
          npc.character_name = "ana"
          yield dll, sch, npc
        end
      end
    end
  end

  # Runs the block as in_corridor on SEA, the player surfing on the water five tiles east of the land.
  def afloat_at_sea
    in_corridor(SEA) do |dll, sch|
      $game_player.x = 7
      $game_player.y = 1
      $PokemonGlobal.surfing = true
      yield dll, sch
    end
  end

  # The water loop and the shore's cue the engine was told to play, as [sound, x, y, volume].
  def shore_and_water(dll)
    dll.played.select { |id, _x, _y, _vol| id == :water || id == :shore }
  end

  # Runs the block with a trainer standing in for the game's: with none, the appearance screen holds control.
  def with_trainer
    trainer = $Trainer
    $Trainer = Object.new
    yield
  ensure
    $Trainer = trainer
  end

  # Runs the block with a message on screen.
  def with_message
    $game_temp.message_window_showing = true
    yield
  ensure
    $game_temp.message_window_showing = nil
  end

  # Runs the block with the mod switched off, as Ctrl+Alt+F8 leaves it.
  def with_mod_off
    keys = PokeAccess::Keys
    enabled = keys.instance_variable_get(:@enabled)
    keys.instance_variable_set(:@enabled, false)
    yield
  ensure
    keys.instance_variable_set(:@enabled, enabled)
  end

  # Runs the block with $PokemonGlobal.diving raising, as in a game whose global state has none.
  def without_diving
    orig = $PokemonGlobal.method(:diving)
    $PokemonGlobal.define_singleton_method(:diving) { raise NoMethodError, "undefined method 'diving'" }
    yield
  ensure
    $PokemonGlobal.define_singleton_method(:diving, orig)
  end

  # Runs the block with a v21 ice slide carrying the player inside the map's own update (ice_sliding, control free).
  def with_v21_slide
    g = $PokemonGlobal
    g.define_singleton_method(:ice_sliding) { true }
    yield
  ensure
    g.singleton_class.send(:remove_method, :ice_sliding)
  end

  # Runs the block with an ice slide carrying the player.
  def with_slide
    sliding = $PokemonGlobal.sliding
    $PokemonGlobal.sliding = true
    yield
  ensure
    $PokemonGlobal.sliding = sliding
  end

  # Puts the player on each [x, y] in turn, one map frame's step check (Feedback.footstep) each, from a fresh map
  # state: the first tile is only noted.
  def walk(*tiles)
    PokeAccess::Sound::Feedback.reset_map_state
    tiles.each do |x, y|
      $game_player.x = x
      $game_player.y = y
      PokeAccess::Sound::Feedback.footstep
    end
  end

  # Takes every kind's last ping back past its pace, as if the time had passed.
  def paces_come_round
    Scheduler.instance_variable_set(:@ptime, {})
    Scheduler.instance_variable_set(:@last_ping_any, nil)
  end

  # The channels whose last order was not a stop.
  def still_playing(dll)
    st = dll.states
    Sound::Pa3d.channels.keys.reject { |id| st[id] == 0 }
  end

  # Every kind the sonar pings, the water and the winds.
  def ambience_ids
    cat = Sound::Catalog
    cat.pings.map { |e| e.id } + [:water] + cat.winds.map { |e| e.id }
  end

  # The listener's moves and the sounds started, in order, as [:listener or sound, x tile, y tile].
  def placements(dll)
    u = Sound::Pa3d::TILE_UNITS
    ids = dll.ids
    dll.log.map do |name, a|
      if name == :listener
        [:listener, a[0] / u, a[1] / u]
      elsif name == :set && a[4] == 1
        [ids[a[0]], a[1] / u, a[2] / u]
      end
    end.compact
  end

  # What the flat channel played while the block ran, as [file, volume, pitch].
  def flat_plays
    played = []
    orig = Audio.method(:se_play)
    Audio.define_singleton_method(:se_play) { |*a| played.push([a[0].to_s.split("/").last, a[1], a[2]]); nil }
    yield
    played
  ensure
    Audio.define_singleton_method(:se_play, orig)
  end
end
