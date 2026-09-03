module PokeAccess
  # Readable in-game books (a fangame addon's BookScene): the page text is drawn to a
  # bitmap by `texto` every frame, so the page is read when it changes (deduped on the page index).

  # The cleaned text of a book page, or nil when empty/out of range.
  def self.book_text(libro, page)
    return nil unless libro && page
    t = (libro[page] rescue nil)
    (t.nil? || t.to_s.empty?) ? nil : clean(t)
  end
end

# Read a book page when it changes (texto redraws every frame, so the page index is the dedup key; the
# scene dies with the book, so the slot needs no reset).
PokeAccess::Hooks.after_hook("BookScene", :texto, :optional => true) do |scene, _r, _a|
  page = scene.instance_variable_get(:@page)
  PokeAccess::Cursor.announce(scene, :book_page, page, true) do
    PokeAccess.book_text(scene.instance_variable_get(:@libro), page)
  end
end
