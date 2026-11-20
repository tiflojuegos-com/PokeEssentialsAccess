# Sagittopoli's Casino Eldiw (map 327): once the grunt PR3SS is beaten (switch 543), the poster on the north wall (event 30,
# no sprite) hides a button that opens the stairs down (switch 544). The poster is named as it is seen; with the assist, as
# the button behind it, until pressed.
module PokeAccess
  module XenoCasino
    MAP = 327
    POSTER = 30
    OPENED = 544

    # The poster's name: the button behind it with the assist.
    def self.poster_label
      PokeAccess::Puzzles.assist? ? :xv_casino_button : :xv_casino_poster
    end
  end
end

PokeAccess::Game.define("xenoverse") do
  casino = PokeAccess::XenoCasino
  mechanic(:state, casino::MAP) do
    auto
    name casino::POSTER, lambda { |_ev| casino.poster_label }, :when => lambda { |_ev| !$game_switches[casino::OPENED] }
  end
end
