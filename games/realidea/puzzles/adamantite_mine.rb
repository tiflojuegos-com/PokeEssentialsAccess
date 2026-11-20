# The Adamantite Mine (map 34): four levers, each with three positions (variables 37, 38, 41 and 44, from 0), set the
# rails, and a cart rides to the cart the rails lead to, or nowhere. Three networks: the south one (levers 1 and 2), the
# middle one (lever 5) and the north one (lever 8), whose rails may also end on the platform at (25, 5). The levers and
# carts are named by what the rails show: a lever's position, and where a cart would go. A cart whose page is drawn
# transparent, as the ones waiting at the far end of a ride, is left out of the lists.
module PokeAccess
  module RealideaMine
    MAP = 34
    LEVERS = { 4 => 37, 11 => 38, 22 => 41, 33 => 44 }
    CARTS = { 8 => [12, 68], 14 => [48, 69], 15 => [26, 52], 39 => [35, 55], 34 => [46, 56], 35 => [47, 34],
              36 => [7, 46], 37 => [6, 21], 38 => [25, 8], 61 => [25, 26] }
    PLATFORM = [25, 5]

    # A lever variable's position, from 0.
    def self.at(var)
      $game_variables[var].to_i
    end

    # Where a cart rides with the rails as they stand: another cart's event, :platform, or nil for nowhere.
    def self.destination(id)
      a = at(37)
      b = at(38)
      case id
      when 8 then a == 1 ? 15 : (a == 0 ? { 0 => 14, 1 => 39 }[b] : nil)
      when 14 then b == 2 ? 39 : (b == 0 ? { 0 => 8, 2 => 15 }[a] : nil)
      when 15 then a == 1 ? 8 : (a == 2 ? { 0 => 14, 1 => 39 }[b] : nil)
      when 39 then b == 2 ? 14 : (b == 1 ? { 0 => 8, 2 => 15 }[a] : nil)
      when 34 then { 2 => 35, 1 => 36 }[at(41)]
      when 35 then { 2 => 34, 0 => 36 }[at(41)]
      when 36 then { 1 => 34, 0 => 35 }[at(41)]
      when 37 then { 0 => 61, 1 => :platform }[at(44)]
      when 38 then { 1 => 37, 2 => 61 }[at(44)]
      when 61 then { 0 => 37, 2 => :platform }[at(44)]
      end
    end

    # The name of a cart: where it would ride, from where it stands.
    def self.cart(ev)
      to = destination(ev.id)
      return :rea_mine_cart_still unless to
      x, y = to == :platform ? PLATFORM : CARTS[to]
      [:rea_mine_cart, { :where => PokeAccess::Puzzles.offset_phrase(x - ev.x, y - ev.y) }]
    end

    # True while the cart is drawn see-through: not there for the eye.
    def self.unseen?(ev)
      (ev.opacity rescue 255).to_i == 0
    end

    # The name of a lever, with its position.
    def self.lever(ev)
      [:rea_mine_lever, { :n => at(LEVERS[ev.id]) + 1 }]
    end
  end
end

PokeAccess::Game.define("realidea") do
  mine = PokeAccess::RealideaMine
  mechanic(:state, mine::MAP) do
    auto
    name mine::LEVERS.keys, lambda { |ev| mine.lever(ev) }
    name mine::CARTS.keys, lambda { |ev| mine.cart(ev) }
    hide mine::CARTS.keys, :when => lambda { |ev| mine.unseen?(ev) }
  end
end
