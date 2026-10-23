# Infinite Fusion's speed-up key (games/infinitefusion_common/turbo_mode.rb): in its default Hold mode each press cycles
# $GameSpeed, which that mode never uses, so nothing is said; in Toggle mode the index is the SPEEDUP_STAGES multiplier,
# said as in other games.
class IfTurboModeGdTest < PokeAccessTest
  # The poller's memory as the mod boots, taken as this file loads, before any test runs.
  BOOT = PokeAccess::Turbo.instance_variables.map { |k| [k, PokeAccess::Turbo.instance_variable_get(k)] }
  # The core's speed reading and the profile's override of it: the profile file is evaluated once, here, and the core's
  # reading put straight back, since the override would reach every other test of this engine; each test puts the
  # profile's in for its block.
  CORE_SPEED = PokeAccess::Turbo.method(:current_speed)
  path = File.join(Harness::ROOT, "games", "infinitefusion_common", "turbo_mode.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
  PROFILE_SPEED = PokeAccess::Turbo.method(:current_speed)
  PokeAccess::Turbo.define_singleton_method(:current_speed, CORE_SPEED)

  test "in Hold mode the presses cycle an index the game ignores, and nothing is said" do
    with_speedup(0) { [1, 2, 0].each { |n| press(n) } }
    assert_nothing_spoken
  end

  test "in Toggle mode each press says the multiplier it sets, interrupting" do
    with_speedup(1) do
      press(1)
      press(2)
    end
    assert_equal [[PokeAccess::I18n.t(:turbo_speed, :n => 2), true], [PokeAccess::I18n.t(:turbo_speed, :n => 3), true]],
                 SpeakCapture.log
  end

  test "an options menu without the speed-up setting counts as Hold mode" do
    with_speedup(nil) { press(1) }
    assert_nothing_spoken
  end

  private

  # Runs the block on the map with the profile's speed reading in place, the speed-up setting at mode (an options
  # menu lacking it for nil), the stages x1, x2 and x3, and the index at 0 already seen; the core's speed reading, the
  # game's globals and the poller's memory are put back after.
  def with_speedup(mode)
    saved = [$scene, $PokemonSystem, $GameSpeed]
    PokeAccess::Turbo.define_singleton_method(:current_speed, PROFILE_SPEED)
    $scene = Scene_Map.new
    $PokemonSystem = mode.nil? ? Object.new : Struct.new(:speedup).new(mode)
    $GameSpeed = 0
    with_stages([1, 2, 3]) do
      forget_speed
      PokeAccess::Turbo.tick
      SpeakCapture.clear
      yield
    end
  ensure
    PokeAccess::Turbo.define_singleton_method(:current_speed, CORE_SPEED)
    $scene, $PokemonSystem, $GameSpeed = saved
    forget_speed
  end

  # Runs the block with the game's SPEEDUP_STAGES set to stages, then puts back what was there.
  def with_stages(stages)
    had = Object.const_defined?(:SPEEDUP_STAGES, false)
    was = had ? Object.const_get(:SPEEDUP_STAGES) : nil
    Object.send(:remove_const, :SPEEDUP_STAGES) if had
    Object.const_set(:SPEEDUP_STAGES, stages)
    yield
  ensure
    Object.send(:remove_const, :SPEEDUP_STAGES) if Object.const_defined?(:SPEEDUP_STAGES, false)
    Object.const_set(:SPEEDUP_STAGES, was) if had
  end

  # Puts the poller's memory back as the mod boots it.
  def forget_speed
    BOOT.each { |k, v| PokeAccess::Turbo.instance_variable_set(k, v) }
  end

  # One press of the speed-up key leaving the index at n, and the frame that follows.
  def press(n)
    $GameSpeed = n
    PokeAccess::Turbo.tick
  end
end
