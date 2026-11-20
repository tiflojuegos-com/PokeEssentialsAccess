# The temple of Ibossim (map 180): six rooms in a row, each with doors drawn with no sprite. One door of each room leads
# on, to the next room and then to the hall where Asherah's son waits; the rest (events 15 to 36) send the player back
# to the entrance, at (6,13). ROOMS holds each room's box, its door that leads on and the side it is on. S190 is set
# once the hall's scene has started.
module PokeAccess
  module AfricanvsIbossim
    MAP = 180
    BACK = [6, 13]
    WRONG = 15..36
    DONE = 190
    ROOMS = [
      [[2, 11, 8, 14], [3, 4], :dir_e],
      [[29, 38, 8, 14], [5, 6], :dir_s],
      [[2, 11, 25, 31], [7, 8], :dir_s],
      [[29, 38, 25, 31], [9, 10], :dir_o],
      [[2, 11, 45, 51], [11, 12], :dir_o],
      [[38, 47, 45, 51], [13, 14], :dir_e]
    ]

    # The assist's line in a room: the side its door that leads on is on.
    def self.hint(side)
      PokeAccess::I18n.t(:af_ibossim_hint, :dir => PokeAccess::I18n.t(side))
    end
  end
end

PokeAccess::Game.define("africanus") do
  temple = PokeAccess::AfricanvsIbossim
  mechanic(:state, temple::MAP) do
    auto
    sent_back :af_ibossim_sent_back, :to => temple::BACK, :events => temple::WRONG
    temple::ROOMS.each do |box, doors, side|
      phase at(*box), :hint => lambda { temple.hint(side) }, :hidden => right_way(*doors)
    end
    solved(nil) { $game_switches[temple::DONE] }
  end
end
