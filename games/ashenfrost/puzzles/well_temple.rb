# Ashen Frost's Well Temple (map 686): twelve rocks pushed with pbPushThisSokoban, two to a pit and three pits to a wing. The game
# moves one only onto RoughFloor, the pits' paved floor (003_Interpreter.rb), and its control event (EV61) waits for each on the
# mark of its colour painted on that floor, the left wing first: the marks are in plain sight, so they are told without the puzzle
# assist. Leaving the map puts the rocks back ($PokemonMap.clear), so no push is final. The pits are walled off from the rest of
# the map, with only two doors of Morove Canyon (M689/E3 and E4) into them, so the puzzle speaks only there.
module PokeAccess
  module AshenWellTemple
    MAP = 686
    CONTROL = 61
    # The part of the map the pits stand in, [x0, y0, x1, y1], and the column of the spikes (EV62, EV63) that part its wings until
    # EV61 has seen the left one done.
    PITS = [8, 59, 32, 77]
    SPIKES_X = 20
    # Each wing's rocks: the event, the colour its graphic wears and the tile of its mark, as EV61's pages check them. EV61 asks no
    # order, so this is one where each can move on its turn: EV56 and EV60 stand in the way of EV55 and EV59.
    WINGS = [
      [[49, :grey, 13, 63], [50, :orange, 10, 63], [51, :grey, 10, 66], [52, :orange, 13, 68], [53, :grey, 10, 74], [54, :orange, 13, 71]],
      [[56, :orange, 26, 61], [55, :grey, 30, 64], [57, :grey, 30, 66], [58, :orange, 26, 69], [60, :orange, 27, 74], [59, :grey, 30, 71]]
    ]
    ROCK_LABELS = { :grey => :ashen_rock_grey, :orange => :ashen_rock_orange }
    MARK_LABELS = { :grey => :ashen_mark_grey, :orange => :ashen_mark_orange }

    # Whether EV61 has finished a wing: its pages set their self switches A and B.
    def self.wing_done?(letter)
      $game_self_switches[[MAP, CONTROL, letter]] ? true : false
    end

    # The rocks EV61 still waits for: the left wing's, then the right's; nil once both are done.
    def self.wing
      return WINGS[0] unless wing_done?("A")
      wing_done?("B") ? nil : WINGS[1]
    end

    # Whether a rock stands on its mark.
    def self.placed?(rock)
      ev = $game_map.events[rock[0]]
      ev && ev.x == rock[2] && ev.y == rock[3] ? true : false
    end

    # The first rock of the wing still off its mark, the one the puzzle's current phase is about.
    def self.next_rock
      rocks = wing
      rocks ? rocks.find { |rock| !placed?(rock) } : nil
    end

    # Whether the player is among the pits.
    def self.in_pits?
      x = $game_player.x
      y = $game_player.y
      x.between?(PITS[0], PITS[2]) && y.between?(PITS[1], PITS[3])
    end

    # Whether the player came in by the right wing's door with the left wing still to do: the spikes keep them from its rocks,
    # the ones EV61 waits for, and leaving is the only way round.
    def self.cut_off?
      in_pits? && !wing_done?("A") && $game_player.x > SPIKES_X
    end

    # How the room works, for the arrival and the info key: nothing away from the pits or with both wings done.
    def self.rule
      return "" unless in_pits? && wing
      cut_off? ? :ashen_temple_left_first : :ashen_temple_rule
    end

    # A phase's title: the rock, where it goes and how many of the wing are on their marks.
    def self.title(rock)
      t = PokeAccess::I18n
      t.t(:ashen_temple_next, :rock => t.t(ROCK_LABELS[rock[1]]), :mark => t.t(MARK_LABELS[rock[1]]),
                              :n => (wing || []).select { |r| placed?(r) }.length)
    end

    # The floor the game lets a rock move onto.
    def self.rough_floor?(x, y)
      $game_map.terrain_tag(x, y).id == :RoughFloor
    end

    # The rock an event of this map is, or nil.
    def self.rock(ev)
      return nil unless $game_map.map_id == MAP
      (WINGS[0] + WINGS[1]).find { |r| r[0] == ev.id }
    end

    # A rock's name for the locator, by its colour; nil for any other event.
    def self.rock_name(ev)
      r = rock(ev)
      r ? PokeAccess::I18n.t(ROCK_LABELS[r[1]]) : nil
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  push_script(/pbPushThisSokoban/) { |x, y| PokeAccess::AshenWellTemple.rough_floor?(x, y) }
  event_name { |ev| PokeAccess::AshenWellTemple.rock_name(ev) }
  event_category(:objects) { |ev| PokeAccess::AshenWellTemple.rock(ev) ? true : false }

  mechanic(:state, PokeAccess::AshenWellTemple::MAP) do
    arrival_hint lambda { PokeAccess::AshenWellTemple.rule }
    solved(nil, :quiet => true) { PokeAccess::AshenWellTemple.wing.nil? }
    phase lambda { PokeAccess::AshenWellTemple.cut_off? }
    (PokeAccess::AshenWellTemple::WINGS[0] + PokeAccess::AshenWellTemple::WINGS[1]).each do |rock|
      mark = PokeAccess::AshenWellTemple::MARK_LABELS[rock[1]]
      phase lambda { PokeAccess::AshenWellTemple.in_pits? && PokeAccess::AshenWellTemple.next_rock == rock },
            :title => lambda { PokeAccess::AshenWellTemple.title(rock) },
            :spots => [{ :at => [rock[2], rock[3]], :label => mark }],
            :track => { :event => rock[0], :label => PokeAccess::AshenWellTemple::ROCK_LABELS[rock[1]],
                        :goal => [rock[2], rock[3], rock[2], rock[3]], :goal_label => mark }
    end
  end
end
