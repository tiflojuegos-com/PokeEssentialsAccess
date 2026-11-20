# Lionel's distortion world (map 268): invisible walls throw the player when bumped and turn their sprite a quarter
# left (switch 355) or right (501); turned, the keys still move the player the usual way but face them elsewhere, so an
# event in front is not the one the key points at. Four small crystals each add one to variable 173; with the four, the
# exit portal (event 48) shows. The game never tells how many there are, so the count goes with the assist alone.
module PokeAccess
  module RealideaLionel
    MAP = 268
    CRYSTALS = [12, 18, 19, 20]
    PORTAL = 48
    FOUND = 173

    # The line telling which way each key faces the player while the sprite is turned, or nil while it is not.
    def self.turned
      return :rea_lionel_turned_left if $game_switches[355]
      return :rea_lionel_turned_right if $game_switches[501]
      nil
    end
  end
end

PokeAccess::Game.define("realidea") do
  world = PokeAccess::RealideaLionel
  mechanic(:state, world::MAP) do
    auto
    name world::CRYSTALS, :rea_lionel_crystal
    name world::PORTAL, :rea_lionel_portal
    count :rea_lionel_crystals, :var => world::FOUND, :of => 4, :assist => true
    info { world.turned }
    arrival_hint :rea_lionel_rule
    hint :rea_lionel_hint
  end
end
