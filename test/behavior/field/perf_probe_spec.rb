# The performance diagnostic is only useful where the player is. Its two original probes, map_poll and
# audio3d, both hang off Game_Player#update, so a tester who recorded a session in a menu that felt slow
# handed in a report with no numbers in it at all -- and the report still printed "map_poll" as though it
# had measured something, on a screen where map_poll does not run.
#
# The third probe hangs off Input.update, which every scene runs, menus included. That is the whole point,
# so it is what this pins: not that Perf can add up milliseconds, but that one frame of input anywhere
# leaves a measurement behind.
Suite.define("perf: the diagnostic still has a number off the map") do
  perf = PokeAccess::Perf
  saved = perf.instance_variable_get(:@stats)
  begin
    perf.reset
    eq "an empty window says so rather than crashing", perf.report, "(sin datos)"

    perf.measure(:pa_spec_probe) { 1 }
    truthy "a measured block is recorded under its own label", perf.report.index("pa_spec_probe")

    perf.reset
    SpeakCapture.clear
    Input.update
    truthy "and one frame of input leaves a measurement behind, with no map in sight",
           perf.report.index("input_frame")
  ensure
    SpeakCapture.clear
    perf.instance_variable_set(:@stats, saved)
  end
end
