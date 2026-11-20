# The Lost Cave off Route 27 (map 200): nine rooms of three by three, each with an exit arrow on every side. One arrow of
# each room leads on, eight in a row from the entrance room to Maximo's (S255 once beaten); the rest send the player
# back to the entrance room, at (11,6). ROOMS holds each room's box, its exit that leads on and the side it is on.
module PokeAccess
  module AnilLostCave
    MAP = 200
    BACK = [11, 6]
    WRONG = 20..51
    BEATEN = 255
    ROOMS = [
      [[3, 19, 5, 19], [6], :dir_e],
      [[3, 19, 29, 43], [7, 8, 9], :dir_s],
      [[3, 19, 53, 67], [10, 11, 12], :dir_s],
      [[29, 45, 5, 19], [13], :dir_n],
      [[29, 45, 29, 43], [14], :dir_e],
      [[29, 45, 53, 67], [15], :dir_e],
      [[55, 71, 5, 19], [16, 17, 18], :dir_s],
      [[55, 71, 29, 43], [19], :dir_o]
    ]

    # The assist's line in a room: the side its exit that leads on is on.
    def self.hint(side)
      PokeAccess::I18n.t(:anil_cave_hint, :dir => PokeAccess::I18n.t(side))
    end
  end
end

PokeAccess::Game.define("anil") do
  cave = PokeAccess::AnilLostCave
  mechanic(:state, cave::MAP) do
    auto
    sent_back :anil_cave_sent_back, :to => cave::BACK, :events => cave::WRONG
    cave::ROOMS.each do |box, exits, side|
      phase at(*box), :hint => lambda { cave.hint(side) }, :hidden => right_way(*exits)
    end
    solved(nil) { $game_switches[cave::BEATEN] }
  end
end
