# The Distortion World of Sevii's postgame (maps 274 and 587; map 588 is the turning scene between them). On the first
# map a floating rock walls in the portal's landing until the tile at its right is stepped on (pbFadeOutOpacity lends
# its tile events through), a plant rises across a side corridor, and the way to the exit crosses a sideways waterfall
# (terrain tags 25 and 26, pbAscendWaterfallDW): surfed to from the west, climbed facing right with the action button,
# slid down leftwards from its crest. On the second map a floating island, unseen and yet solid on arrival, bridges the
# gap to the north: the tile at the landing's right raises it, the tiles right of and below that one let it fall.
module PokeAccess
  module SeviiDistortion
    FIRST = 274
    SECOND = 587
    ROCK = [10, 11, 12, 13]
    ROCK_TILE = [55, 39]
    PLANT = (17..28).to_a
    PLANT_TILES = [29, 30]
    FALL = 25
    CREST = 26
    FALL_FOOT = [32, 4]
    ISLAND = [5, 6, 7, 8, 9, 10]
    ISLAND_TILE = [13, 6]
    ISLAND_DROPS = [12, 13]
    DONE = 324

    # True while a fading event shows and stands: seen, and not lent through.
    def self.shown?(ev)
      ev && ev.opacity.to_i > 0 && !ev.through ? true : false
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    def self.rock_up?
      shown?($game_map.events[ROCK[0]])
    end

    def self.island_up?
      shown?($game_map.events[ISLAND[0]])
    end

    # True on a tile of the sideways waterfall or its crest.
    def self.fall?(x, y)
      [FALL, CREST].include?(PokeAccess::World::Terrain.number(x, y))
    end

    # The climb from (x, y) facing right onto the waterfall, as an assisted step pressed with the action button: it ends
    # on the first tile past the falls. Nil facing any other way.
    def self.climb(x, y, dir, lvl)
      return nil unless dir[2] == 6
      lx = x + 1
      lx += 1 while lx < $game_map.width && fall?(lx, y)
      return nil if lx >= $game_map.width
      PokeAccess::Routes::Moves::Step.new(lx, y, lvl, 1, { :kind => :act, :face => 6, :x => x, :y => y })
    end

    # Where arriving on the crest facing left ends: slid down past the falls. Nil arriving any other way.
    def self.descent(x, y, d)
      return nil unless d == 4
      lx = x
      lx -= 1 while lx > 0 && fall?(lx, y)
      [lx, y]
    end

    # The first map's hint: the rock's tile while it walls the landing, then the waterfall.
    def self.first_hint
      rock_up? && $game_player.x >= ROCK_TILE[0] ? :sevii_dw_rock_hint : :sevii_dw_fall_hint
    end
  end
end

PokeAccess::Game.define("sevii") do
  dw = PokeAccess::SeviiDistortion
  shown = lambda { |ev| dw.shown?(ev) }
  unseen = lambda { |ev| !dw.shown?(ev) }

  mechanic(:state, dw::FIRST) do
    auto
    name dw::ROCK, :sevii_dw_rock, :grouped => true, :when => shown
    name dw::PLANT, :sevii_dw_plant, :grouped => true, :when => shown
    hide [dw::ROCK, dw::PLANT], :when => unseen
    avoid dw::PLANT_TILES
    spot :at => dw::ROCK_TILE, :label => :sevii_dw_rock_tile, :assist => true, :onto => true, :when => lambda { dw.rock_up? }
    spot :at => dw::FALL_FOOT, :label => :sevii_dw_fall, :onto => true
    hint lambda { dw.first_hint }
    solved(nil, :quiet => true) { $game_switches[dw::DONE] }
  end

  mechanic(:state, dw::SECOND) do
    name dw::ISLAND, :sevii_dw_island, :grouped => true, :when => shown
    hide dw::ISLAND, :when => unseen
    avoid dw::ISLAND_DROPS
    spot :at => dw::ISLAND_TILE, :label => :sevii_dw_island_tile, :assist => true, :onto => true,
         :when => lambda { !dw.island_up? }
    phase(lambda { dw.island_up? }, :title => :sevii_dw_island_up)
    phase(lambda { true }, :title => :sevii_dw_island_down)
    hint :sevii_dw_island_hint
    solved(nil, :quiet => true) { $game_switches[dw::DONE] }
  end

  assisted_step(:front_tags => [dw::FALL], :maps => [dw::FIRST]) { |x, y, dir, lvl| dw.climb(x, y, dir, lvl) }
  terrain_rule(:tags => [dw::CREST], :maps => [dw::FIRST]) { |x, y, d| dw.descent(x, y, d) }
  camera_tile(:tags => [dw::FALL, dw::CREST], :maps => [dw::FIRST]) { |_x, _y| PokeAccess::I18n.t(:sevii_dw_fall) }
end
