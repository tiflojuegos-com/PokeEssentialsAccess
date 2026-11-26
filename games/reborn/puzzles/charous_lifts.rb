# Charous Hall, the Elite Four's second room (map 819): four platforms over the drop run up and down on their own by a
# parallel page and a timer, and the player rides one stood on while it rests: 1 (event 21) and 2 (14) join the bottom
# floor to the middle, 3 (27) and 4 (26) the middle to the top. With the assist each lower stop is listed.
module PokeAccess
  module RebornLifts
    MAP = 819
    # Event => [number, row it rests on below, row it rests on above].
    LIFTS = { 21 => [1, 87, 79], 14 => [2, 87, 79], 27 => [3, 69, 60], 26 => [4, 69, 60] }
    # Where each one rests below, by its number; the patches drawn beside them (events 17, 44 and 45) are passable
    # floor.
    STOPS = { 1 => [20, 87], 2 => [13, 87], 3 => [14, 69], 4 => [19, 69] }
    # The lower halves each platform drags along, walked through.
    HALVES = [15, 16, 28, 29]

    # A platform's number and where it is now.
    def self.label(ev)
      n, below, above = LIFTS[ev.id]
      moving = ev.respond_to?(:moving?) && ev.moving?
      where = :rbf_lift_moving
      where = :rbf_lift_down if !moving && ev.y == below
      where = :rbf_lift_up if !moving && ev.y == above
      [:rbf_lift, { :n => n, :where => PokeAccess::I18n.t(where) }]
    end
  end
end

PokeAccess::Game.define("reborn") do
  lifts = PokeAccess::RebornLifts
  mechanic(:state, lifts::MAP) do
    auto
    name lifts::LIFTS.keys, lambda { |ev| lifts.label(ev) }
    hide lifts::HALVES
    arrival_hint :rbf_lifts_rule
    lifts::STOPS.each do |n, at|
      spot :at => at, :label => [:rbf_lift_board, { :n => n }], :assist => true
    end
    hint :rbf_lifts_hint
  end
end
