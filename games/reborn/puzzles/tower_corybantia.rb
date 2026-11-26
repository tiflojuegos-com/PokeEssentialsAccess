# Tower Corybantia (map 699): four floors, each with a book drawn on the map (events 1 to 4 at (6,8), (6,30), (6,51),
# (6,73)); the first read adds one to variable 381 (self switch A), and faced from below it reads the next line of the
# verse. At 7 any stairs (events 5 to 20) set it to 8 and a path (events 21, 24) opens to the exit (event 22).
module PokeAccess
  module RebornCorybantia
    BOOKS = [1, 2, 3, 4]

    def self.read?(id)
      $game_self_switches[[699, id, "A"]] ? true : false
    end

    def self.left
      BOOKS.reject { |id| read?(id) }.length
    end

    def self.path?
      $game_variables[381].to_i >= 8
    end

    def self.hint
      return [:rbb_cory_hint_books, { :n => left }] if left > 0
      path? ? :rbb_cory_hint_exit : :rbb_cory_hint_stairs
    end
  end
end

PokeAccess::Game.define("reborn") do
  cory = PokeAccess::RebornCorybantia
  mechanic(:state, 699, :part => :books) do
    auto
    name cory::BOOKS, lambda { |ev| cory.read?(ev.id) ? :rbb_cory_book_read : :rbb_cory_book }
    name [21, 24], :rbb_cory_path, :grouped => true
    count :rbb_cory_books, :selfs => [cory::BOOKS, "A"], :assist => true, :announce => false
    phase lambda { cory.path? && $game_player.y >= 65 }, :title => :rbb_cory_path_seen, :hint => :rbb_cory_hint_exit
    phase lambda { true }, :quiet => true, :hint => lambda { cory.hint }
  end
end
