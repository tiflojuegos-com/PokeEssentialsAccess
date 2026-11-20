# The grapple of the Combretum mines (maps 131, 133, 134, 136 and 137): with the AGARRAR item (switch 99 lights the
# anchor rocks, "Roca N"), a touch tile before a gap, walked onto facing the rock across, throws the player over it. The
# routes already take those throws while the item is in the bag. The lit rocks are named for all; with the puzzle
# assist, each throw tile and the way it throws, while the item is in the bag.
module PokeAccess
  module AwakeningGrapple
    # map => { touch event => the facing it throws toward }
    THROWS = { 131 => { 14 => 6, 15 => 6, 16 => 4, 17 => 4 },
               133 => { 4 => 6, 7 => 4, 17 => 6, 18 => 4, 19 => 2, 20 => 2, 21 => 8, 22 => 8 },
               134 => { 9 => 6, 10 => 4, 11 => 4, 12 => 6, 13 => 2, 14 => 8, 17 => 6, 18 => 4 },
               136 => { 13 => 6, 14 => 4, 15 => 4, 16 => 6, 17 => 2, 18 => 8 },
               137 => { 9 => 6, 10 => 4, 11 => 4, 12 => 6 } }

    # True while the grapple is in the bag.
    def self.held?; (PokeAccess::World::Flags.bag(:AGARRAR).to_i > 0 rescue false); end
  end
end

PokeAccess::Game.define("awakening") do
  grapple = PokeAccess::AwakeningGrapple
  grapple::THROWS.each do |map, throws|
    mechanic(:state, map, :part => :grapple) do
      auto
      name(/\ARoca \d+\z/, :awk_hook_rock)
      throws.each do |ev, dir|
        name ev, lambda { |_ev| [:awk_hook_throw, { :dir => PokeAccess::Puzzles.face_name(dir) }] }, :assist => true,
             :when => lambda { |_ev| grapple.held? }
      end
    end
  end
end
