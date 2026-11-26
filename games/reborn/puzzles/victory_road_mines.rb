# Victory Road's mines (maps 784, 812, 786, 811, 788, 790 and 791): a cart is used with the action button; its self
# switch A starts a page that rolls it along the rails, the player aboard when it calls hookBeforeMineCart or alone (a
# load). It stops by the levers' switches and the station variable. With the assist, a cart says where it would go now.
module PokeAccess
  module RebornVrMines
    CART = /\ACart\d+\z/
    KINDS = { "minecart1" => :rbc2_cart, "minecart2" => :rbc2_cart_rocks, "minecart3" => :rbc2_cart_blast }
    STEPS = { 1 => [0, 1], 2 => [-1, 0], 3 => [1, 0], 4 => [0, -1], 5 => [-1, 1], 6 => [1, 1], 7 => [-1, -1], 8 => [1, -1] }
    FACING = { 1 => 2, 2 => 4, 3 => 6, 4 => 8 }
    TURNS = { 16 => 2, 17 => 4, 18 => 6, 19 => 8 }
    AHEAD = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }
    RIDE = /hookBeforeMineCart/
    MINE1 = [20, 22, 24, 26, 35, 36, 48, 51, 60, 61, 62, 69, 70, 72, 74, 76, 79, 80, 82, 89, 90]
    ATRIUM = [114, 116, 118, 130, 134, 136]
    LEVERS = { 784 => ATRIUM, 812 => ATRIUM, 786 => MINE1, 811 => MINE1, 788 => [], 790 => [33, 34, 35, 39],
               791 => [33, 34] }

    # The page a cart runs once used: the last whose conditions hold with its self switch A on.
    def self.ride_page(ev)
      PokeAccess::World::Mechanics::Links.live_page(ev, { [:self, ev.id, "A"] => true })
    end

    # A variable as the page has left it so far (sets), else as it stands; nil when the page set it to what this reader
    # cannot tell.
    def self.var(id, sets)
      k = [:var, id]
      sets.key?(k) ? sets[k] : $game_variables[id].to_i
    end

    # Whether a conditional branch (111) holds, with what the page has set so far; nil for a kind this reader does not
    # follow or a variable it cannot tell.
    def self.holds?(params, ev, sets)
      links = PokeAccess::World::Mechanics::Links
      case params[0]
      when 0
        k = [:switch, params[1]]
        on = sets.key?(k) ? sets[k] : (links.switch(params[1], {}) ? true : false)
        on == (params[2] == 0)
      when 1
        v = var(params[1], sets)
        o = params[2] == 0 ? params[3].to_i : var(params[3], sets)
        return nil if v.nil? || o.nil?
        [v == o, v >= o, v <= o, v > o, v < o, v != o][params[4].to_i]
      when 2 then links.self_switch(ev.id, params[1], { [:self, ev.id, "A"] => true }) == (params[2] == 0)
      end
    end

    # Keeps in sets what a Control Switches (121) or Control Variables (122) of the page leaves, for the branches after
    # it: a variable set, raised or lowered by a number; any other operation leaves it untold.
    def self.record(c, sets)
      pr = c.parameters
      if c.code == 121
        (pr[0]..pr[1]).each { |s| sets[[:switch, s]] = pr[2] == 0 }
        return
      end
      n = pr[3] == 0 ? pr[4].to_i : nil
      (pr[0]..pr[1]).each do |v|
        old = var(v, sets)
        sets[[:var, v]] = n.nil? || old.nil? || pr[2] > 2 ? nil : [n, old + n, old - n][pr[2]]
      end
    end

    # Moves a position by a route's steps, turning facing as the steps and turns do and stepping it ahead with Move
    # Forward; answers [position, facing].
    def self.walk(pos, face, route)
      (route || []).each do |m|
        s = STEPS[m.code]
        if s
          pos = [pos[0] + s[0], pos[1] + s[1]]
          face = FACING[m.code] || face
        elsif TURNS[m.code]
          face = TURNS[m.code]
        elsif m.code == 12 && AHEAD[face]
          pos = [pos[0] + AHEAD[face][0], pos[1] + AHEAD[face][1]]
        end
      end
      [pos, face]
    end

    # Where the cart's page leaves the cart and the player, from where the cart stands, as [cart, player] (player nil
    # when it never boards); :away when the branch taken moves the player off the map; nil when it cannot be told.
    def self.roll(ev, list)
      sets = {}
      cart = [0, 0]
      player = nil
      face = nil
      i = 0
      while i < list.length
        c = list[i]
        case c.code
        when 111
          ok = holds?(c.parameters, ev, sets)
          return nil if ok.nil?
          i = ok ? i + 1 : branch_end(list, i)
          next
        when 411
          i = branch_end(list, i)
          next
        when 201 then return :away
        when 121, 122 then record(c, sets)
        when 209
          route = (c.parameters[1].list rescue nil)
          if c.parameters[0] == 0
            cart = walk(cart, nil, route)[0]
          elsif c.parameters[0] == -1
            if player
              player, face = walk(player, face, route)
            else
              player = [0, 0]
            end
          end
        end
        i += 1
      end
      [cart, player]
    end

    # The index after the part of a branch that starts at i: a condition not taken goes on past its else or its end, an
    # else reached from the branch taken past its end.
    def self.branch_end(list, i)
      indent = list[i].indent
      j = i + 1
      j += 1 until j >= list.length || ([411, 412].include?(list[j].code) && list[j].indent == indent)
      j + 1
    end

    # Where using the cart takes it, said from where it stands: [dx, dy, rider], where the player lands for a ride, or
    # where the cart stops for one pushed; :away; nil for a cart whose page cannot be told.
    def self.ride(ev)
      page = ride_page(ev)
      list = page && page.list
      return nil unless list.is_a?(Array) && page.trigger.to_i >= 3
      out = roll(ev, list)
      return out unless out.is_a?(Array)
      rider = list.any? { |c| [355, 655].include?(c.code) && c.parameters[0].to_s =~ RIDE }
      at = rider && out[1] ? out[1] : out[0]
      [at[0], at[1], rider ? true : false]
    end

    # A cart's name by its load, and with the assist where it would go now.
    def self.cart_label(ev)
      key = KINDS[ev.character_name.to_s]
      return nil unless key
      i18n = PokeAccess::I18n
      name = i18n.t(key)
      return name unless PokeAccess::Puzzles.assist?
      r = ride(ev)
      return name unless r
      return i18n.t(:rbc2_cart_away, :name => name) if r == :away
      return i18n.t(:rbc2_cart_still, :name => name) if r[0] == 0 && r[1] == 0
      where = PokeAccess::Locator.dir_phrase(r[0], r[1])
      i18n.t(r[2] ? :rbc2_cart_takes : :rbc2_cart_rolls, :name => name, :where => where)
    end

    # A lever's name with its state: on while the page its switch shows stands.
    def self.lever_label(ev)
      page = PokeAccess::World::Mechanics::Links.live_page(ev, {})
      on = page && page.condition && (page.condition.switch1_valid rescue false)
      PokeAccess::I18n.t(on ? :rbc2_lever_on : :rbc2_lever_off)
    end
  end
end

PokeAccess::Game.define("reborn") do
  mines = PokeAccess::RebornVrMines
  mines::LEVERS.each do |map, levers|
    mechanic(:state, map, :part => :mines) do
      auto
      name mines::CART, lambda { |ev| mines.cart_label(ev) }
      name levers, lambda { |ev| mines.lever_label(ev) } unless levers.empty?
      arrival_hint :rbc2_mine_rule, :once => true
      hint :rbc2_mine_hint
    end
  end
end
