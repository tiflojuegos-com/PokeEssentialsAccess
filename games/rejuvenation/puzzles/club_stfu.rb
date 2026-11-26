# Club S.T.F.U. (map 414): the party's hype (variable 115) lights the meter drawn on the door to Amber's room (event 6)
# in eight steps. With the meter full the door opens to the action button (switch 274); stepping on it leads to Amber.
module PokeAccess
  module RejuvClub
    MAP = 414
    STEPS = [50, 100, 150, 200, 250, 300, 350, 550]
    FULL = 550

    # How many of the meter's steps are lit.
    def self.lit
      v = $game_variables[115].to_i
      STEPS.count { |s| v >= s }
    end

    # The door's name, with its meter as drawn.
    def self.door_label
      [:rj_club_door, { :n => lit, :of => STEPS.length }]
    end

    # The assisted hint: raise the hype, open the door, or go through it.
    def self.hint
      return :rj_club_hint_enter if $game_switches[274]
      $game_variables[115].to_i >= FULL ? :rj_club_hint_open : [:rj_club_hint_hype, { :n => $game_variables[115].to_i,
                                                                                        :of => FULL }]
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  club = PokeAccess::RejuvClub
  mechanic(:state, club::MAP, :part => :hype) do
    auto
    name 6, lambda { |_ev| club.door_label }
    info { PokeAccess::Puzzles.label_of(club.door_label) }
    hint lambda { club.hint }
    active { !$game_switches[274] || $game_variables[115].to_i < 400 }
    solved(nil, :quiet => true) { $game_switches[274] && $game_variables[115].to_i >= 400 }
  end
end
