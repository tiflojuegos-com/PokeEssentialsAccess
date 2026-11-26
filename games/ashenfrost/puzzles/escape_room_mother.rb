# Missing Mom: the lost mother (variable 45 at 1) waits in the third of the Eastridge Escape Room's rooms (map 137,
# EV5). The greeter of map 128 (EV2) draws the room at random (variable 1, 0 to 2) and the three share a name, so the
# assist says, as the player agrees to pay, whether the mother is in the room drawn.
module PokeAccess
  module AshenEscapeMother
    COUNTER_MAP = 128
    GREETER = 2
    LOST = 45
    ROOM = 1
    MOTHER_ROOM = 2
    COST = 5000

    # The line for the room drawn while the boy waits and the player can pay; nil otherwise.
    def self.room_line
      return nil unless $game_variables[LOST].to_i == 1
      money = (PokeAccess::Engine.player.money rescue nil)
      return nil if money && money < COST
      $game_variables[ROOM].to_i == MOTHER_ROOM ? :aff_mom_here : :aff_mom_elsewhere
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  mom = PokeAccess::AshenEscapeMother
  mechanic(:state, mom::COUNTER_MAP, :part => :aff_missing_mom) do
    auto
    on_reach mom::GREETER, { :choice => 0 }, lambda { mom.room_line }, :assist => true
  end
end
