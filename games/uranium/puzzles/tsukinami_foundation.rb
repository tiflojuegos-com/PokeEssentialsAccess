# The Tsukinami Village Foundation (map 241): rooms joined by Quantum Leap points, each a common event (90) that asks to
# jump and transfers the player to the spot its page writes to variables 2 and 3. The sceptre lies in the entrance room.
# Stepping on the plates of the south room (events 52 and 53) adds to variable 138; at 2 Urayne (event 43) appears, and
# speaking to it sets 6, which opens the last leap (event 37) to the room of the flutes (event 16). The routes cannot
# follow a leap: the hint gives the next one toward the south room, by room, from a table the map's leaps were walked into.
module PokeAccess
  module UraniumFoundation
    # Each room as its box of tiles [x0, x1, y0, y1], with the leap that leads from it toward the south room.
    def self.rooms
      [[[0, 10, 2, 13], 2], [[28, 40, 12, 23], 27], [[33, 36, 4, 6], 30], [[30, 31, 3, 6], 33], [[23, 27, 28, 31], 21],
       [[8, 10, 19, 22], 23], [[1, 9, 29, 38], 17], [[11, 18, 13, 17], 25], [[18, 34, 35, 42], nil],
       [[19, 21, 25, 31], 20], [[19, 22, 8, 11], 44]]
    end

    def self.stage; $game_variables[138].to_i; end
    def self.flutes_taken?; $game_self_switches[[241, 16, "A"]] ? true : false; end
    def self.done?; stage >= 6 && flutes_taken?; end

    # The room the player stands in, as its entry of rooms, or nil.
    def self.room
      x = $game_player.x
      y = $game_player.y
      rooms.find { |box, _leap| x.between?(box[0], box[1]) && y.between?(box[2], box[3]) }
    end

    # The leap at an event, as a hint toward it.
    def self.leap_to(id)
      ev = $game_map.events[id]
      ev ? [:ura_rp_leap_next, { :x => ev.x, :y => ev.y }] : ""
    end

    # The next step of the plates' quest: the next leap toward the south room, then the plates, Urayne, the last leap and
    # the flutes.
    def self.hint
      return "" if done?
      here = room
      return "" unless here
      box, leap = here
      return :ura_rp_leap_flutes if box == [19, 22, 8, 11] && stage >= 6
      return leap_to(leap) if leap
      return :ura_rp_leap_plates if stage < 2
      return :ura_rp_leap_urayne if stage < 6
      leap_to(37)
    end
  end
end

PokeAccess::Game.define("uranium") do
  mechanic(:state, 241) do
    auto
    name [52, 53], :ura_rp_leap_plate, :when => lambda { |ev| PokeAccess::UraniumFoundation.stage < 2 }
    active { PokeAccess::Puzzles.assist? && $game_switches[186] && !PokeAccess::UraniumFoundation.done? }
    hint lambda { PokeAccess::UraniumFoundation.hint }
    solved(nil, :quiet => true) { PokeAccess::UraniumFoundation.done? }
  end
end
