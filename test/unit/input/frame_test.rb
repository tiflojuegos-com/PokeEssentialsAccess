# The two beats. The map frame runs one ordered table, by stage and then order number whatever the load order, each
# step guarded and only the sound stage while the mod is not listening, and asks control once per frame and scope;
# the pulse, which Input.update runs after the engine's own, takes the keyboard's picture and runs every poller, and
# pulses that run on with no map frame stall the map.
class FrameTest < PokeAccessTest
  Frame = PokeAccess::Frame
  Control = PokeAccess::Control

  # A key none of the mod's keys is bound to, held across pulses.
  FREE_KEY = 0x51

  test "the core's map frame runs the world, control, navigation and sound steps in this order" do
    want = [[:world, [:map_change, :teleport, :forced_move, :event_end, :battle_end, :info]],
            [:control, [:control]],
            [:nav, [:listener, :feedback, :held_carry, :surfaces, :guide, :puzzles, :keys, :regions, :hpa]],
            [:sound, [:soundscape]]]
    assert_equal want, [:world, :control, :nav, :sound].map { |s| [s, Frame.steps_of(s)] }
  end

  test "runs its steps by stage, then by order number, ties in registration order" do
    ran = []
    isolated_frame do
      Frame.step(:sound, 10, :spec_sound) { ran.push(:sound) }
      Frame.step(:nav, 20, :spec_late) { ran.push(:late) }
      Frame.step(:control, 10, :spec_control) { ran.push(:control) }
      Frame.step(:nav, 10, :spec_early) { ran.push(:early) }
      Frame.step(:nav, 20, :spec_tie) { ran.push(:tie) }
      Frame.step(:world, 50, :spec_world) { ran.push(:world) }
      Frame.run
    end
    assert_equal [:world, :control, :early, :late, :tie, :sound], ran
  end

  test "a name registered again replaces its step, which then counts as registered last" do
    ran = []
    order = isolated_frame do
      Frame.step(:nav, 20, :spec_late) { ran.push(:late) }
      Frame.step(:nav, 20, :spec_tie) { ran.push(:tie) }
      Frame.step(:nav, 20, :spec_late) { ran.push(:late_again) }
      Frame.run
      Frame.steps_of(:nav)
    end
    assert_equal [[:spec_tie, :spec_late], [:tie, :late_again]], [order, ran]
  end

  test "a step that fails on every frame is skipped each time, the frame running on and ending" do
    ran = []
    running = isolated_frame do
      Frame.step(:nav, 10, :spec_boom) { raise "the step fails" }
      Frame.step(:nav, 20, :spec_after) { ran.push(:after) }
      Frame.step(:sound, 10, :spec_sound) { ran.push(:sound) }
      2.times { Frame.run }
      Frame.running?
    end
    assert_equal [[:after, :sound, :after, :sound], false], [ran, running]
  end

  test "with the mod not listening on the map, only the sound stage runs" do
    ran = []
    isolated_frame do
      [:world, :control, :nav, :sound].each { |stage| Frame.step(stage, 10, :"spec_#{stage}") { ran.push(stage) } }
      without_player { Frame.run }
    end
    assert_equal [:sound], ran
  end

  test "counts one map frame per run" do
    before = Frame.serial
    isolated_frame { Frame.run }
    assert_equal before + 1, Frame.serial
  end

  test "the pulse runs every poller, one that raises not stopping the next" do
    ran = []
    isolated_frame do
      Frame.each_pulse { raise "the poller fails" }
      Frame.each_pulse { ran.push(:next) }
      Frame.pulse
    end
    assert_equal [:next], ran
  end

  test "a pulse job that raises does not stop the rest of the pulse" do
    ran = []
    isolated_frame do
      Frame.each_pulse { ran.push(:poller) }
      swapping(PokeAccess::Remap, :update, proc { |*_a| raise "the remap fails" }) do
        swapping(PokeAccess::Keys, :global_poll, proc { |*_a| raise "the poll fails" }) { Frame.pulse }
      end
    end
    assert_equal [:poller], ran
  end

  test "a pulse is no map frame: its pollers run outside one, and it counts none" do
    inside = []
    serial = Frame.serial
    isolated_frame do
      Frame.each_pulse { inside.push(Frame.running?) }
      Frame.pulse
    end
    assert_equal [[false], serial], [inside, Frame.serial]
  end

  test "each pulse takes the keyboard's picture first, so a key held across pulses is pressed once" do
    pressed = []
    held = []
    isolated_frame do
      Frame.each_pulse { pressed.push(PokeAccess::Keyboard.pressed?(FREE_KEY)) }
      swapping(PokeAccess::Keyboard, :raw_down?, proc { |vk| held.include?(vk) }) do
        Frame.pulse
        held.push(FREE_KEY)
        2.times { Frame.pulse }
      end
    end
    assert_equal [false, true, false], pressed
  ensure
    2.times { PokeAccess::Keyboard.snapshot }
  end

  test "a map frame and a pulse each mark the world unsettled" do
    epoch = PokeAccess::World::Epoch
    counts = isolated_frame do
      start = epoch.frame
      Frame.run
      after_run = epoch.frame
      Frame.pulse
      [after_run - start, epoch.frame - after_run]
    end
    assert_equal [1, 1], counts
  end

  test "inside a map frame control is asked once per scope, and afresh after a pushed change" do
    seen = []
    isolated_frame do
      Frame.step(:sound, 10, :spec_probe) do
        seen.push(Control.reason(:hold))
        $game_temp.message_window_showing = true
        seen.push(Control.reason(:hold))
        Control.changed!
        seen.push(Control.reason(:hold))
        $game_temp.message_window_showing = false
        $game_temp.in_menu = true
        seen.push(Control.reason(:hold))
      end
      temp_flags(:message_window_showing => false, :in_menu => false) { Frame.run }
    end
    assert_equal [nil, nil, :message, :in_menu], seen, "the menu flag's setter pushes its own change"
  end

  test "each map frame asks control afresh" do
    seen = []
    isolated_frame do
      Frame.step(:sound, 10, :spec_probe) { seen.push(Control.reason(:hold)) }
      Frame.run
      temp_flags(:message_window_showing => true) { Frame.run }
    end
    assert_equal [nil, :message], seen
  end

  test "outside a map frame control is asked afresh every time" do
    first = Control.reason(:hold)
    second = temp_flags(:message_window_showing => true) { Control.reason(:hold) }
    assert_equal [nil, :message], [first, second]
  end

  # A key handled in a map frame's step can open a modal loop (a name entry) that pulses while that frame still runs.
  test "a modal loop opened from a map frame's step asks control afresh on each pulse" do
    seen = []
    isolated_frame do
      Frame.step(:nav, 10, :spec_modal) do
        seen.push(Control.reason(:hold))
        $game_temp.message_window_showing = true
        Frame.pulse
        seen.push(Control.reason(:hold))
      end
      temp_flags(:message_window_showing => false) { Frame.run }
    end
    assert_equal [nil, :message], seen
  end

  # A screen with its own loop over the map (Uranium's pause menu, a text log, a fly map) pulses with no map frame and
  # raises no flag.
  test "pulses that run on with no map frame stall the map until the next map frame" do
    seen = []
    fired = isolated_frame do
      Frame.step(:control, 10, :spec_control) { Control.evaluate }
      Frame.run
      transitions do |log|
        (Frame::STALL_PULSES - 1).times { Frame.pulse }
        seen.push([scopes, log.length])
        Frame.pulse
        seen.push([scopes, log.length])
        Frame.pulse
        seen.push([scopes, log.length])
        Frame.run
        seen.push([scopes, log.length])
      end
    end
    assert_equal [[[nil, nil], 0], [[:stalled, :stalled], 1], [[:stalled, :stalled], 1], [[nil, nil], 2]], seen,
                 "a few pulses are no stall; past the margin both scopes are stalled, the loss fired by that pulse once"
    assert_equal [[:lost, :stalled], [:regained, :stalled]], fired, "and the next map frame lets go"
  end

  test "the listener and the regions follow the player only while control is free" do
    free = following { Frame.run_stage(:nav) }
    held = Control.hold(:spec_screen) { following { Frame.run_stage(:nav) } }
    assert_equal [[:listener, :regions], []], [free, held]
  end

  test "Input.update runs the engine's own update, then the pulse, and answers what the engine answered" do
    order = []
    got = isolated_frame do
      Frame.each_pulse { order.push(:pulse) }
      swapping(Input, :update__access_orig, proc { |*_a| order.push(:engine); :engine_answer }) { Input.update }
    end
    assert_equal [:engine_answer, [:engine, :pulse]], [got, order]
  end

  test "a pulse that raises never breaks the engine's Input.update" do
    got = swapping(Input, :update__access_orig, proc { |*_a| :engine_answer }) do
      swapping(Frame, :pulse, proc { |*_a| raise "the pulse fails" }) { Input.update }
    end
    assert_equal :engine_answer, got
  end

  private

  # The reasons that hold the player now, for the cues and for the locator keys.
  def scopes
    [Control.reason(:hold), Control.reason(:keys)]
  end

  # The block's value with the frame's table and pollers emptied for it, the real ones put back after.
  def isolated_frame
    steps = Frame.instance_variable_get(:@steps)
    pollers = Frame.instance_variable_get(:@pollers)
    Frame.instance_variable_set(:@steps, {})
    Frame.instance_variable_set(:@pollers, [])
    yield
  ensure
    Frame.instance_variable_set(:@steps, steps)
    Frame.instance_variable_set(:@pollers, pollers)
  end

  # The control transitions the block fires, as [:lost or :regained, reason]; the block gets the list as it grows.
  def transitions
    seen = []
    lost = proc { |r| seen.push([:lost, r]) }
    regained = proc { |r| seen.push([:regained, r]) }
    PokeAccess::Events.on(:control_lost, &lost)
    PokeAccess::Events.on(:control_regained, &regained)
    yield seen
    seen
  ensure
    handlers = PokeAccess::Events.instance_variable_get(:@handlers)
    (handlers[:control_lost] || []).reject! { |h| h.equal?(lost) }
    (handlers[:control_regained] || []).reject! { |h| h.equal?(regained) }
  end

  # Which of the listener's move and the regions' walk the block ran, the real ones put back after.
  def following
    ran = []
    swapping(PokeAccess::Sound, :follow_player, proc { |*_a| ran.push(:listener) }) do
      swapping(PokeAccess::Routes::Regions, :tick, proc { |*_a| ran.push(:regions) }) { yield }
    end
    ran
  end

  # The block's value with mod's own method meth answering as body does, the method put back after.
  def swapping(mod, meth, body)
    sc = mod.singleton_class
    saved = :"frame_test_saved_#{meth.to_s.delete('?!')}"
    sc.send(:alias_method, saved, meth)
    mod.define_singleton_method(meth, &body)
    yield
  ensure
    if sc && sc.method_defined?(saved)
      sc.send(:alias_method, meth, saved)
      sc.send(:remove_method, saved)
    end
  end

  # The block's value with no player, the player put back after.
  def without_player
    was = $game_player
    $game_player = nil
    yield
  ensure
    $game_player = was
  end

  # The block's value with $game_temp's flags set as given, each put back after through its setter.
  def temp_flags(flags)
    was = flags.keys.map { |f| [f, $game_temp.send(f)] }
    flags.each { |f, v| $game_temp.send("#{f}=", v) }
    yield
  ensure
    (was || []).each { |f, v| $game_temp.send("#{f}=", v) }
  end
end
