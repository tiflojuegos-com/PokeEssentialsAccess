# Perseida's puzzle room of the Bard's temple (map 135): four statues that cry (EV5, EV4, EV3, EV2) are pressed in the order
# of the slab's cries (EV26): a wrong one sets V68 to 0, each right one draws a tile on the row below (EV29, EV28, EV30,
# EV27) and V68 at 5 opens the door (EV6) north. There four statues (EV1, EV7, EV8, EV9) are pushed with pbPushThisBoulder,
# each to its own hole, which a parallel event checks and marks with its switch (120 to 123); stepping on a hole sounds its
# cry. The tile events are the progress, so the map leaves out what the core says of a control (a shut passage). Each hole adds
# one to V69 and the scene of the fourth sets it to 5, which ends the statues' rule and their line on the info key.
module PokeAccess
  module PerseidaBard
    MAP = 135
    STATUES = [[1, 120, 13, 4], [7, 121, 2, 8], [8, 123, 5, 4], [9, 122, 16, 8]]
    CRIES = [[5, 35, 29], [4, 133, 28], [3, 590, 30], [2, 459, 27]]
    SLAB = 26
    PROGRESS = 68
    PLACED = 69
    DONE = 5

    # True once the cries are solved and the door to the statues' room is open.
    def self.open?
      $game_variables[PROGRESS].to_i >= DONE
    end

    # True once the four statues sit in their holes and the scene that follows has run.
    def self.placed?
      $game_variables[PLACED].to_i >= DONE
    end

    # The statues' rule once their room is open, else nothing.
    def self.statues_rule
      open? ? :perseida_bard_statues_rule : ""
    end

    # The cries' rule until they are solved, else nothing.
    def self.cries_rule
      open? ? "" : :perseida_bard_cries_rule
    end

    # An event's own name, or empty.
    def self.event_name(id)
      ev = $game_map.events[id]
      ev ? ev.name.to_s : ""
    end

    # The statue to place first, in the order of STATUES, or nil once all sit in their holes.
    def self.current
      STATUES.find { |_ev, switch, _x, _y| !$game_switches[switch] }
    end

    # A hole's name: with the assist, by the statue it takes.
    def self.hole_label(id)
      PokeAccess::Puzzles.assist? ? [:perseida_bard_hole_of, { :statue => event_name(id) }] : :perseida_bard_hole
    end

    # True while a statue's hole is still empty in the open room, but for the one the assist's phase already lists as its goal.
    def self.hole_listed?(id)
      return false unless open?
      entry = STATUES.find { |ev, _switch, _x, _y| ev == id }
      return false if $game_switches[entry[1]]
      !(PokeAccess::Puzzles.assist? && current && current[0] == id)
    end

    # A crying statue's name by its Pokemon; with the assist, its place in the order of the cries.
    def self.cry_label(ev)
      n = CRIES.map { |c| c[0] }.index(ev.id)
      species = PokeAccess::Data.species_name(CRIES[n][1])
      return [:perseida_bard_cry_statue, { :species => species }] unless PokeAccess::Puzzles.assist?
      [:perseida_bard_cry_statue_nth, { :species => species, :n => n + 1 }]
    end

    # The order of the cries, by Pokemon.
    def self.cries_hint
      names = CRIES.map { |c| PokeAccess::Data.species_name(c[1]) }
      [:perseida_bard_cries_hint, { :order => PokeAccess::Routes::Text.and_list(names) }]
    end
  end
end

PokeAccess::Game.define("perseida") do
  bard = PokeAccess::PerseidaBard
  mechanic(:state, bard::MAP, :part => :statues) do
    count :perseida_bard_statues, :switches => bard::STATUES.map { |s| s[1] }
    bard::STATUES.each do |ev, switch, x, y|
      phase lambda { bard.open? && !$game_switches[switch] },
            :hint => lambda { [:perseida_bard_push_hint, { :statue => bard.event_name(ev) }] },
            :track => { :event => ev, :label => lambda { bard.event_name(ev) }, :goal => [x, y, x, y],
                        :goal_label => lambda { [:perseida_bard_hole_of, { :statue => bard.event_name(ev) }] } }
      spot :at => [x, y], :label => lambda { bard.hole_label(ev) }, :when => lambda { bard.hole_listed?(ev) }
    end
    arrival_hint lambda { bard.statues_rule }
    solved { bard.placed? }
  end

  mechanic(:state, bard::MAP, :part => :cries) do
    name bard::CRIES.map { |c| c[0] }, lambda { |ev| lambda { bard.cry_label(ev) } }
    name bard::SLAB, :perseida_bard_slab
    count :perseida_bard_cries, :flags => bard::CRIES.map { |c| { :event => c[2] } }
    active { !bard.open? }
    hint lambda { bard.cries_hint }
    arrival_hint lambda { bard.cries_rule }
  end
end
