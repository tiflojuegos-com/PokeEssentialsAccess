module PokeAccess
  # BW Mystery Gift and Card Album, two screens of one plugin.
  #
  # The menu (PokemonMGift_Scene) uses sprite buttons instead of a command window, but keeps the options in
  # @commands and the cursor in @index and pumps pbUpdate, which is what the sprite-menu primitive needs.
  #
  # The album (WonderCardAlbumScene) is a paged grid; its updateCursorPosition recomputes the page from
  # @selected_card on every move. USE opens a card and offers to DELETE it, so this grid guards a
  # destructive action.
  module BWMysteryGift
    # A menu entry's label. Rows built from MenuHandlers ARE the handler hash, which is why the screen reads
    # cmd["name"]; the pair and plain-string shapes are accepted for a copy built without MenuHandlers.
    def self.menu_entry(entry)
      return (entry["name"] || entry[:name]) if entry.is_a?(Hash)
      entry.is_a?(Array) ? entry[1] : entry
    end

    # The opened card as the viewer prints it: title, claimed state, arrival date and description. The
    # claimed state is not written in words on screen -- the viewer swaps the background for a "seen" one.
    def self.viewer(scene)
      cards = PokeAccess.ivar(scene, :@cards)
      idx = PokeAccess.ivar(scene, :@index)
      c = (cards.is_a?(Array) && idx.is_a?(Integer)) ? cards[idx] : nil
      return unless c
      title = PokeAccess.clean((c.title rescue "").to_s).to_s.strip
      desc = PokeAccess.clean((c.description rescue "").to_s).to_s.strip
      parts = [title]
      parts.push(PokeAccess::I18n.t((c.claimed? rescue false) ? :mgift_claimed : :mgift_unclaimed))
      d = (c.date_received.strftime("%d %b %Y") rescue nil)
      parts.push(PokeAccess::I18n.t(:mgift_date, :d => d)) if d && !d.to_s.empty?
      parts.push(desc)
      parts = parts.reject { |p| p.nil? || p.to_s.empty? }
      return if parts.empty?
      PokeAccess.speak(parts.join(". "), true)
    rescue StandardError
      nil
    end

    # The focused card: title, place in the album and which page of the grid that is.
    #
    # The title joins the index in the dedup key, because deleting a card shifts the rest up and leaves the
    # cursor where it was, so the same index then holds a different card.
    #
    # Never `return` from inside the announce block: on_change has already recorded the key by the time it
    # yields, so a return leaves the slot marked as spoken with nothing said.
    def self.card(scene)
      cards = PokeAccess.ivar(scene, :@cards)
      idx = PokeAccess.ivar(scene, :@selected_card)
      return unless cards.is_a?(Array) && idx.is_a?(Integer) && cards[idx]
      title = PokeAccess.clean((cards[idx].title rescue "").to_s).to_s.strip
      return if title.empty?
      PokeAccess::Cursor.announce(scene, :mgift_card, [idx, title], true) do
        line = PokeAccess::I18n.t(:list_entry, :name => title, :n => idx + 1, :tot => cards.length)
        per = (WonderCardAlbumScene::CARDS_PER_PAGE rescue nil)
        pages = (per.is_a?(Integer) && per > 0) ? (cards.length.to_f / per).ceil : nil
        if pages && pages > 1
          "#{line}. #{PokeAccess::I18n.t(:mgift_page, :n => (idx / per) + 1, :tot => pages)}"
        else
          line
        end
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

# The viewer is a scene of its own: it paints title and description once in pbStartScene and then waits for
# BACK, so that one call is the whole read.
PokeAccess::Hooks.after_hook("WonderCardScene", :pbStartScene, :optional => true) do |scene, _r, _a|
  PokeAccess::BWMysteryGift.viewer(scene)
end
