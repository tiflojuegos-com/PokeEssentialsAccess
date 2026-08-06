# Music book (the Advanced Items - Field Moves plugin, Window_MusicBook): the instruments and the tunes
# learned for each. It IS a Window_DrawableCommand, so the generic hook fires -- but the entries live in
# @music_book / @filterlist, not in any of the ivars the generic reader knows, so it found no list and the
# window read as nothing at all. The window's own `item` accessor resolves the focused row through the
# filter, which is what makes this a short extractor instead of a reimplementation of its indexing.
#
# The trailing row is the close button and the plugin literally paints CLOSE BAG on it, so it reuses the
# bag key rather than the PC one (which says "close BOX").
module PokeAccess
  module MusicBook
    # The focused tune's name, or the trailing close row.
    def self.text(win, i)
      book = win.instance_variable_get(:@music_book)
      inst = win.instance_variable_get(:@instrument)
      list = (book.instruments[inst] rescue nil)
      filter = win.instance_variable_get(:@filterlist)
      count = (filter && filter[inst]) ? filter[inst].length : (list.is_a?(Array) ? list.length : 0)
      return PokeAccess::I18n.t(:mn_close_bag) if i >= count
      id = (win.item rescue nil)
      return nil if id.nil?
      nm = (PokeAccess::Data.item_name(id) rescue nil)
      return nil if nm.nil? || nm.to_s.empty?
      # The favourite mark. The book keeps its own list and the window paints a star beside a tune that is on
      # it -- the only thing distinguishing two rows that otherwise read identically, and invisible to a
      # reader that says the name alone.
      fav = (book.favorited?(id) rescue false)
      fav ? "#{nm}, #{PokeAccess::I18n.t(:mb_favourite)}" : nm.to_s
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Menus.def_extractor("Window_MusicBook") { |win, i| PokeAccess::MusicBook.text(win, i) }
