# First gym, Ciudad Grisalla (map 20): before each of three musketeers lie three tiles painted with a type, touch events
# with no graphic (11 to 19) that ask whether it is super effective against Fighting. A yes fights, harder on a wrong type,
# and turns the musketeer's switch on (84, 85, 86); var 63 counts the battles, and three bring the lifts. The tiles go by
# the type the game names; with the assist, the right one of each musketeer says so.
PokeAccess::Game.define("pokemon_z") do
  tiles = { 11 => [:POISON, 84], 12 => [:WATER, 84], 13 => [:FLYING, 84], 14 => [:BUG, 85], 15 => [:ROCK, 85],
            16 => [:PSYCHIC, 85], 17 => [:GHOST, 86], 18 => [:DRAGON, 86], 19 => [:FAIRY, 86] }
  right = [13, 16, 19]
  label = lambda do |ev|
    type = (PokeAccess::Data.type_name(PBTypes.const_get(tiles[ev.id][0])) rescue nil)
    if type.nil? || type.to_s.empty?
      :z_gym1_tile_plain
    else
      [right.include?(ev.id) && PokeAccess::Puzzles.assist? ? :z_gym1_tile_right : :z_gym1_tile, { :type => type }]
    end
  end
  mechanic(:state, 20) do
    auto
    name tiles.keys.sort, label, :when => lambda { |ev| !$game_switches[tiles[ev.id][1]] }
  end
end
