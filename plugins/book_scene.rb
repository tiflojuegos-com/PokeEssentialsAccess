module PokeAccess
  # Readable in-game books (a fangame addon's BookScene): a page is read when it changes.

  # The tags the page's drawFormattedTextEx takes as formatting; other words in angle brackets it paints as they are.
  BOOK_FORMAT_TAG = /\A<\/?(?:c|c2|c3|o|fn|br|fs|i|b|r|pg|pog|u|s|icon|img|ac|ar|al|outln|outln2)(?:\s*=[^>]*)?>\z/i

  # The cleaned text of a book page, or nil when empty/out of range. Words the page paints in angle brackets, as a
  # book's quotes, stay.
  def self.book_text(libro, page)
    return nil unless libro && page
    t = (libro[page] rescue nil)
    return nil if t.nil? || t.to_s.empty?
    clean(t.to_s.gsub(/<[^<>]*>/) { |tag| tag =~ BOOK_FORMAT_TAG ? tag : tag[1...-1] })
  end
end

# Reads a book page when it changes, deduped on the page index (texto redraws every frame).
PokeAccess::Hooks.after_hook("BookScene", :texto, :optional => true) do |scene, _r, _a|
  page = scene.instance_variable_get(:@page)
  PokeAccess::Cursor.announce(scene, :book_page, page, true) do
    PokeAccess.book_text(scene.instance_variable_get(:@libro), page)
  end
end
