# Vitro's gym of Ecruteak (Gimnasio Iris, map 35): a narrow walkway in the dark from the entrance to Morty (event 2), with
# dead-end branches and trainers on the way. Its edge tiles, and nothing else on the map, carry terrain tag 2, and a parallel
# event (event 3) sends a player standing on one back to the entrance (12, 42); past the edge lies only empty floor. The exit
# door (12, 48) is on an edge tile too, so walking onto it sends the player back before its touch fires. The map is dark
# past a circle of two tiles round the player (0338_Dark Maps: radius 64, opacity 255, no Flash), so the edge is named
# within it, or anywhere with the puzzle assist, and is no surface past it; routes keep off it with the assist alone. The
# move back is said; the door's tile is named as the exit, and a move back from
# it says that the exit sends back too, and that an Escape Rope or Dig gets out while the game keeps an escape point (only a
# cave's entrance sets one, and its exit clears it; Fly is refused indoors). The guide in the void (event 14) is never
# reached. With the assist, the way to Morty from where the player stands. Switch 7 is the badge.
module PokeAccess
  module VitroEcruteak
    MAP = 35
    MORTY = [6, 1]
    EXIT = [12, 48]
    # The darkness's circle round the player, in tiles (INITIAL_DARKNESS_CIRCLE, 64 pixels).
    LIGHT = 2

    # True on an edge tile of the walkway, on this map.
    def self.edge?(x, y)
      $game_map.map_id == MAP && PokeAccess::World::Terrain.number(x, y) == 2
    end

    # True where (x, y) lies in the light round the player.
    def self.lit?(x, y)
      dx = x - $game_player.x
      dy = y - $game_player.y
      dx * dx + dy * dy <= LIGHT * LIGHT
    end

    # The label of an edge tile here: the exit door's own, the edge's in the light or with the assist, else no surface;
    # nil elsewhere.
    def self.label(x, y)
      return nil unless edge?(x, y)
      return :vitro_ecruteak_exit_tile if [x, y] == EXIT
      PokeAccess::Puzzles.assist? || lit?(x, y) ? :vitro_ecruteak_edge : false
    end

    # What a move back from the exit door says (from it, or from the tile above, its only way in, as the move began): with an escape point kept, the ways out that use it.
    def self.exit_back
      point = ($PokemonGlobal.escapePoint rescue nil)
      point.is_a?(Array) && !point.empty? ? :vitro_ecruteak_exit_rope : :vitro_ecruteak_exit_back
    end

    # The way on foot to Morty from where the player stands, or nil when there is none or the player is beside him.
    def self.hint
      plan = PokeAccess::Routes::Planner.plan(MORTY[0], MORTY[1])
      return nil unless plan.kind == :walk && plan.route && !plan.route.empty?
      [:vitro_ecruteak_way, { :steps => PokeAccess::Routes::Text.steps(plan.route) }]
    end
  end
end

PokeAccess::Game.define("vitro") do
  terrain_rule(:tags => [2], :assist => true) { |x, y, _d| PokeAccess::VitroEcruteak.edge?(x, y) ? false : nil }
  PokeAccess::World::Terrain.label_rule { |x, y| PokeAccess::VitroEcruteak.label(x, y) }

  mechanic(:state, PokeAccess::VitroEcruteak::MAP, :part => :walkway) do
    hide 14
    phase lambda { true }, :title => :vitro_dark_area, :quiet => true, :hint => lambda { PokeAccess::VitroEcruteak.hint }
    sent_back lambda { PokeAccess::VitroEcruteak.exit_back }, :from => [12, 12, 47, 48], :to => [12, 42]
    sent_back :vitro_ecruteak_fell, :to => [12, 42]
    solved { $game_switches[7] }
    arrival_hint :vitro_ecruteak_rule
  end
end
