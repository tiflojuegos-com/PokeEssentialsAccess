# Griselda's treasures: floor panels (tile 814) before shut doors in the Wispy Ruins (map 489), the Wispy Chasm (maps 12
# and 508) and the Wispy Treasury (map 507). Each checks the badges when stepped on: enough opens its door and changes
# its tile, too few only glows. PANELS holds each panel by map with the badges its success line names.
module PokeAccess
  module RejuvGriselda
    PANELS = {
      12 => { 100 => 1, 101 => 9, 120 => 2 },
      489 => { 43 => 4, 66 => 5 },
      507 => { 29 => 17 },
      508 => { 1 => 8, 2 => 3, 21 => 7, 49 => 6, 62 => 9 }
    }
    TILE = 814

    # True while a panel still shows its unlit tile.
    def self.unopened?(ev)
      (ev.tile_id rescue 0).to_i == TILE
    end

    # A panel's name, and with the puzzle assist the badges it asks for.
    def self.label(map, ev)
      return :rj_griselda_panel unless PokeAccess::Puzzles.assist?
      [:rj_griselda_panel_badges, { :n => PANELS[map][ev.id] }]
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  griselda = PokeAccess::RejuvGriselda
  griselda::PANELS.each do |map, panels|
    mechanic(:state, map, :part => :treasure_panels) do
      auto
      name panels.keys, lambda { |ev| griselda.label(map, ev) }, :when => lambda { |ev| griselda.unopened?(ev) }
    end
  end
end
