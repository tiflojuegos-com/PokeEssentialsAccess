# The mud slopes (events named mudbottom and mudtop, drawn as mudslide) of the routes and caves of Hoenn: touching the foot
# of one while facing up on a bike without hopping climbs two tiles, any other way slides the player a tile back down, and
# touching the top while facing down slides two tiles down.
module PokeAccess
  module HoennMudSlopes
    # The maps holding a slope.
    def self.maps
      [31, 34, 37, 62, 69, 76, 77, 83, 109]
    end

    # The names of the slope events.
    def self.slope
      /\Amud(?:bottom|top)/
    end

    # True when the move just made was a climb, a bike facing up that is not hopping.
    def self.climbed?
      $PokemonGlobal.bicycle && !($game_player.bike_hops rescue false) && $game_player.direction == 8
    end

    # What a forced move onto or off a slope says: nothing when it was a climb.
    def self.slid
      climbed? ? nil : :if_ho_mud_slid
    end
  end
end

PokeAccess::Game.define("infinitefusion_hoenn") do
  mechanic(:state, PokeAccess::HoennMudSlopes.maps) do
    auto
    name(/\Amudbottom/, :if_ho_mud_bottom)
    name(/\Amudtop/, :if_ho_mud_top)
    avoid(PokeAccess::HoennMudSlopes.slope)
    sent_back lambda { PokeAccess::HoennMudSlopes.slid }, :forced => true, :events => PokeAccess::HoennMudSlopes.slope
    on_use(/\Amudbottom/, :if_ho_mud_bike, :assist => true)
  end
end
