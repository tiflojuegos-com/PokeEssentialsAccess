# Focus.focused?: the game's window is in front when the window in front is this process's, where Windows tells the
# owner; where it does not (an engine that fakes the window handle), the window first seen in front stands for it.
class FocusTest < PokeAccessTest
  F = PokeAccess::Focus
  # The window handles the tests put in front: the game's, another program's, and none.
  GAME = 555
  OTHER = 777
  NONE = 0
  # This process's id, and another program's.
  OWN_PID = 4000
  OTHER_PID = 4242

  test "another program's window in front at the first look is not taken for the game's" do
    with_windows(GAME => OWN_PID, OTHER => OTHER_PID) do |front|
      assert_equal [false, true, false], [OTHER, GAME, OTHER].map { |h| front[0] = h; F.focused? }
    end
  end

  test "the game's window made anew in front, as a fullscreen toggle does, is still the game's" do
    with_windows(GAME => OWN_PID, 556 => OWN_PID) do |front|
      assert_equal [true, true], [GAME, 556].map { |h| front[0] = h; F.focused? }
    end
  end

  test "where the window's owner cannot be told, the window first seen in front stands for the game's" do
    with_windows({}) do |front|
      assert_equal [true, true, false, true], [GAME, GAME, NONE, GAME].map { |h| front[0] = h; F.focused? }
    end
  end

  test "a step taken with another program's window in front, as on ice, does not make that window the game's" do
    with_windows(OTHER => OTHER_PID) do |front|
      front[0] = GAME
      F.focused?
      front[0] = OTHER
      F.mark_focused
      front[0] = GAME
      assert_equal [true, GAME], [F.focused?, F.hwnd]
    end
  end

  private

  # Runs the block with GetForegroundWindow answering the handle in front[0] (yielded), GetWindowThreadProcessId
  # writing the owner owners gives each handle (none for the others) and GetCurrentProcessId answering OWN_PID; no
  # game window is remembered while it runs, and the calls and the remembered window are put back after.
  def with_windows(owners)
    front = [NONE]
    gfw = fake { |*_a| front[0] }
    gwt = fake do |h, buf|
      pid = owners[h]
      buf[0, 4] = [pid].pack("L") if pid
      pid ? 1 : 0
    end
    pid = fake { |*_a| OWN_PID }
    was = F.instance_variable_get(:@game_hwnd)
    F.instance_variable_set(:@game_hwnd, nil)
    with_consts(F, :GFW => gfw, :GWTPID => gwt, :GCPID => pid) { yield front }
  ensure
    F.instance_variable_set(:@game_hwnd, was)
  end

  # A stand-in for a Win32API call that answers with the block.
  def fake(&body)
    o = Object.new
    o.define_singleton_method(:call, &body)
    o
  end

  # Runs the block with the module's constants set to the values given, put back after.
  def with_consts(mod, values)
    saved = values.keys.map { |k| [k, mod.const_get(k)] }
    values.each { |k, v| mod.send(:remove_const, k); mod.const_set(k, v) }
    yield
  ensure
    saved.each { |k, v| mod.send(:remove_const, k); mod.const_set(k, v) }
  end
end
