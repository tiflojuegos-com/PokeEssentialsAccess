# The performance diagnostic measures off the map too: one frame of Input.update, which every scene runs, leaves an
# input_frame measurement.
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
