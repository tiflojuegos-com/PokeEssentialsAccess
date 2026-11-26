# Mechanic Shed (map 748), Route 4: once the Breloom machine is beaten (variable 393 at 2) a Gastly (event 9) waits at
# (22,7) and four hidden corners flip it round the machine. Stepping on one while it is halfway (row 8) panics it
# (switch 927); with Blindstep (2226) it never moves. From the south, send it south and wait: (22,9) needs no corner.
module PokeAccess
  module RebornMechanicShed
    MAP = 748
    GASTLY = 9
    CORNERS = { 23 => 7, 24 => 7, 25 => 9, 11 => 9 }
    NORTH = 7
    BELOW_SOUTH = [22, 10]

    # True while the Gastly is out and not yet beaten or caught.
    def self.chasing?; $game_variables[393].to_i == 2; end

    # True when the corners no longer move the Gastly: panicked, or Blindstep.
    def self.still?; $game_switches[927] || $game_switches[2226] ? true : false; end

    # The Gastly's row, nil while it is not on the map.
    def self.row
      ev = ($game_map.events || {})[GASTLY]
      ev ? ev.y : nil
    end

    # What a corner says as it is stepped on: that the Gastly flees round the machine, when it waits on that row.
    def self.corner(ev)
      return nil unless chasing? && !still?
      row == CORNERS[ev.id] ? :rbh_ms_flees : nil
    end

    # With the assist, the way to reach the Gastly from where it waits.
    def self.hint
      return nil unless chasing? && row
      return :rbh_ms_hint_still if still?
      row == NORTH ? :rbh_ms_hint_north : :rbh_ms_hint_south
    end
  end
end

PokeAccess::Game.define("reborn") do
  ms = PokeAccess::RebornMechanicShed
  mechanic(:state, ms::MAP) do
    auto
    on_use ms::CORNERS.keys, lambda { |ev| ms.corner(ev) }
    spot(:at => ms::BELOW_SOUTH, :label => :rbh_ms_spot, :assist => true, :when => lambda { ms.chasing? && !ms.still? })
    hint lambda { ms.hint }
    active { PokeAccess::Puzzles.assist? && ms.chasing? }
    solved(nil, :quiet => true) { $game_variables[393].to_i >= 3 }
  end
end
