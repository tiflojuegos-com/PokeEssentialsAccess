# The Houndour Game on Evergreen Hill (map 705): the man (EV42) has the middle of three Houndour (EV39 to EV41) jump for
# the prize and shuffle (self switch A); EV40's yes gives the Toxic Orb (self switch B). The prize stays in the middle
# one. They are named by their place in the row; the assist says which holds it.
module PokeAccess
  module AshenHoundourGame
    MAP = 705
    HOST = 42
    DOGS = [39, 40, 41]
    PLACES = [:aff_houndour_left, :aff_houndour_middle, :aff_houndour_right]

    # Whether the game is on: the man has shuffled them and nobody has guessed right yet.
    def self.playing?
      $game_self_switches[[MAP, HOST, "A"]] && !won? ? true : false
    end

    # Whether the prize has been won.
    def self.won?
      $game_self_switches[[MAP, HOST, "B"]] ? true : false
    end

    # A Houndour's name by its place in the row, left to right, while the game is on; nil otherwise.
    def self.place_label(ev)
      return nil unless playing?
      xs = DOGS.map { |id| ($game_map.events[id].x rescue nil) }.compact.sort
      i = xs.index(ev.x)
      i ? PLACES[i] : nil
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  game = PokeAccess::AshenHoundourGame
  mechanic(:state, game::MAP, :part => :aff_houndour) do
    auto
    name game::DOGS, lambda { |ev| game.place_label(ev) }, :when => lambda { |_ev| game.playing? }
    on_reach game::HOST, { :choice => 0 }, :aff_houndour_shuffle
    on_reach game::HOST, { :choice => 0 }, :aff_houndour_prize, :assist => true
    right_choice game::DOGS, :takes => :item
    hint :aff_houndour_prize
    active { PokeAccess::Puzzles.assist? && game.playing? }
    solved(nil, :quiet => true) { game.won? }
  end
end
