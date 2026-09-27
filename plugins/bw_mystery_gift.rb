module PokeAccess
  # BW Mystery Gift: the menu (PokemonMGift_Scene, sprite buttons over @commands and @index), the downloads (the
  # internet one's carousel of pending gifts, the gift a password matches), the card album (WonderCardAlbumScene, a
  # paged grid) and the card viewer.
  module BWMysteryGift
    # A menu entry's label: a MenuHandlers hash's "name", a pair's second item, or a plain string.
    def self.menu_entry(entry)
      return (entry["name"] || entry[:name]) if entry.is_a?(Hash)
      entry.is_a?(Array) ? entry[1] : entry
    end

    # What a card's icon shows: the Pokemon's species, or the item. A gift of several items keeps no item on its card
    # (the card stores it only for a gift_type of 1), so its icon, and with it the album's "xN", shows nothing.
    def self.contents(card)
      pk = (card.pokemon_data rescue nil)
      return PokeAccess::Data.species_name((pk.species rescue pk)) if (card.gift_type rescue nil) == 0 && pk
      it = (card.item rescue nil)
      return nil if it.nil?
      id = (it.is_a?(Symbol) || it.is_a?(String)) ? it : (it.id rescue it)
      nm = PokeAccess::Data.item_name(id)
      (nm.nil? || nm.to_s.empty?) ? nil : nm.to_s
    rescue StandardError
      nil
    end

    # What a card's icon shows beside its title, left out when the title already names it ("Gold Bottle Cap").
    def self.contents_beside(title, card)
      shown = contents(card)
      return nil if shown.nil? || title.to_s.downcase.include?(shown.to_s.downcase)
      shown
    end

    # Holds a download while it runs: :internet (the carousel) or :password, the gifts it decrypted, the password
    # typed and the name last said.
    def self.download(kind)
      @download = kind ? { :kind => kind, :gifts => [], :password => nil, :said => nil } : nil
    end

    # What a gift is: a Pokemon (type 0) or an item, in words.
    def self.kind(gift)
      PokeAccess::I18n.t(gift[1] == 0 ? :mgift_kind_pokemon : :mgift_kind_item)
    end

    # A carousel paint (its gift's name, alone in a pbDrawTextPositions batch): the name and whether it is a Pokemon
    # or an item, said on a change of gift, the first queued; paints of anything but a pending gift pass.
    def self.painted(rows)
      d = @download
      return if d.nil? || d[:kind] != :internet || !rows.is_a?(Array) || !rows[0].is_a?(Array)
      name = rows[0][0].to_s
      gift = d[:gifts].find { |g| g.is_a?(Array) && g[3].to_s == name }
      return if gift.nil? || d[:said] == name
      first = d[:said].nil?
      d[:said] = name
      PokeAccess.speak(PokeAccess.clean("#{name}, #{kind(gift)}"), !first)
    rescue StandardError
      nil
    end

    # Keeps the password typed for the password download, which decrypts the gifts only afterwards.
    def self.note_password(pw)
      @download[:password] = pw.to_s if @download && @download[:kind] == :password
    end

    # Keeps the gift list a download decrypts, to tell a Pokemon from an item by the name the carousel paints; the
    # password download then says the gift the password matches, as its sprite drops in.
    def self.note_gifts(list)
      return unless @download && list.is_a?(Array)
      @download[:gifts] = list
      password_gift(list) if @download[:kind] == :password
    rescue StandardError
      nil
    end

    # The gift the typed password matches, said as its falling sprite shows it (the species or the item) with what
    # it is, queued; nothing when none matches or the player already has it, which the game then says.
    def self.password_gift(list)
      pw = @download[:password]
      return if pw.nil? || pw.empty?
      gift = list.find { |g| g.is_a?(Array) && g.length > 6 && g[6] == pw }
      return if gift.nil? || (($player.mystery_gifts.any? { |g| g[0] == gift[0] }) rescue false)
      data = gift[2]
      shown = if gift[1] == 0
                PokeAccess::Data.species_name((data.species rescue data))
              else
                PokeAccess::Data.item_name(data.is_a?(String) ? data.split(" x")[0].to_sym : data)
              end
      shown = gift[3] if shown.nil? || shown.to_s.empty?
      PokeAccess.speak(PokeAccess.clean("#{shown}, #{kind(gift)}"), false)
    end

    # The opened card: title, what its sprite shows, claimed state (shown only by the background), arrival date and
    # description.
    def self.viewer(scene)
      cards = PokeAccess.ivar(scene, :@cards)
      idx = PokeAccess.ivar(scene, :@index)
      c = (cards.is_a?(Array) && idx.is_a?(Integer)) ? cards[idx] : nil
      return unless c
      title = PokeAccess.clean((c.title rescue "").to_s)
      desc = PokeAccess.clean((c.description rescue "").to_s)
      parts = [title, contents_beside(title, c)]
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

    # The focused card: title, what its icon shows, place, claimed state, date and, from medium, its page of several;
    # keyed on the title too, as a deletion shifts the next card in. No return inside the block: the key is already
    # marked.
    def self.card(scene)
      cards = PokeAccess.ivar(scene, :@cards)
      idx = PokeAccess.ivar(scene, :@selected_card)
      return unless cards.is_a?(Array) && idx.is_a?(Integer) && !cards.empty?
      idx = cards.length - 1 if idx >= cards.length
      return unless idx >= 0 && cards[idx]
      title = PokeAccess.clean((cards[idx].title rescue "").to_s)
      return if title.empty?
      claimed = (cards[idx].claimed? rescue nil)
      PokeAccess::Cursor.announce(scene, :mgift_card, [idx, title, claimed], true) do
        shown = contents_beside(title, cards[idx])
        head = (shown.nil? || shown.to_s.empty?) ? title : "#{title}, #{shown}"
        line = PokeAccess::Verbosity.list_entry(head, idx + 1, cards.length)
        unless claimed.nil?
          line += ", " + PokeAccess::I18n.t(claimed ? :mgift_claimed : :mgift_unclaimed)
        end
        rd = (cards[idx].date_received rescue nil)
        rt = (rd.strftime("%d %b %Y") rescue nil) if rd
        line += ", #{rt}" if rt
        per = (WonderCardAlbumScene::CARDS_PER_PAGE rescue nil)
        pages = (per.is_a?(Integer) && per > 0) ? (cards.length.to_f / per).ceil : nil
        if pages && pages > 1 && PokeAccess::Verbosity.keep?(:positions, :medium)
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

# The card viewer paints once in pbStartScene, then waits for Back: that call is the whole read.
PokeAccess::Hooks.after_hook("WonderCardScene", :pbStartScene, :optional => true) do |scene, _r, _a|
  PokeAccess::BWMysteryGift.viewer(scene)
end

# The two downloads, MysteryGiftCustom module functions: the internet one runs the carousel in its own loop and
# repaints the focused gift's name every frame, its gift list from the decrypt it calls first; the password one
# decrypts the gifts once the password is typed, then drops the matching gift's sprite in.
if PokeAccess.const_at("MysteryGiftCustom")
  [[:pbDownloadMysteryGift_Internet, :internet], [:pbDownloadMysteryGift_Password, :password]].each do |meth, kind|
    PokeAccess::Hooks.wrap_singleton("MysteryGiftCustom", meth, "bw_mgift_download", :around) do |_a, call_next|
      PokeAccess::BWMysteryGift.download(kind)
      begin
        call_next.call
      ensure
        PokeAccess::BWMysteryGift.download(nil)
      end
    end
  end
  PokeAccess::Hooks.wrap_kernel("pbEnterPasswordFreeText", "bw_mgift_password", :after) do |_args, result|
    PokeAccess::BWMysteryGift.note_password(result)
  end
  PokeAccess::Hooks.wrap_kernel("pbMysteryGiftDecrypt", "bw_mgift_gifts", :after) do |_args, result|
    PokeAccess::BWMysteryGift.note_gifts(result)
  end
  PokeAccess::Hooks.wrap_kernel("pbDrawTextPositions", "bw_mgift_carousel_name", :before) do |args, _r|
    PokeAccess::BWMysteryGift.painted(args[1])
  end
end
