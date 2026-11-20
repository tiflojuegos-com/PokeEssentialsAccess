# Vitro's Ruins of Alph after the League. Map 50: four tile puzzles (events 1, 55, 56, 57, pbTilePuzzle, done from the tile
# below each slab facing up) turn switches 72 to 75 on and drop the player into the chamber (map 52); once solved, the floor
# below each (events 2 to 5) is a hole down to it, so a solved one is no more listed. Four walls (events 38, 46, 47, 48) show a
# word in Unown (UnownMessage, which easy_unown_text reads) and give way to a room of items once their switch is on: 69 by an
# Escape Rope used at (24, 4), 67 by reading the wall with a Water Stone in the bag, 68 by Flash used at (58, 4) (the handlers
# of 0338_Dark Maps, which mkxp-z loads over 0121's, accept it there though the map is not dark), and 66 by reading the wall
# with Ho-Oh in the party. Reading walls 2 and 4 is a use core already tells the opening of, so those say nothing more. Map 52: the
# door (event 7) opens only once Green (event 8, page 3) opens it, with variable 44 at 2: that takes the four puzzles (variable
# 17 at 4), the League (switch 12) and the Mega Ring (switch 61), then the battle with Green in the ruins outside (map 49).
# Map 155: the pillar (event 3) asks for a word, compared in a script, and leads to map 156.
module PokeAccess
  module VitroAlph
    # Each tile puzzle's event and the switch its solution turns on.
    TILES = { 1 => 72, 55 => 73, 56 => 74, 57 => 75 }
    # Each wall's event and the switch that opens it.
    WALLS = { 38 => 69, 46 => 67, 47 => 68, 48 => 66 }
    # The walls that open as they are read.
    READ_WALLS = PokeAccess::World::Mechanics.picked([46, 48])

    # True once the tile puzzle of event ev is solved.
    def self.solved_tile?(ev); $game_switches[TILES[ev.id]] ? true : false; end

    # The line for wall n (event id) opening, but for one that opened as the player read it, which core tells.
    def self.wall_line(id, n)
      return nil if READ_WALLS[id] && PokeAccess::Puzzles::Auto.last_used_among?(PokeAccess::World::Mechanics.picked([id]))
      [:vitro_alph_wall_opened, { :n => n }]
    end

    # The step toward the open door of map 52, with the assist.
    def self.door_hint
      return :vitro_alph_door_green if $game_variables[44] >= 2
      :vitro_alph_door_later
    end

    # The word the pillar's page compares the entry with, translated as the game's _I does at that moment, or nil.
    def self.pillar_word
      ev = $game_map.events[3]
      list = ev && PokeAccess.ivar(ev, :@list)
      (list || []).each do |cmd|
        next unless cmd.code == 111 && cmd.parameters[0] == 12
        word = cmd.parameters[1].to_s[/unownWord == _I\("([^"]+)"\)/, 1]
        next unless word
        return defined?(_I) ? (_I(word) rescue word) : word
      end
      nil
    end

    # The pillar's answer for the info key, or nil.
    def self.pillar_line
      word = pillar_word
      word ? [:vitro_alph_pillar_answer, { :word => word }] : nil
    end
  end
end

PokeAccess::Game.define("vitro") do
  mechanic(:state, 50) do
    auto
    name PokeAccess::VitroAlph::TILES.keys, :vitro_alph_tile_puzzle, :when => lambda { |ev| !PokeAccess::VitroAlph.solved_tile?(ev) }
    hide PokeAccess::VitroAlph::TILES.keys, :when => lambda { |ev| PokeAccess::VitroAlph.solved_tile?(ev) }
    name PokeAccess::VitroAlph::WALLS.keys, :vitro_alph_wall, :numbered => true
    count :vitro_alph_solved, :switches => [72, 73, 74, 75], :announce => false
    PokeAccess::VitroAlph::WALLS.keys.sort.each_with_index do |ev, i|
      watch :switch => PokeAccess::VitroAlph::WALLS[ev], :label => :vitro_alph_wall,
            :say => lambda { PokeAccess::VitroAlph.wall_line(ev, i + 1) }
    end
    hint :vitro_alph_walls_hint
  end

  mechanic(:state, 52) do
    auto
    phase lambda { $game_variables[44] < 3 }, :title => :vitro_alph_door_shut, :quiet => true,
          :hint => lambda { PokeAccess::VitroAlph.door_hint }
  end

  mechanic(:state, 155) do
    auto
    active { PokeAccess::Puzzles.assist? }
    info { PokeAccess::VitroAlph.pillar_line }
  end
end
