# The library gym of Amatista City (map 273): four books, won from the gym's people, go back on the shelves (terrain 37)
# facing up from the tile below; each book's description names the section of the next one. The shelves are four rows,
# 1 at the bottom to 4 at the top, of sections two tiles wide, A to D on the left and E to H on the right. With every book
# in its section (the game's own check) switch 388 opens the way to the leader. Events 2 to 5 are the books on the shelf.
module PokeAccess
  module RealideaLibrary
    MAP = 273
    SHELF = 37
    DONE = 388
    ROWS = { 47 => 1, 42 => 2, 37 => 3, 32 => 4 }
    LETTERS = %w[A B C D E F G H]
    BOOKS = { 2 => :LIBRO1, 3 => :LIBRO2, 4 => :LIBRO3, 5 => :LIBRO4 }
    # The tiles each book is checked on, as [x0, x1, y].
    HOMES = { 2 => [11, 12, 42], 3 => [22, 23, 42], 4 => [13, 14, 32], 5 => [7, 8, 37] }
    STORE_X = 30

    # The section of a shelf tile, as "2C", or nil off the shelves.
    def self.section(x, y)
      row = ROWS[y]
      return nil unless row && PokeAccess::World::Terrain.number(x, y) == SHELF
      col = x >= 20 ? 4 + (x - 20) / 2 : (x - 7) / 2
      col >= 0 && col < LETTERS.length ? "#{row}#{LETTERS[col]}" : nil
    end

    # The line for the shelf section in front of the player, facing up, or nil.
    def self.facing_line
      return nil unless $game_player.direction == 8
      s = section($game_player.x, $game_player.y - 1)
      s ? [:rea_library_section, { :section => s }] : nil
    end

    # The name of a book on the shelf, by its title; nil while it waits off the shelves.
    def self.book(ev)
      return nil if ev.x >= STORE_X
      [:rea_library_book, { :title => PokeAccess::Data.item_name(BOOKS[ev.id]).to_s }]
    end

    # How many books stand in their own section.
    def self.placed
      HOMES.keys.select do |id|
        ev = $game_map.events[id]
        x0, x1, y = HOMES[id]
        ev && ev.y == y && ev.x >= x0 && ev.x <= x1
      end.length
    end
  end
end

PokeAccess::Game.define("realidea") do
  lib = PokeAccess::RealideaLibrary
  camera_tile(:maps => [lib::MAP], :tags => [lib::SHELF]) do |x, y|
    s = lib.section(x, y)
    s ? PokeAccess::I18n.t(:rea_library_section, :section => s) : nil
  end
  mechanic(:state, lib::MAP) do
    auto
    name lib::BOOKS.keys, lambda { |ev| lib.book(ev) }, :when => lambda { |ev| ev.x < lib::STORE_X }
    count :rea_library_placed, :value => lambda { lib.placed }, :of => 4, :assist => true
    info { lib.facing_line }
    arrival_hint :rea_library_rule
    solved { $game_switches[lib::DONE] }
    hint :rea_library_hint
  end
end
