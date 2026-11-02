# Perseida's books (Textbook_Scene in 0223_Libros Mejorados; its BookScene is only a pbBook that calls textbook): @bookarray
# holds a title and a text for each page, two entries a page, and the page is painted as it opens and on each turn. Some
# pages add a picture with no text of its own.
module PokeAccess
  module PerseidaBooks
    # A page as painted: its title with its place among the pages, then its text; the first page says how to turn them.
    def self.page_line(scene, page)
      rows = PokeAccess.ivar(scene, :@bookarray)
      return nil unless rows.is_a?(Array) && rows[page]
      head = PokeAccess::Verbosity.list_entry(PokeAccess.clean(rows[page].to_s), page / 2 + 1, (rows.length + 1) / 2)
      line = PokeAccess.sentences([head, PokeAccess.clean(rows[page + 1].to_s)])
      PokeAccess::Info.set_info(:text, line)
      page == 0 ? PokeAccess::Verbosity.with_hint(line, PokeAccess::I18n.t(:perseida_book_hint), " ") : line
    end
  end
end

PokeAccess::Game.define("perseida") do
  after("Textbook_Scene", :drawTextbookPage, :optional => true) do |scene, _r, args|
    PokeAccess::Cursor.announce(scene, :perseida_book, args[0], true, false) do
      PokeAccess::PerseidaBooks.page_line(scene, args[0])
    end
  end
  after("Textbook_Scene", :pbEndScene, :optional => true, :hook_container => true) do |_scene, _r, _a|
    PokeAccess::Info.clear_text
  end
end
