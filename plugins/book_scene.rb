module PokeAccess
  # Readable in-game books (a fangame addon's BookScene): a page is read when it changes.

  # The cleaned text of a book page, or nil when empty/out of range.
  def self.book_text(libro, page)
    return nil unless libro && page
    t = (libro[page] rescue nil)
    (t.nil? || t.to_s.empty?) ? nil : clean(t)
  end
end

# Reads a book page when it changes, deduped on the page index (texto redraws every frame).
PokeAccess::Hooks.after_hook("BookScene", :texto, :optional => true) do |scene, _r, _a|
  page = scene.instance_variable_get(:@page)
  PokeAccess::Cursor.announce(scene, :book_page, page, true) do
    PokeAccess.book_text(scene.instance_variable_get(:@libro), page)
  end
end
