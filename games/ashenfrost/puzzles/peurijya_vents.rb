# Peurijya Home (maps 584 to 587, Case Fourteen): four maps of one name joined by vents with no graphic. Listening at
# the locked door (map 584, EV5) opens the basement vent (EV7, self switch A) into the ducts (map 587), whose vents lead
# to the gangsters or to the bedrooms (map 586: EV3, EV8, EV9, EV10 add to variable 190; four show the traitor).
module PokeAccess
  module AshenPeurijya
    BASEMENT = 584
    DUCT_VENT = 7
    FOUND = 190
    KIDS = 4
    # Each map's vents: the event and the key of where it leads.
    VENTS = {
      584 => [[7, :afe_vent_ducts]],
      585 => [[4, :afe_vent_listen], [11, :afe_vent_ducts]],
      586 => [[1, :afe_vent_ducts]],
      587 => [[10, :afe_vent_basement], [11, :afe_vent_hallway], [14, :afe_vent_hallway], [12, :afe_vent_listen],
              [13, :afe_vent_listen], [15, :afe_vent_listen], [16, :afe_vent_listen],
              [17, :afe_vent_bedroom], [18, :afe_vent_bedroom]]
    }

    # How many children are found, never past the four.
    def self.found
      [$game_variables[FOUND].to_i, KIDS].min
    end

    # Whether the basement vent is open.
    def self.vent_open?
      $game_self_switches[[BASEMENT, DUCT_VENT, "A"]] ? true : false
    end

    # Whether the children are still to be found.
    def self.searching?
      found < KIDS
    end

    # The assist's hint: the door to listen at, then the way to the bedrooms.
    def self.hint
      vent_open? ? :afe_home_hint_kids : :afe_home_hint_door
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  home = PokeAccess::AshenPeurijya
  home::VENTS.each do |map, vents|
    mechanic(:state, map, :part => :afe_vents) do
      auto
      active { PokeAccess::Puzzles.assist? && home.searching? }
      vents.each { |ev, label| name ev, label }
      count :afe_home_kids, :value => lambda { home.found }, :of => home::KIDS, :assist => true, :reset => false
      phase lambda { home.searching? }, :hint => lambda { home.hint }
    end
  end
end
