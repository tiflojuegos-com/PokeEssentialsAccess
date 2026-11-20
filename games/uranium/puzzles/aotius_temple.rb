# The Temple of Aotius (map 262), after the story: five levers (events 60 to 64) flip the switches 87 to 93, which draw and
# remove rows of flames across the way. The way north needs levers 61, 62, 60, 63, 64 and 63 again, the last pulled from the
# east room; the hint reads the levers off the switches and names the next one the player can walk to. In the north the
# flames that do not burn (events 11, 14, 17, 22, 23) are drawn on the sign, events 12, 13, 15, 16, 24 and 25 send the
# player back. Switch 233 clears the flames, which the map sets on arrival below story step 27.
module PokeAccess
  module UraniumAotius
    def self.levers; [60, 61, 62, 63, 64]; end
    def self.flames; [11, 12, 13, 14, 15, 16, 17, 22, 23, 24, 25]; end
    def self.sign; 68; end
    def self.north; [14, 9]; end
    def self.safe_order; [[10, 12], [11, 9], [12, 11], [14, 12], [16, 12]]; end
    def self.flame_origin; [9, 8]; end

    # For each combination of pulled levers (bit 0 to 4 for events 60 to 64), the levers that lead on, as [steps left,
    # event]: the way is found by a search over every position and lever combination on the map's own pages.
    def self.next_levers
      {
        0 => [[5, 62], [6, 61]], 1 => [[6, 60], [7, 61]], 2 => [[5, 62]], 3 => [[6, 60]],
        4 => [[4, 60], [4, 63], [5, 61]], 5 => [[3, 63], [4, 61]], 6 => [[4, 60], [4, 63]], 7 => [[3, 63]],
        12 => [[3, 64]], 13 => [[2, 64]], 14 => [[3, 64]], 15 => [[2, 64]],
        16 => [[1, 60], [2, 61]], 17 => [[1, 61]], 18 => [[1, 60]], 20 => [[1, 60], [2, 61]], 21 => [[1, 61]],
        22 => [[1, 60]], 28 => [[2, 63]], 29 => [[1, 63]], 30 => [[2, 63]], 31 => [[1, 63]]
      }
    end

    # Whether a game switch is on.
    def self.on?(id); $game_switches[id] ? true : false; end

    # The levers pulled, as the bits of a number, read off the switches the levers flip.
    def self.mask
      bits = [on?(93), on?(87), on?(92) ^ on?(91), on?(91), on?(90)]
      sum = 0
      bits.each_with_index { |bit, i| sum |= (1 << i) if bit }
      sum
    end

    # An event's place among the levers, in reading order.
    def self.number(id)
      spots = levers.map { |lever| ev = $game_map.events[lever]; [ev.y, ev.x, lever] }
      spots.sort.index { |spot| spot[2] == id } + 1
    end

    # Whether the player can walk to the tiles beside a spot now.
    def self.near?(x, y)
      PokeAccess::Routes::Planner.reach(PokeAccess::Routes::Goal.near(x, y))[0] != :no
    end

    # Whether the player can walk to the tiles beside an event now.
    def self.reachable?(id)
      ev = $game_map.events[id]
      near?(ev.x, ev.y)
    end

    # The lever to pull next, the nearest to the way north among those the player can walk to.
    def self.next_lever
      options = next_levers[mask]
      return nil unless options
      pick = options.find { |option| reachable?(option[1]) } || options.first
      pick[1]
    end

    # A flame of the northern grid as its row and column in the picture on the sign.
    def self.cell(x, y)
      PokeAccess::I18n.t(:ura_pp_aotius_cell, :row => y - flame_origin[1], :col => x - flame_origin[0])
    end

    # What the picture on the sign shows: the flames that do not hurt, by row and column.
    def self.picture
      cells = safe_order.sort_by { |spot| [spot[1], spot[0]] }.map { |spot| cell(spot[0], spot[1]) }
      PokeAccess::I18n.t(:ura_pp_aotius_picture, :cells => cells.join("; "))
    end

    # The safe way through the northern flames.
    def self.safe_way
      cells = safe_order.map { |spot| cell(spot[0], spot[1]) }
      PokeAccess::I18n.t(:ura_pp_aotius_safe, :cells => cells.join("; "))
    end

    # The hint: the next lever, or once the way north is open the flames to step on.
    def self.hint
      return "" if done?
      return safe_way if reachable_north?
      lever = next_lever
      lever ? PokeAccess::I18n.t(:ura_pp_aotius_next, :n => number(lever)) : ""
    end

    # Whether the player can walk to the Urayne memory in the north.
    def self.reachable_north?; near?(north[0], north[1]); end

    # Whether the temple is over: the flames are out for good, or Aotius has been caught.
    def self.done?; on?(233) || on?(232); end
  end
end

PokeAccess::Game.define("uranium") do
  mechanic(:state, 262) do
    auto
    [87, 88, 89, 90, 91, 92, 93].each { |switch| watch :switch => switch, :quiet => true }
    controls
    obstacle(/fire/i, :label => :ura_pp_aotius_wall)
    name(PokeAccess::UraniumAotius.levers, :ura_pp_aotius_lever, :numbered => true)
    name(PokeAccess::UraniumAotius.flames, lambda { |ev| PokeAccess::UraniumAotius.cell(ev.x, ev.y) })
    on_reach(PokeAccess::UraniumAotius.sign, { :text => 1 }, lambda { |ev| PokeAccess::UraniumAotius.picture })
    arrival_hint lambda { PokeAccess::UraniumAotius.done? ? nil : :ura_pp_aotius_rule }
    solved(nil) { PokeAccess::UraniumAotius.done? }
    hint lambda { PokeAccess::UraniumAotius.hint }
  end
end
