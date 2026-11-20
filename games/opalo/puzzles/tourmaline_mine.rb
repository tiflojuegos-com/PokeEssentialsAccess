# Opalo's mine carts of the Mina Turmalina (map 290): each cart (events 20, 42, 50 and 73) is boarded facing one way and
# carries the player along its rails, the way set by the levers that move the rails (switches 663, 665, 667 and 670) and by
# the end it stands at (switches 664, 666, 668, 669 and 672). A cart is named by the way it is boarded; with the assist, also
# by where it goes now. The carts are the one way from the arrival (50,15) to the stairs down (7..9,65), past rubble that
# the detonator (event 63) blows up with the dynamite of event 64 (switch 671). With the assist, a phase for each step of
# that way says the next lever, cart or item, by where the player stands and the switches; the rule was checked against
# every state the mine can reach, ledges, sensors and the carts' routes included.
module PokeAccess
  module OpaloMineCarts
    # Each cart's pages, lowest first: the switches the page waits for, the way the player faces to board, and the player's
    # shift from the tile they board from, read off the move route the page gives the player.
    PAGES = {
      20 => [[[], 4, [-22, -3]], [[664], 2, [22, 3]], [[663], 4, [-6, 10]], [[663, 664], 4, [6, -10]],
             [[665], 4, [-19, 10]], [[665, 666], 8, [19, -10]]],
      42 => [[[], 4, [-7, 9]], [[668], 8, [7, -9]], [[667], 4, [-7, -5]], [[668, 667], 2, [7, 5]]],
      50 => [[[], 6, [10, -6]], [[669], 2, [-10, 6]], [[667], 6, [18, 0]], [[669, 667], 4, [-18, 0]]],
      73 => [[[], 4, [-1, 13]], [[672], 4, [1, -13]], [[670], 4, [-24, -9]], [[672, 670], 8, [25, 9]]]
    }
    DIRS = { 2 => :dir_down, 4 => :dir_left, 6 => :dir_right, 8 => :dir_up }
    MAP = 290
    BLASTED = 671
    HOME = [20, 4, 35, 15]
    TRACK_B = [20, 4, 29, 25]
    LEVER_WEST = [21, nil, 20, 5]
    LEVER_TRACK_B = [31, nil, 30, 38]
    LEVER_CAVE = [37, nil, 8, 38]
    LEVER_SOUTH = [62, nil, 52, 73]
    CART2_BACK = [42, 2, 23, 36]
    CART3 = [50, 6, 29, 50]
    DYNAMITE = [64, nil, 54, 40]
    CART4 = [73, 4, 45, 57]
    CART4_SOUTH = [73, 4, 44, 70]
    CART4_BACK = [73, 8, 21, 60]
    DETONATOR = [63, nil, 18, 61]
    RETURN = [82, nil, 59, 17]
    STAIRS = [8, 65]
    START_CART = [15, 73]
    START_ITEM = 7
    WATER_ITEM = 8
    WATER_ITEM_AT = [31, 67]
    # Each step of the way down: [event, the way to face to board it or nil, x, y of the event then], or :stairs.
    STEPS = [HOME, LEVER_WEST, LEVER_TRACK_B, TRACK_B, CART2_BACK, LEVER_CAVE, CART3, DYNAMITE, CART4, LEVER_SOUTH,
             CART4_SOUTH, CART4_BACK, DETONATOR, RETURN, :stairs]

    # Whether (x, y) lies in the box [x0, x1, y0, y1].
    def self.inside?(x, y, box)
      x >= box[0] && x <= box[1] && y >= box[2] && y <= box[3]
    end

    # Whether the bag holds the dynamite, or the rubble is already blown up.
    def self.dynamite?
      $game_switches[BLASTED] || PokeAccess::World::Flags.bag(:DINAMITA).to_i > 0
    end

    # The next step for the player at (x, y): the action that starts a shortest way to the stairs down.
    def self.next_step(x, y)
      on = lambda { |s| $game_switches[s] ? true : false }
      return :stairs if on.call(BLASTED) && inside?(x, y, [0, 21, 58, 80])
      return RETURN if inside?(x, y, [55, 60, 16, 19])
      return (dynamite? ? DETONATOR : CART4_BACK) if inside?(x, y, [18, 21, 58, 64])
      return (on.call(670) == (dynamite? ? true : false) ? CART4_SOUTH : LEVER_SOUTH) if inside?(x, y, [44, 53, 66, 76])
      return (dynamite? ? CART4 : DYNAMITE) if inside?(x, y, [44, 56, 39, 60])
      return (on.call(665) ? TRACK_B : LEVER_TRACK_B) if inside?(x, y, [29, 50, 22, 44])
      return CART2_BACK if on.call(668) && on.call(667) && inside?(x, y, [20, 24, 32, 35])
      return (on.call(667) ? CART3 : LEVER_CAVE) if inside?(x, y, [0, 17, 31, 41])
      return CART3 if inside?(x, y, [0, 28, 31, 53])
      return (on.call(663) ? HOME : LEVER_WEST) if inside?(x, y, [0, 22, 0, 13])
      HOME
    end

    # The step the phases follow: held while an event runs, so a ride does not go through the steps it crosses.
    def self.step
      return @step if @step && ($game_system.map_interpreter.running? rescue false)
      @step = next_step($game_player.x, $game_player.y)
    end

    # Where (x, y) lies from the player.
    def self.from_player(x, y)
      PokeAccess::Puzzles.offset_phrase(x - $game_player.x, y - $game_player.y)
    end

    # The dynamite's name as the game gives it, or "" when it gives none.
    def self.dynamite_name
      PokeAccess::Data.item_id(:DINAMITA)[1].to_s
    rescue StandardError => e
      PokeAccess.swallowed(e)
      ""
    end

    # Forgets the step held through a ride, so a new visit starts from where the player arrives.
    def self.forget
      @step = nil
    end

    # The assist's line for the current step. A cart is said where it is boarded: where it stands, or where a sensor on the
    # way sends it back, said as such.
    def self.hint
      s = step
      return stairs_hint if s == :stairs
      id, dir, x, y = s
      at = from_player(x, y)
      return cart_hint(id, dir, x, y, at) if dir
      return item_line(:op_mine_next_item, :op_mine_next_pickup, at) if id == DYNAMITE[0]
      return item_line(:op_mine_next_detonator, :op_mine_next_detonator_plain, at) if id == DETONATOR[0]
      return [:op_mine_next_return, { :at => at }] if id == RETURN[0]
      [:op_mine_next_lever, { :at => at }]
    end

    # A step about the dynamite, named as the game names it, or the line without the name when the game gives none.
    def self.item_line(named, plain, at)
      item = dynamite_name
      item.empty? ? [plain, { :at => at }] : [named, { :at => at, :item => item }]
    end

    # A cart step: the cart where it is boarded and the way to face; while it still stands elsewhere, that it is sent back
    # there on the way.
    def self.cart_hint(id, dir, x, y, at)
      ev = $game_map.events[id]
      vars = { :at => at, :dir => PokeAccess::I18n.t(DIRS[dir]) }
      return [:op_mine_next_cart, vars] if ev.nil? || (ev.x == x && ev.y == y)
      [:op_mine_next_cart_back, vars]
    end

    # The stairs down and what the mine still keeps off the way: the item the cart back to the start leads to, and the
    # one across the water, reached by surfing.
    def self.stairs_hint
      parts = [PokeAccess::I18n.t(:op_mine_next_stairs, :at => from_player(STAIRS[0], STAIRS[1]))]
      unless $game_self_switches[[MAP, START_ITEM, "A"]]
        parts.push(PokeAccess::I18n.t(:op_mine_extra_start, :at => from_player(START_CART[0], START_CART[1])))
      end
      unless $game_self_switches[[MAP, WATER_ITEM, "A"]]
        parts.push(PokeAccess::I18n.t(:op_mine_extra_water, :at => from_player(WATER_ITEM_AT[0], WATER_ITEM_AT[1])))
      end
      PokeAccess.sentences(parts)
    end

    # The page of a cart the game runs now: the last one whose switches are all on.
    def self.page(id)
      PAGES[id].select { |pg| pg[0].all? { |s| $game_switches[s] } }.last
    end

    # A cart's name: the way it is boarded and, with the assist, where it goes.
    def self.label(ev)
      pg = page(ev.id)
      dir = PokeAccess::I18n.t(DIRS[pg[1]])
      return [:op_cart_named, { :dir => dir }] unless PokeAccess::Puzzles.assist?
      [:op_cart_named_ride, { :dir => dir, :to => PokeAccess::Puzzles.offset_phrase(pg[2][0], pg[2][1]) }]
    end

    # What a cart does to the player who uses it now: where it carries them, or the way to face to board it.
    def self.ride_line(ev)
      pg = page(ev.id)
      return [:op_cart_named, { :dir => PokeAccess::I18n.t(DIRS[pg[1]]) }] unless $game_player.direction == pg[1]
      [:op_cart_ride_said, { :to => PokeAccess::Puzzles.offset_phrase(pg[2][0], pg[2][1]) }]
    end
  end
end

PokeAccess::World::Epoch.on(:map) { PokeAccess::OpaloMineCarts.forget }

PokeAccess::Game.define("opalo") do
  carts = PokeAccess::OpaloMineCarts
  mechanic(:state, 290) do
    auto
    name carts::PAGES.keys, lambda { |ev| carts.label(ev) }
    on_use carts::PAGES.keys, lambda { |ev| carts.ride_line(ev) }
    carts::STEPS.each do |s|
      phase lambda { PokeAccess::Puzzles.assist? && carts.step == s }, :hint => lambda { carts.hint }
    end
  end
end
