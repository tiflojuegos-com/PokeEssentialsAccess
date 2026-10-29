# RMXP's event timer (core/field/event_timer.rb): a countdown is said once, queued, as it starts, and the field key
# reads its time left while the game's timer runs, whatever the boxes show (a gen-6 map keeps a timer sprite per
# connected map and never shows a box it hid). The stand-in below holds Sprite_Timer's name only while the file's hook
# section is evaluated again, so the hook binds to it and no other test sees the sprite.

# The timer sprite in its gen-6 shape: while the game's timer runs its update counts the seconds left (@total_sec) and
# makes its box the first time; once the timer stops it hides the box, for good.
class EventTimerSprite
  Box = Struct.new(:visible)

  def update
    if PokeAccess::EventTimer.running?($game_system)
      @timer ||= Box.new(true)
      @total_sec = $game_system.timer
    elsif @timer
      @timer.visible = false
    end
    :updated
  end
end

timer_made = !Object.const_defined?(:Sprite_Timer)
Object.const_set(:Sprite_Timer, EventTimerSprite) if timer_made
begin
  timer = File.join(Harness::ROOT, "core", "field", "event_timer.rb")
  source = Harness.source(timer)
  module_end = source.index("\n", source.index(/^end\s*$/)) + 1
  eval(source[module_end..-1], TOPLEVEL_BINDING, timer, source[0, module_end].count("\n") + 1)
ensure
  Object.send(:remove_const, :Sprite_Timer) if timer_made
end

class EventTimerTest < PokeAccessTest
  # The game's timer up to v20 (the seconds left, and whether it runs) and from v21 (timer_start set while it runs).
  ClassicSystem = Struct.new(:timer, :timer_working)
  ModernSystem = Struct.new(:timer, :timer_start)

  test "a countdown is said once, queued, as it starts" do
    with_system(ClassicSystem.new(180, true)) do |sys|
      sprite = EventTimerSprite.new
      sprite.update
      sys.timer = 179
      sprite.update
    end
    assert_equal [[timer_line("3:00"), false]], SpeakCapture.log
  end

  test "a new countdown is said once with a map's sprite whose box stayed hidden beside a fresh one" do
    with_system(ClassicSystem.new(30, true)) do |sys|
      old_map = EventTimerSprite.new
      old_map.update
      sys.timer_working = false
      old_map.update
      SpeakCapture.clear
      new_map = EventTimerSprite.new
      sys.timer = 90
      sys.timer_working = true
      3.times { [old_map, new_map].each { |s| s.update } }
    end
    assert_equal [timer_line("1:30")], SpeakCapture.lines
  end

  test "the field key adds the time left while the timer runs, its box hidden or not, and leaves it out once it stops" do
    with_system(ClassicSystem.new(65, false)) do |sys|
      plain = field_key
      sprite = EventTimerSprite.new
      sys.timer_working = true
      sprite.update
      sys.timer_working = false
      sprite.update
      sys.timer_working = true
      sprite.update
      assert_equal "#{plain}, #{timer_line('1:05')}", field_key, "a box hidden for good"
      sys.timer_working = false
      sprite.update
      assert_equal plain, field_key
    end
  end

  test "from v21 the timer runs while timer_start is set" do
    with_system(ModernSystem.new(42, 1234.5)) do |sys|
      sprite = EventTimerSprite.new
      sprite.update
      sys.timer_start = nil
      sprite.update
      sys.timer = 75
      sys.timer_start = 2000.0
      sprite.update
    end
    assert_equal [timer_line("0:42"), timer_line("1:15")], SpeakCapture.lines
  end

  test "a game loaded with its timer running says the countdown again" do
    with_system(ClassicSystem.new(50, true)) { EventTimerSprite.new.update }
    with_system(ClassicSystem.new(50, true)) { EventTimerSprite.new.update }
    assert_equal [timer_line("0:50")] * 2, SpeakCapture.lines
  end

  test "a stopped timer says nothing, and the sprite keeps its own result" do
    with_system(ClassicSystem.new(20, false)) do
      assert_equal :updated, EventTimerSprite.new.update
    end
    assert_nothing_spoken
  end

  private

  # Runs the block with sys as the game's $game_system, the harness's put back after.
  def with_system(sys)
    kept = $game_system
    $game_system = sys
    yield sys
  ensure
    $game_system = kept
  end

  # What the field key says off battle.
  def field_key
    PokeAccess::Battle.announce_overworld
    SpeakCapture.lines.last
  ensure
    SpeakCapture.clear
  end

  def timer_line(time)
    PokeAccess::I18n.t(:event_timer, :t => time)
  end
end
