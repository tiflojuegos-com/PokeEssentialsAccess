# The Sootopolis Gym (map 284): three fields of thin ice, 7, 19 and 40 tiles (EV6 to EV12, EV13 to EV31, EV32 to EV71).
# A tile cracks at the first step (self switch A, a count in V55, V56 or V57) and drops the player to the basement (map
# 285, same tile) at the second; once every tile of a field is cracked a parallel event fixes them (self switch B) and
# shows the stairs to the next one. Leaving the basement by its door starts the gym over (pbResetSootGym). The hint
# follows the tiles as they were stepped on, whatever way the player took, while the field can still be finished.
module PokeAccess
  module SeviiSootopolis
    MAP = 284
    BASEMENT = 285
    # Each field as [counter, tiles, the tile stepped on first, the plan], from sootopolis_plan.rb (generated): the plan
    # gives the next tile for every set of cracked tiles and tile stood on that can still finish the field.
    FIELDS = PokeAccess::SeviiSootopolisPlan::FIELDS
    TILES = (6..71).to_a

    def self.cracked?(ev)
      $game_self_switches[[MAP, ev, "A"]] ? true : false
    end

    def self.fixed?(ev)
      $game_self_switches[[MAP, ev, "B"]] ? true : false
    end

    # The field being crossed: the first whose tiles are not fixed yet, or nil.
    def self.field
      FIELDS.find { |_var, ids, _first, _plan| !fixed?(ids[0]) }
    end

    # A field's cracked tiles as its plan's bits.
    def self.bits(ids)
      n = 0
      ids.each_with_index { |id, i| n |= 1 << i if cracked?(id) }
      n
    end

    # The field's tile the player stands on, or nil off it.
    def self.standing(ids)
      ids.find do |id|
        ev = ($game_map.events[id] rescue nil)
        ev && ev.x == $game_player.x && ev.y == $game_player.y
      end
    end

    # The next tile to step on: the first one before any cracks, then the plan's for the cracked tiles and the one stood
    # on; nil once the field cannot be finished. Kept while the player's tile, the counters and the field stand.
    def self.next_tile
      f = field
      key = [$game_player.x, $game_player.y, f && f[0]] + FIELDS.map { |var, _ids, _first, _plan| $game_variables[var].to_i }
      return @next[1] if @next && @next[0] == key
      @next = [key, plan_tile]
      @next[1]
    end

    def self.plan_tile
      f = field
      return nil unless f
      _var, ids, first, plan = f
      n = bits(ids)
      return first if n == 0
      at = standing(ids)
      at ? plan[n * 100 + at] : nil
    end

    # A tile's name while it shows cracked and not fixed.
    def self.tile_name(ev)
      cracked?(ev.id) && !fixed?(ev.id) ? :sevii_soot_cracked : nil
    end

    def self.hint
      return nil unless field
      next_tile ? :sevii_soot_hint : :sevii_soot_off_path
    end
  end
end

PokeAccess::Game.define("sevii") do
  soot = PokeAccess::SeviiSootopolis

  mechanic(:state, soot::MAP) do
    auto
    name soot::TILES, lambda { |ev| soot.tile_name(ev) }, :when => false
    arrival_hint :sevii_soot_rule, :once => true
    soot::FIELDS.each do |var, ids, _first, _plan|
      count :sevii_soot_count, :var => var, :of => ids.length, :assist => true, :hide_zero => true
      ids.each do |tile|
        spot :event => tile, :label => :sevii_soot_next, :assist => true, :onto => true,
             :when => lambda { soot.next_tile == tile }
      end
    end
    hint lambda { soot.hint }
    solved(nil, :quiet => true) { $game_switches[276] }
  end

  mechanic(:state, soot::BASEMENT) do
    auto
    sent_back :sevii_soot_fell, :maps => [soot::MAP]
    hint :sevii_soot_basement_hint
    solved(nil, :quiet => true) { $game_switches[276] }
  end
end
