# The haunted penthouse of Case Three (maps 93 to 95): variable 37 counts ghosts. Arriving in the bedroom starts
# Phantump; the small room's book (map 94, EV3), the hall's book (map 93, EV12), the small room's present (EV4) and door
# (EV1) each start a battle and move a bedroom box (map 95, EV4 to EV7, gone at 3 to 6). The assist names the next.
module PokeAccess
  module AshenPenthouse
    GHOSTS = 37
    # What the assist says at each count, and the event that is next, as [map, id], where there is one to name.
    STEPS = {
      1 => [:afh_ghost_bedroom, nil],
      2 => [:afh_ghost_book_small, [94, 3]],
      3 => [:afh_ghost_book_hall, [93, 12]],
      4 => [:afh_ghost_present, [94, 4]],
      5 => [:afh_ghost_door, nil]
    }

    # The ghosts met so far.
    def self.count
      $game_variables[GHOSTS].to_i
    end

    # Whether the bed is free: every box moved.
    def self.done?
      count >= 6
    end

    # Whether an event of this map is the haunted object the count waits for.
    def self.next?(ev)
      step = STEPS[count]
      step && step[1] == [$game_map.map_id, ev.id] ? true : false
    end

    # The assist's line for the count, or nil before the first ghost.
    def self.hint
      step = STEPS[count]
      step ? step[0] : nil
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  ghosts = PokeAccess::AshenPenthouse
  mechanic(:state, [93, 94, 95], :part => :ghosts) do
    auto
    name [3, 4, 12], lambda { |ev| ghosts.next?(ev) ? :afh_ghost_haunted : nil }, :assist => true,
                     :when => lambda { |ev| ghosts.next?(ev) }
    phase lambda { PokeAccess::Puzzles.assist? && ghosts.hint }, :quiet => true, :hint => lambda { ghosts.hint }
    active { !ghosts.done? }
  end
end
