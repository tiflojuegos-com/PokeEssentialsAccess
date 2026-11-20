# Perseida's Tower Ruins on Route 7 (map 117): two far levers (EV66, EV54) each light a torch beside the door lever (S179
# lights EV28, S180 lights EV29), and with both on the door lever (EV30) opens the door EV55 and sets V71 to 11. The way
# north crosses a false wall (#EOT HIDE, 9 to 12, 22 to 23) with the Dark Gem on, and then a row the gem shows as a wall
# (#EOT SHOW, 20 to 24, 11), crossed with the gem off. On Route 7 (map 57), the way in crosses the false wall at 34,7.
module PokeAccess
  module PerseidaTower
    MAP = 117
    LEVERS = [66, 54]
    TORCHES = { 28 => 179, 29 => 180 }
    DOOR_LEVER = 30
    QUEST = 71
    DONE = 11
    ROUTE = 57
    ROUTE_WALL = [34, 7]
    FOUND = 9

    # True while Elvira's quest has the player look for the way into the ruins.
    def self.on_way?
      v = $game_variables[QUEST].to_i
      v >= FOUND && v < DONE
    end

    # A torch's name, lit or out as its switch has it.
    def self.torch_label(ev)
      $game_switches[TORCHES[ev.id]] ? :perseida_tower_torch_lit : :perseida_tower_torch_out
    end

    # True once the door lever has opened the way out.
    def self.open?
      $game_variables[QUEST].to_i >= DONE
    end
  end
end

PokeAccess::Game.define("perseida") do
  tower = PokeAccess::PerseidaTower
  mechanic(:state, tower::MAP) do
    auto
    name tower::LEVERS, :perseida_tower_lever
    name tower::DOOR_LEVER, :perseida_tower_door_lever
    name tower::TORCHES.keys, lambda { |ev| lambda { tower.torch_label(ev) } }
    count :perseida_tower_levers, :switches => tower::TORCHES.values, :assist => true
    spot :at => [10, 23], :label => :perseida_tower_false_wall, :assist => true, :when => lambda { !tower.open? }
    spot :at => [22, 11], :label => :perseida_tower_gem_off, :assist => true, :when => lambda { !tower.open? }
    hint :perseida_tower_hint
    active { PokeAccess::Puzzles.assist? && !tower.open? }
    solved { tower.open? }
  end

  mechanic(:state, tower::ROUTE) do
    auto
    spot :at => tower::ROUTE_WALL, :label => :perseida_tower_false_wall, :assist => true, :when => lambda { tower.on_way? }
  end
end
