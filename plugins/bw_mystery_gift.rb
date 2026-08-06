module PokeAccess
  # BW Mystery Gift and Card Album. Two screens from the same plugin, both silent for opposite reasons.
  #
  # The MENU (PokemonMGift_Scene) replaces the engine's command window with sprite buttons, so the generic
  # command reader never sees it -- but it still keeps the option list in @commands and the cursor in @index,
  # and its loop calls pbUpdate every frame, which is all the sprite-menu primitive needs.
  #
  # The ALBUM (WonderCardAlbumScene) is a paged grid of received cards. Its own updateCursorPosition runs on
  # every move -- it recomputes the page from @selected_card -- so that is where the focus is read. It matters
  # more than most read-only screens: USE opens a card and offers to DELETE it, and the grid gave no spoken
  # feedback at all, so a blind player was navigating a destructive action blind.
  module BWMysteryGift
    # A menu entry. The rows are neither strings nor pairs: the menu is built from MenuHandlers and each row
    # IS the handler hash, which is why the screen itself reads the label as cmd["name"]. Speaking the row
    # spelled the whole hash out loud. The pair and plain-string shapes are still accepted, because that is
    # what a copy built without MenuHandlers would hold.
    def self.menu_entry(entry)
      return (entry["name"] || entry[:name]) if entry.is_a?(Hash)
      entry.is_a?(Array) ? entry[1] : entry
    end

    # The focused card: its title, and where it sits in the album.
    def self.card(scene)
      cards = PokeAccess.ivar(scene, :@cards)
      idx = PokeAccess.ivar(scene, :@selected_card)
      return unless cards.is_a?(Array) && idx.is_a?(Integer) && cards[idx]
      title = PokeAccess.clean((cards[idx].title rescue "").to_s).to_s.strip
      return if title.empty?
      # The title is part of the key, not just the index: deleting a card shifts the rest up and leaves the
      # cursor where it was, so the slot now holds a DIFFERENT card at the same index -- the one moment on
      # this screen where staying quiet is worst, since the player just destroyed something.
      PokeAccess::Cursor.announce(scene, :mgift_card, [idx, title], true) do
        PokeAccess::I18n.t(:list_entry, :name => title, :n => idx + 1, :tot => cards.length)
      end
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("PokemonMGift_Scene", :pbUpdate, :optional => true) do |scene, _r, _a|
  PokeAccess::Menus.poll_sprite_menu(scene, :@commands, :mgift_menu) do |entry|
    PokeAccess::BWMysteryGift.menu_entry(entry)
  end
end

PokeAccess::Hooks.after_hook("WonderCardAlbumScene", :updateCursorPosition, :optional => true) do |scene, _r, _a|
  PokeAccess::BWMysteryGift.card(scene)
end
