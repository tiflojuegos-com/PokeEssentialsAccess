# Vieja Biblioteca (map 39): three books stick out of the shelves, drawn only through the Lens of Truth (events 54, 41
# and 53), and the action events under them (55, 56 and 57) push each with a yes, setting 101, 102 and 103 and adding to
# var 74; with all three, the autorun of event 58 sets 104 and the door in the north wall of the central room (event 39)
# leads on to map 40, whose scene raises var 75. A book is named and listed while the lens shows it, or with the assist;
# the info key and the hint, with the assist alone.
PokeAccess::Game.define("pokemon_z") do
  books = { 55 => [54, 101, :z_library_book_west, :z_library_at_west],
            56 => [41, 102, :z_library_book_centre, :z_library_at_centre],
            57 => [53, 103, :z_library_book_ne, :z_library_at_ne] }
  past_door = at(64, 77, 26, 30)
  seen = lambda do |ev|
    book = books[ev.id]
    book && (PokeAccess::Puzzles.assist? || PokeAccess::World::Lens.reaches?($game_map.events[book[0]])) ? book[2] : nil
  end
  mechanic(:state, 39) do
    books.keys.sort.each do |id|
      watch :switch => books[id][1], :label => books[id][2], :on => :z_arma_book_pushed, :off => :z_arma_book_still
    end
    controls
    name books.keys.sort, seen
    active do
      PokeAccess::Puzzles.assist? &&
        (!$game_switches[104] || ($game_variables[75].to_i == 0 && !past_door.call))
    end
    hint(lambda do
      if $game_switches[104]
        :z_library_door
      else
        left = books.keys.sort.reject { |id| $game_switches[books[id][1]] }
        [:z_library_books_hint, { :n => left.length,
                                  :books => left.map { |id| PokeAccess::I18n.t(books[id][3]) }.join("; ") }]
      end
    end)
  end
end
