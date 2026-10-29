module PokeAccess
  # Sevii's Cycling Road on Route 110: while switch 270 is on, CyclingRoadHUD repaints "Time:" over the seconds ridden
  # every tenth of a second. A run's first paint is said and the field key says the last one; the final time is a
  # message at the road's end, which the dialogue reader says.
  module SeviiCyclingRoad
    # The switch that is on while a run is timed, and the variable that holds the run (a CyclingRoadState and its HUD).
    RUN_SWITCH = 270
    RUN_VAR = 85

    # A paint of the HUD: its rows kept on it for the field key, and said, queued, the first time it paints.
    def self.painted(hud, rows)
      return if rows.empty?
      first = PokeAccess.ivar(hud, :@access_sv_time).nil?
      hud.instance_variable_set(:@access_sv_time, rows)
      PokeAccess.speak(text(rows), false) if first
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The rows as the HUD lays them out, its label joined to the time under it.
    def self.text(rows)
      PokeAccess::PaintCapture.pair_labels(PokeAccess::PaintCapture.lines(rows)).join(", ")
    end

    # The time the running HUD painted last, or nil while no run is timed.
    def self.line
      return nil unless ($game_switches[RUN_SWITCH] rescue false)
      hud = ($game_variables[RUN_VAR].hud rescue nil)
      rows = hud && PokeAccess.ivar(hud, :@access_sv_time)
      return nil unless rows
      t = text(rows)
      t.empty? ? nil : t
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("sevii") do
  # createText paints the whole HUD: as it is built, then on each repaint its update makes.
  around("CyclingRoadHUD", :createText) do |hud, nxt, _a|
    r = nil
    rows = PokeAccess::PaintCapture.sample { r = nxt.call }
    PokeAccess::SeviiCyclingRoad.painted(hud, rows)
    r
  end

  # The field key says the run's time ahead of the field events core counts.
  override("PokeAccess::Battle", :field_event_text) do |_mod, original, _args|
    parts = [PokeAccess::SeviiCyclingRoad.line, original.call].compact
    parts.empty? ? nil : parts.join(", ")
  end
end
