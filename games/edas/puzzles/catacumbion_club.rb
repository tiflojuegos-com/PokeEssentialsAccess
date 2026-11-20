# Edas' Catacumbión club (map 46) in the Amber chapter (switch 177): its exit (event 2) stays shut until the skeleton key is
# found (switch 187). Notes hidden about the room point the way, and the key lies under a rug (event 23, worked standing on
# it), which asks for none of them. The panel behind the wall (event 25) shows once the wall gives (switch 247).
module PokeAccess
  module EdasClub
    MAP = 46
    CHAPTER = 177
    KEY = 187
    WALL = 247
    NOTES = [16, 11, 12]
    PANEL = 25
    RUG = [13, 14]

    # Whether the club holds the player: the chapter under way and the key still to find.
    def self.locked?
      $game_switches[CHAPTER] && !$game_switches[KEY] ? true : false
    end
  end
end

PokeAccess::Game.define("edas") do
  club = PokeAccess::EdasClub
  mechanic(:state, club::MAP) do
    auto
    name club::NOTES, lambda { |_ev| club.locked? ? :edas_club_note : nil }, :when => lambda { |_ev| club.locked? }
    name club::PANEL, lambda { |_ev| club.locked? && $game_switches[club::WALL] ? :edas_club_panel : nil },
         :when => lambda { |_ev| club.locked? && $game_switches[club::WALL] }
    arrival_hint lambda { club.locked? ? :edas_club_rule : nil }
    solved { $game_switches[club::KEY] }
    phase lambda { club.locked? }, :hint => :edas_club_hint
    spot :at => club::RUG, :label => :edas_club_rug, :assist => true, :onto => true, :when => lambda { club.locked? }
  end
end
