# Sound::Feedback on the map: the game's bump ("bump", "Player bump") swallowed at pbSEPlay while the mod's answers a
# push into a wall, the mod's bump (wall_cue), the radar's tick for what lines up in front, and the map frame (tick).
class GameBumpTest < PokeAccessTest
  Feedback = PokeAccess::Sound::Feedback
  Pa3d = PokeAccess::Sound::Pa3d
  Config = PokeAccess::Config
  # What the filter keeps of the last push, cleared for each walk and put back after.
  PUSH_STATE = [:@bump_time, :@bump_heard, :@push_seen, :@bump_dir, :@was_blocked]
  # The bump's cooldown in the walk, 20 frames: half a second, so the windows add up exactly.
  COOLDOWN = 20
  # The game's bump as pbSEPlay hands it on when it plays, and when it is swallowed.
  PLAYS = ["Player bump"]
  SWALLOWED = []
  # The radar's tick, by the file the flat channel plays.
  TICK = "pa_guide_c"
  # An RPG::AudioFile as the game hands it to pbSEPlay.
  AudioFile = Struct.new(:name)

  test "swallows either era's bump while the mod's bump answers a push into a wall" do
    with_walk_state do
      [["Player bump"], ["bump", 80, 100]].each do |args|
        assert_equal SWALLOWED, let_through { pbSEPlay(*args) }, args[0]
      end
    end
  end

  test "swallows the bump handed as an audio file or a path, whatever its folder, extension or case" do
    with_walk_state do
      [AudioFile.new("Audio/SE/Player bump.wav"), "Audio/SE/BUMP.ogg", " player BUMP "].each do |param|
        assert_equal SWALLOWED, let_through { pbSEPlay(param) }, param.inspect
      end
    end
  end

  test "lets through every other sound, names that only resemble the bump included" do
    with_walk_state do
      others = ["Cursor", "Player bump 2", "bumper", nil, AudioFile.new(nil), Object.new]
      assert_equal others, let_through { others.each { |param| pbSEPlay(param) } }
    end
  end

  test "plays the game's bump once the player asks for it back, even right after the mod's" do
    with_walk_state do
      push
      Config.game_bump = true
      assert_equal PLAYS, game_bump
    end
  end

  test "plays the game's bump on any screen but the map, even right after the mod's" do
    with_walk_state do
      push
      $scene = Object.new
      assert_equal PLAYS, game_bump
    end
  end

  test "plays the game's bump when the mod's would not be heard" do
    { :sound_nav => :off, :wall_volume => 0, :sound_wall => false }.each do |key, value|
      with_walk_state { with_setting(key, value) { assert_equal PLAYS, game_bump, "#{key} #{value.inspect}" } }
    end
  end

  test "plays the game's bump when the engine would play the mod's at a master volume of zero, paused or not" do
    [true, false].each do |active|
      with_walk_state do
        with_sound_engine do
          with_soundscape do |sch, _scene|
            sch.instance_variable_set(:@active, active)
            heard = [0, 1].map { |master| with_setting(:audio3d_volume, master) { game_bump } }
            assert_equal [PLAYS, SWALLOWED], heard, "at masters 0 and 1, the soundscape active: #{active}"
          end
        end
      end
    end
  end

  test "plays the game's bump while the mod's cues stand down" do
    [:menu, :event, :message, :mod_off, :config_menu].each do |reason|
      with_walk_state { standing_down(reason) { assert_equal PLAYS, game_bump, reason.to_s } }
    end
  end

  test "plays the game's bump against a tile the player can walk onto" do
    with_walk_state(blocked: false) { assert_equal PLAYS, game_bump }
  end

  test "plays the game's bump with no arrow held" do
    with_walk_state do
      hold_arrow(0)
      assert_equal PLAYS, game_bump
    end
  end

  test "counts an arrow the engine fails to read as none held: no bump of the mod's, and the game's plays" do
    with_walk_state do
      hold_arrow(nil)
      assert_equal [[], PLAYS], [flat_cues { push }, game_bump]
    end
  end

  test "leaves a real step to the game: no bump of the mod's, and the game's plays" do
    with_walk_state do
      stepping
      assert_equal [[], PLAYS], [flat_cues { push }, game_bump]
    end
  end

  test "takes a v21 bump's one-step animation for no step: the game's bump is swallowed and the mod's plays" do
    with_walk_state do
      stepping(true)
      assert_equal SWALLOWED, game_bump, "the push is the mod's to answer"
      assert_equal ["pa3d_wall_c"], flat_cues { push }, "and its bump plays at once"
    end
  end

  test "leaves the bump to the game when the engine fails to answer the step" do
    with_walk_state do
      $game_player.define_singleton_method(:passable?) { |_x, _y, _d| raise "engine error" }
      assert_equal [PLAYS, []], [game_bump, flat_cues { push }]
    end
  end

  test "swallows an event's bump right after the mod's, for the same push" do
    with_walk_state(real_clock: true) do
      push
      with_event_running { assert_equal SWALLOWED, game_bump }
    end
  end

  test "swallows an event's bump until the cooldown plus SAME_PUSH has passed, then plays it" do
    with_walk_state do
      push
      with_event_running do
        pass(0.5)
        held = game_bump
        pass(0.25)
        assert_equal [SWALLOWED, PLAYS], [held, game_bump], "at the cooldown, then at the cooldown plus SAME_PUSH"
      end
    end
  end

  test "keeps the same-push window at SAME_PUSH with no cooldown at all" do
    with_walk_state do
      with_setting(:bump_cooldown, 0) do
        push
        with_event_running do
          pass(0.125)
          held = game_bump
          pass(0.125)
          assert_equal [SWALLOWED, PLAYS], [held, game_bump], "half SAME_PUSH after the bump, then SAME_PUSH"
        end
      end
    end
  end

  test "swallows an event's bump just after the arrow is let go, until SAME_PUSH has passed" do
    with_walk_state do
      push
      hold_arrow(0)
      with_event_running do
        pass(0.125)
        held = game_bump
        pass(0.125)
        assert_equal [SWALLOWED, PLAYS], [held, game_bump], "half SAME_PUSH after the release, then SAME_PUSH"
      end
    end
  end

  test "plays an event's bump toward another wall than the one the mod's answered" do
    with_walk_state do
      push
      $game_player.direction = 4
      hold_arrow(4)
      with_event_running { assert_equal PLAYS, game_bump }
    end
  end

  test "lets an event's bump play after a bump of the mod's nobody heard, the engine's at a master volume of zero" do
    { 0 => PLAYS, 1 => SWALLOWED }.each do |master, want|
      with_walk_state do
        with_sound_engine do
          with_setting(:audio3d_volume, master) do
            push
            with_event_running { assert_equal want, game_bump, "master #{master}" }
          end
        end
      end
    end
  end

  test "keeps one bump heard when the engine fails to play the mod's: its flat stand-in, or else the game's" do
    with_walk_state do
      with_sound_engine do |dll|
        def dll.call(name, *args)
          raise "PA3D_Set failed" if name == :set
          super
        end
        heard = flat_cues { push } + with_event_running { game_bump }
        assert_includes [["pa3d_wall_c"], PLAYS], heard, "never no bump at all, nor two"
      end
    end
  end

  test "swallows the bump against something to interact with whose cue plays flat, even at a master volume of zero" do
    with_walk_state do
      with_sound_engine do
        Pa3d.channels[:interact] = -1
        Config.audio3d_volume = 0
        World.event(:kind => :sign, :id => 901, :x => 5, :y => 6)
        assert_equal SWALLOWED, game_bump
      end
    end
  end

  test "plays the mod's bump as a push starts, then once a cooldown while it is held" do
    with_walk_state do
      bumps = flat_cues do
        push
        pass(0.25)
        push
        pass(0.25)
        push
      end
      assert_equal ["pa3d_wall_c", "pa3d_wall_c"], bumps, "at once and at the cooldown, none between"
    end
  end

  test "plays the mod's bump at once toward a new wall, the arrow still down" do
    with_walk_state do
      bumps = flat_cues do
        push
        $game_player.direction = 4
        hold_arrow(4)
        push
      end
      assert_equal ["pa3d_wall_c", "pa3d_wall_l"], bumps
    end
  end

  test "plays the mod's bump at once on a push after the arrow was let go" do
    with_walk_state do
      bumps = flat_cues do
        push
        hold_arrow(0)
        push
        hold_arrow(2)
        push
      end
      assert_equal ["pa3d_wall_c", "pa3d_wall_c"], bumps
    end
  end

  test "plays the mod's bump at once on a push after a map change" do
    with_walk_state do
      bumps = flat_cues do
        push
        PokeAccess::Caches.reset_all
        push
      end
      assert_equal ["pa3d_wall_c", "pa3d_wall_c"], bumps
    end
  end

  test "plays no bump of the mod's with no arrow held" do
    with_walk_state do
      hold_arrow(0)
      assert_equal [], flat_cues { push }
    end
  end

  test "plays the mod's bump only with sound navigation on and the walls audible" do
    cases = { [:sound_nav, :off] => [], [:wall_volume, 0] => [], [:wall_volume, 1] => ["pa3d_wall_c"] }
    cases.each do |(key, value), want|
      with_walk_state { with_setting(key, value) { assert_equal want, flat_cues { push }, "#{key} #{value.inspect}" } }
    end
  end

  test "keeps nothing of a push its silent walls answered, so an event's bump after it plays" do
    with_walk_state do
      with_setting(:wall_volume, 0) { push }
      with_event_running { assert_equal PLAYS, game_bump }
    end
  end

  test "ticks the radar again when the player turns away and back" do
    with_player do
      World.event(:kind => :sign, :id => 7, :x => 5, :y => 6)
      ticks = flat_cues do
        Feedback.radar
        $game_player.direction = 4
        Feedback.radar
        $game_player.direction = 2
        Feedback.radar
      end
      assert_equal [TICK, TICK], ticks
    end
  end

  test "ticks the radar once for the same thing in front, faced from another tile" do
    with_player do
      World.event(:kind => :sign, :id => 7, :x => 5, :y => 6)
      ticks = flat_cues do
        Feedback.radar
        $game_player.y = 7
        $game_player.direction = 8
        Feedback.radar
      end
      assert_equal [TICK], ticks, "the sign is still the one in front"
    end
  end

  test "ticks the radar when something to interact with comes in front of the player standing still, once while it stays" do
    with_player do
      sign = World.event(:kind => :sign, :id => 7, :x => 4, :y => 6)
      ticks = flat_cues do
        Feedback.radar
        [5, 5, 6, 5].each do |x|
          sign.x = x
          World.next_frame
          Feedback.radar
        end
      end
      assert_equal [TICK, TICK], ticks, "on coming in front, none while it stays, again on coming back"
    end
  end

  test "keeps the radar silent facing nothing to interact with" do
    { "an empty tile" => nil, "a person with nothing to say" => :npc }.each do |what, kind|
      with_player do
        World.event(:kind => kind, :id => 7, :x => 5, :y => 6) if kind
        assert_equal [], flat_cues { Feedback.radar }, what
      end
    end
  end

  test "keeps the radar silent while it is off or sound navigation is not full" do
    { :proximity_radar => false, :sound_nav => :basic }.each do |key, value|
      with_player do
        World.event(:kind => :sign, :id => 7, :x => 5, :y => 6)
        with_setting(key, value) { assert_equal [], flat_cues { Feedback.radar }, "#{key} #{value.inspect}" }
      end
    end
  end

  test "ticks the radar, switched back on, for what is already in front" do
    with_player do
      World.event(:kind => :sign, :id => 7, :x => 5, :y => 6)
      ticks = flat_cues do
        Feedback.radar
        Config.proximity_radar = false
        Feedback.radar
        Config.proximity_radar = true
        Feedback.radar
      end
      assert_equal [TICK, TICK], ticks
    end
  end

  test "runs the mod's bump and the radar on a map frame with control free" do
    with_walk_state do
      World.event(:kind => :sign, :id => 901, :x => 5, :y => 6)
      assert_equal ["pa3d_interact", TICK], flat_cues { Feedback.tick }, "the bump into the sign, its own, then its tick"
    end
  end

  test "bumps apart from a wall and ticks the radar facing someone across a counter" do
    with_walk_state do
      $game_map.load_grid(["......", "......", "......", "......", "......", ".....@", ".....C", "......"])
      World.event(:kind => :sign, :id => 901, :x => 5, :y => 7)
      assert_equal ["pa3d_interact", TICK], flat_cues { Feedback.tick }, "the bump into the counter, then the tick"
    end
  end

  test "plays nothing on a map frame while control is held" do
    with_walk_state do
      World.event(:kind => :sign, :id => 901, :x => 5, :y => 6)
      with_event_running { assert_equal [], flat_cues { Feedback.tick } }
    end
  end

  test "does nothing on a map frame with no player" do
    with_walk_state do
      $game_player = nil
      assert_equal [], flat_cues { Feedback.tick }
    end
  end

  private

  # Runs the block in a wall bump's state: on the map, out of menus and messages, the arrow held the way the player
  # faces into an impassable tile (a walkable one with blocked false), the positional engine down so the mod's bump
  # plays flat, the mod's clock stopped at 100 s (running with real_clock), the bump's cooldown at COOLDOWN and
  # nothing kept of a push. Whatever it touched is put back after.
  def with_walk_state(blocked: true, real_clock: false)
    saved = [$scene, $game_player, $game_temp.in_menu, $game_temp.message_window_showing, $se_played,
             Config.bump_cooldown]
    pushed = PUSH_STATE.map { |iv| Feedback.instance_variable_get(iv) }
    PUSH_STATE.each { |iv| Feedback.instance_variable_set(iv, nil) }
    Feedback.instance_variable_set(:@was_blocked, false)
    Config.bump_cooldown = COOLDOWN
    $scene = Scene_Map.new
    $game_temp.in_menu = false
    $game_temp.message_window_showing = false
    player = Game_Player.new
    player.define_singleton_method(:passable?) { |_x, _y, _d| !blocked }
    $game_player = player
    walk = proc { real_clock ? yield : with_clock(100.0) { yield } }
    with_sound_engine(false) { with_arrow(2, &walk) }
  ensure
    $scene, $game_player, $game_temp.in_menu, $game_temp.message_window_showing, $se_played,
      Config.bump_cooldown = saved
    PUSH_STATE.each_with_index { |iv, i| Feedback.instance_variable_set(iv, pushed[i]) }
  end

  # Runs the block with a fresh player at (5, 5) facing down and the radar remembering nothing; the player is put back
  # after.
  def with_player
    was = $game_player
    $game_player = Game_Player.new
    Feedback.reset_map_state
    yield
  ensure
    $game_player = was
  end

  # Runs the block with the engine's own arrow (what Input.dir4 reads under the remapper) at @arrow[0], which
  # hold_arrow changes; the engine's method is put back after.
  def with_arrow(dir)
    held = @arrow = [dir]
    name = Input.respond_to?(:dir4__access_orig) ? :dir4__access_orig : :dir4
    real = Input.method(name)
    Input.define_singleton_method(name) { |*_args| held[0] || raise("the engine's arrow failed") }
    yield
  ensure
    Input.define_singleton_method(name, real) if real
  end

  # Holds the arrow toward dir from now on (0: none held; nil: the engine fails to read it).
  def hold_arrow(dir)
    @arrow[0] = dir
  end

  # Runs the block with the mod's clock stopped at now seconds, moved on by pass; the real clock is put back after.
  def with_clock(now)
    t = @clock = [now]
    real = PokeAccess.method(:clock)
    PokeAccess.define_singleton_method(:clock) { t[0] }
    yield
  ensure
    PokeAccess.define_singleton_method(:clock, real) if real
  end

  # Moves the stopped clock on by seconds.
  def pass(seconds)
    @clock[0] += seconds
  end

  # One map frame's look at the push (Feedback.wall_cue), which plays the mod's bump when it answers one.
  def push
    Feedback.wall_cue
  end

  # The files of the mod's cues the block plays, flat as in the walk state.
  def flat_cues
    with_cue_log do |log|
      yield
      log.map { |entry| cue_name(entry) }
    end
  end

  # What pbSEPlay hands on to the engine of the sounds the block plays.
  def let_through
    $se_played = []
    yield
    $se_played
  end

  # What pbSEPlay hands on of the game's bump played now: PLAYS or SWALLOWED.
  def game_bump
    let_through { pbSEPlay("Player bump") }
  end

  # Runs the block with a setting at value, put back after.
  def with_setting(key, value)
    was = Config.send(key)
    Config.send("#{key}=", value)
    yield
  ensure
    Config.send("#{key}=", was)
  end

  # Runs the block with one of the reasons the mod's cues stand down: a menu open over the map, an event running, a
  # message open, the mod switched off (Ctrl+Alt+F8) or the mod's own menu open; put back after.
  def standing_down(reason, &blk)
    case reason
    when :event then with_event_running(&blk)
    when :menu then with_flag($game_temp, :in_menu, &blk)
    when :message then with_flag($game_temp, :message_window_showing, &blk)
    when :mod_off then with_ivar(PokeAccess::Keys, :@enabled, false, &blk)
    when :config_menu then with_ivar(PokeAccess::ConfigMenu, :@active, true, &blk)
    end
  end

  # Runs the block with the map's interpreter running an event, its own running? put back after.
  def with_event_running
    interp = $game_system.map_interpreter
    real = interp.method(:running?)
    interp.define_singleton_method(:running?) { true }
    yield
  ensure
    interp.define_singleton_method(:running?, real) if real
  end

  # Runs the block with an engine flag raised through its writer, as the engine raises it (in_menu= tells Control at
  # once), and lowered after.
  def with_flag(obj, flag)
    obj.send("#{flag}=", true)
    yield
  ensure
    obj.send("#{flag}=", false)
  end

  # Runs the block with an object's instance variable at value, put back after.
  def with_ivar(obj, ivar, value)
    was = obj.instance_variable_get(ivar)
    obj.instance_variable_set(ivar, value)
    yield
  ensure
    obj.instance_variable_set(ivar, was)
  end

  # Makes the player take a step, or with bumping play a v21 bump's one-step animation (moving, @bumping set).
  def stepping(bumping = false)
    $game_player.define_singleton_method(:moving?) { true }
    $game_player.instance_variable_set(:@bumping, bumping)
  end
end
