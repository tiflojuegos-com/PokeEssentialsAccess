# Sevii's spin floors (0243_Spin Tiles, with Marin's 0215_Common Tiles): an arrow tile is a wall that runs common event 3
# when bumped, unless an event stands on it. pbSpinTile then moves the player onto it and on through anything, turning
# at each arrow (terrain tags 20 to 23: up, down, right, left) and keeping its way elsewhere, until it reaches a stop tile
# (tag 24). The routes take a press toward an arrow as that whole move. The floors: the Rocket Warehouse of the past (map
# 202), where the grunt's outfit lies across the arrows, the Rocket HQ (map 234) and two rooms of the Trick House (maps 565
# and 568).
module PokeAccess
  module SeviiSpin
    # The common event the arrow tiles run, and the stop tile's terrain tag.
    COMMON_EVENT = 3
    STOP = 24
    # Terrain tag => direction of each arrow.
    ARROWS = { 20 => 8, 21 => 2, 22 => 6, 23 => 4 }
    WAREHOUSE = 202
    FLOORS = [202, 234, 565, 568]

    # The arrow tiles of the current map, as {[x, y] => true}, read once per map from its tileset's common events.
    def self.arrows
      id = ($game_map.map_id rescue nil)
      return @arrows if @arrows_map == id && @arrows
      @arrows_map = id
      @arrows = scan
    end

    # Every tile of the map whose tile, on any layer, runs COMMON_EVENT.
    def self.scan
      found = {}
      events = ($game_map.tileset.common_events rescue nil)
      return found unless events
      data = $game_map.data
      (0...$game_map.width).each do |x|
        (0...$game_map.height).each do |y|
          [2, 1, 0].each do |z|
            tile = data[x, y, z]
            next if tile.nil? || tile < 384
            list = events[tile - 384]
            next unless list && list.include?(COMMON_EVENT)
            found[[x, y]] = true
            break
          end
        end
      end
      found
    rescue StandardError => e
      PokeAccess.swallowed(e)
      {}
    end

    # True if (x,y) has an arrow tile beside it.
    def self.beside_arrow?(x, y)
      a = arrows
      return false if a.empty?
      a[[x + 1, y]] || a[[x - 1, y]] || a[[x, y + 1]] || a[[x, y - 1]] ? true : false
    end

    # Where a press from (x,y) toward dir ends: the spin's stop tile with its one press (ridden, not hopped), false for a
    # spin that never stops, nil when the tile ahead is no arrow or an event stands on it.
    def self.landing(x, y, dir)
      nx = x + dir[0]; ny = y + dir[1]
      return nil unless arrows[[nx, ny]]
      return nil unless PokeAccess::World::Events.at(nx, ny).empty?
      stop = spin(nx, ny)
      stop ? [stop[0], stop[1], 1] : stop
    end

    # The stop tile a spin that starts on the arrow at (x,y) reaches, or false when it would leave the map or never stop.
    def self.spin(x, y)
      terrain = PokeAccess::World::Terrain
      face = ARROWS[terrain.number(x, y)]
      return false unless face
      PokeAccess::Routes::Moves::ARRIVAL_CAP.times do
        dd = PokeAccess::DIR_DELTA[face]
        x += dd[0]; y += dd[1]
        return false unless ($game_map.valid?(x, y) rescue false)
        tag = terrain.number(x, y)
        return [x, y] if tag == STOP
        face = ARROWS[tag] || face
      end
      false
    end

    # What the free camera says of a floor's tile: an arrow and its way, or the stop tile; nil elsewhere.
    def self.tile_line(x, y)
      tag = PokeAccess::World::Terrain.number(x, y)
      return PokeAccess::I18n.t(:sevii_spin_stop) if tag == STOP
      d = ARROWS[tag]
      d ? PokeAccess::I18n.t(:sevii_spin_arrow, :dir => PokeAccess::Routes::Text.dir(d)) : nil
    end

    # The grunt whose outfit the warehouse gives: the one that matches the player's look (variable 33).
    def self.outfit_grunt
      $game_variables[33].to_i == 1 ? 2 : 5
    end
  end
end

PokeAccess::Game.define("sevii") do
  spin = PokeAccess::SeviiSpin

  terrain_exit(:maps => spin::FLOORS, :tiles => lambda { |x, y| spin.beside_arrow?(x, y) }) do |x, y, dir|
    spin.landing(x, y, dir)
  end
  camera_tile(:maps => spin::FLOORS, :tags => spin::ARROWS.keys + [spin::STOP]) { |x, y| spin.tile_line(x, y) }

  mechanic(:state, spin::FLOORS, :part => :spin) do
    auto
    arrival_hint :sevii_spin_rule, :once => true
  end

  mechanic(:state, spin::WAREHOUSE, :part => :outfit) do
    auto
    [2, 5].each do |grunt|
      spot :event => grunt, :label => :sevii_outfit_grunt, :assist => true, :when => lambda { spin.outfit_grunt == grunt }
    end
    hint :sevii_outfit_hint
    solved(nil, :quiet => true) { $game_switches[86] }
  end
end
