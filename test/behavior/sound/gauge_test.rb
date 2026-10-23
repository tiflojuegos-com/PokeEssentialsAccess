# The flat channel's tones for minigames and puzzles: the timing gauge's tick (Sound.gauge), pitched by closeness to the
# good moment inside mkxp's 50-150, and a puzzle grid's cell (Sound.cell), its file by column and its pitch by row.
class GaugeTest < PokeAccessTest
  Sound = PokeAccess::Sound

  test "the tick sweeps from 80 at the far end to the channel's ceiling of 150, a pitch of its own per sixth" do
    pitches = (0..6).map { |d| flat_plays { Sound.gauge(1.0 - d / 6.0) }.map { |_f, _v, pitch| pitch } }
    assert_equal [[150], [138], [126], [115], [103], [91], [80]], pitches
  end

  test "a fraction past either end is held to that end" do
    { 1.4 => 150, -0.5 => 80 }.each do |fraction, pitch|
      assert_equal [pitch], flat_plays { Sound.gauge(fraction) }.map { |_f, _v, p| p }, "at #{fraction}"
    end
  end

  test "a fraction as text reads as its leading number or 0, a missing one as 0, one of another kind plays nothing" do
    { "0.5" => [115], "soon" => [80], nil => [80], :soon => [] }.each do |fraction, pitches|
      assert_equal pitches, flat_plays { Sound.gauge(fraction) }.map { |_f, _v, p| p }, "for #{fraction.inspect}"
    end
  end

  test "the tick plays its own file at the minigame's volume" do
    PokeAccess::Config.minigame_volume = 33
    assert_equal [["pa_mg_tick", 33, 115]], flat_plays { Sound.gauge(0.5) }
  end

  test "with the minigame's sound switched off the tick is silent" do
    PokeAccess::Config.sound_minigame = false
    assert_equal [], flat_plays { Sound.gauge(0.5) }
  end

  test "a cell plays its column's file and its row's pitch at the puzzles' volume" do
    PokeAccess::Config.puzzle_volume = 44
    { [0, 0] => ["pa_guide_l", 44, 140], [1, 1] => ["pa_guide_c", 44, 110], [2, 2] => ["pa_guide_r", 44, 85],
      [2, 0] => ["pa_guide_r", 44, 140] }.each do |(col, row), play|
      assert_equal [play], flat_plays { Sound.cell(col, row) }, "column #{col}, row #{row}"
    end
  end

  test "a cell past the grid plays the centre file at the recording's pitch" do
    PokeAccess::Config.puzzle_volume = 44
    assert_equal [["pa_guide_c", 44, 100]], flat_plays { Sound.cell(3, 5) }
  end

  test "the grid's tone moves every row, held inside the flat channel" do
    { 0 => [82, 65, 50], 100 => [150, 118, 91] }.each do |tone, pitches|
      PokeAccess::Config.grid_tone = tone
      plays = flat_plays { (0..2).each { |row| Sound.cell(0, row) } }
      assert_equal pitches, plays.map { |_f, _v, p| p }, "tone #{tone}"
    end
  end

  test "a cell plays down to the puzzles' quietest volume, and nothing at 0 or with the grid's sound off" do
    { [1, true] => [["pa_guide_l", 1, 140]], [0, true] => [], [44, false] => [] }.each do |(volume, on), plays|
      PokeAccess::Config.puzzle_volume = volume
      PokeAccess::Config.sound_grid = on
      assert_equal plays, flat_plays { Sound.cell(0, 0) }, "at volume #{volume}, sound #{on ? 'on' : 'off'}"
    end
  end

  private

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
