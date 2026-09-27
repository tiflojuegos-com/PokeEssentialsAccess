# The timing gauge's tick, pitched by closeness to the good moment: its sweep fits mkxp's flat SE range (50-150), so
# every step sounds different.
Suite.define("gauge: the sweep stays inside the flat channel's 50-150 and every step is audible") do
  log = []
  orig = Audio.method(:se_play)
  begin
    Audio.define_singleton_method(:se_play) { |*a| log.push(a); nil }
    pitches = (0..6).map { |d| log.clear; PokeAccess::Spatial.gauge(1.0 - d / 6.0); log[0][2] }
    eq "the far end is unchanged", pitches.last, 80
    eq "the perfect moment sits on the channel's ceiling, not above it", pitches.first, 150
    eq "seven frames, seven different pitches", pitches.uniq.length, 7
    eq "descending as the moment recedes", pitches, pitches.sort.reverse
    log.clear; PokeAccess::Spatial.gauge(1.4)
    eq "an overshoot clamps to the top", log[0][2], 150
    log.clear; PokeAccess::Spatial.gauge(-0.5)
    eq "and an undershoot to the bottom", log[0][2], 80
    eq "the constants themselves fit the channel", PokeAccess::Spatial::GAUGE_LOW + PokeAccess::Spatial::GAUGE_SPAN, 150
  ensure
    Audio.define_singleton_method(:se_play, orig)
  end
end
