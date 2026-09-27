# Insurgence afloat (games/insurgence/water.rb): its Game_Map#passable? lets a surfing player onto water only on its own
# tile and the one it faces, so the route search asks as if the player stood where it asks from. The map below answers
# as Insurgence's does; the profile's module alone is loaded, its override being the Insurgence process's.
unless defined?(PokeAccess::InsurgenceWater)
  path = File.join(Harness::ROOT, "games", "insurgence", "water.rb")
  eval(File.read(path)[/^module PokeAccess\r?\n.*?^end\r?\n/m], TOPLEVEL_BINDING, path)
end

module InsurgenceWaterSpec
  DELTA = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }

  # Loads a lake and makes the stub map answer water as Insurgence's passable? does: a water tile counts only while
  # surfing and only as the player's own tile or the one in front of it (009_Game_Map_.rb).
  def self.lake
    $game_map.load_grid(["#######",
                         "#~~~~~#",
                         "#~~~~~#",
                         "#~~~~~#",
                         "#######"])
    def $game_map.passable?(x, y, dir)
      dx, dy = InsurgenceWaterSpec::DELTA[dir]
      nx = x + dx; ny = y + dy
      return false if cell(nx, ny) == "#"
      return true unless cell(nx, ny) == "~" || cell(x, y) == "~"
      return false unless ($PokemonGlobal.surfing rescue false)
      p = $game_player
      fx, fy = InsurgenceWaterSpec::DELTA[p.direction]
      ok = lambda { |tx, ty| cell(tx, ty) != "~" || [tx, ty] == [p.x, p.y] || [tx, ty] == [p.x + fx, p.y + fy] }
      ok.call(x, y) && ok.call(nx, ny)
    end
    $PokemonGlobal.surfing = true
    $game_player.x = 1; $game_player.y = 1; $game_player.direction = 2
  end

  # Drops the Insurgence answer, back to the stub's own.
  def self.dry
    class << $game_map; remove_method(:passable?) rescue nil; end
    $PokemonGlobal.surfing = false
  end
end

Suite.define("insurgence water: afloat, the engine is asked as if the player stood where the search asks from") do
  w = PokeAccess::InsurgenceWater
  begin
    InsurgenceWaterSpec.lake
    falsy "asked plainly, water far from the player is a wall to Insurgence's passable?",
          $game_player.passable?(3, 2, 6)
    truthy "asked from where the step starts, it is water to surf on",
           w.as_if_at(3, 2, 6) { $game_player.passable?(3, 2, 6) }
    eq "the player is put back where it was, facing the way it faced",
       [$game_player.x, $game_player.y, $game_player.direction], [1, 1, 2]
    truthy "its own tile and the one it faces still pass as the game asks them",
           w.as_if_at(1, 1, 2) { $game_player.passable?(1, 1, 2) }
    raised = begin
               w.as_if_at(4, 3, 8) { raise "boom" }
               false
             rescue RuntimeError
               true
             end
    truthy "a failing question still puts the player back", raised && [$game_player.x, $game_player.y] == [1, 1]
  ensure
    InsurgenceWaterSpec.dry
  end
end

Suite.define("insurgence water: on foot nothing moves, whatever the question") do
  $PokemonGlobal.surfing = false
  $game_player.x = 5; $game_player.y = 5; $game_player.direction = 2
  seen = PokeAccess::InsurgenceWater.as_if_at(9, 9, 4) { [$game_player.x, $game_player.y, $game_player.direction] }
  eq "the block sees the player where it stands", seen, [5, 5, 2]
end
