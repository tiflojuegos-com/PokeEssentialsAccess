# Clara's Alternative Mystery Gifts (BES v16, kleinstudio's BW screens): the menu and the card album by their cursor, the
# gift list by a mirror of its arrows (its cursor is a local of the method), and the card screens as they paint.
module PokeAccess
  module AltMysteryGift
    @gifts = nil

    # The scene watchers of the menu and of the album, kept for the returns that make them say their focus again.
    class << self
      attr_accessor :menu_reader, :album_reader
    end

    # Back from a download or a submenu: the menu says its focused entry again.
    def self.menu_returned
      PokeAccess::Cursor.reset(menu_reader, :amg_menu)
    end

    # Back from the card command, whether it showed a card or deleted one: the album says its focused slot again.
    def self.album_returned
      PokeAccess::Cursor.reset(album_reader, :amg_album)
    end

    # The menu's focused entry: its position is the key, its text one of the four the screen paints.
    def self.menu_focus(scene)
      labels = PokeAccess.ivar(scene, :@text)
      sel = PokeAccess.ivar(scene, :@sel)
      return unless labels.is_a?(Array) && sel.is_a?(Integer) && labels[sel]
      [sel, labels[sel]]
    end

    # Cards a page of the album holds, 4 in the script; the cursor one past them is the exit button.
    def self.per_page
      n = PokeAccess.const_at("CardAlbumScene::CARDS_PER_PAGE")
      n.is_a?(Integer) && n > 0 ? n : 4
    end

    # A date as the album paints it: day, month and year unpadded, or the value's own text.
    def self.card_date(time)
      return "#{time.day}/#{time.month}/#{time.year}" if time.respond_to?(:strftime)
      time.to_s
    end

    # A card's line: its title with its place among the cards, its date, and the page note when it has one.
    def self.card_line(data, idx, total, note)
      title = PokeAccess.clean(data[:title].to_s)
      parts = [PokeAccess::Verbosity.list_entry(title, idx + 1, total), card_date(data[:date]), note]
      parts.reject { |p| p.nil? || p.to_s.empty? }.join(", ")
    end

    # The album's page as a note to a card's line, said once for each page it lands on, while positions are said and
    # the album has several; the page said is kept on the scene.
    def self.page_note(scene, page, pages)
      return if pages <= 1 || PokeAccess.ivar(scene, :@access_amg_page) == page
      scene.instance_variable_set(:@access_amg_page, page)
      return unless PokeAccess::Verbosity.keep?(:positions, :medium)
      PokeAccess::I18n.t(:amg_page, :n => page + 1, :tot => pages)
    end

    # The exit button's word as the album painted it, or the mod's own where the paint was not seen.
    def self.exit_label(scene)
      labels = PokeAccess.ivar(scene, :@access_amg_labels)
      (labels.is_a?(Array) && labels[1]) || PokeAccess::I18n.t(:pc_cancel)
    end

    # The album's focused slot: [page, slot, card id] as the key, since a deletion slides the next card under the same
    # slot, and the card's line (made when it is said, as it notes the page), the empty slot's word or the exit button's.
    def self.album_focus(scene)
      cards = PokeAccess.ivar(scene, :@cards)
      sel = PokeAccess.ivar(scene, :@sel)
      page = PokeAccess.ivar(scene, :@page)
      return unless cards.is_a?(Array) && sel.is_a?(Integer) && page.is_a?(Integer)
      per = per_page
      return [[page, sel, nil], exit_label(scene)] if sel == per
      idx = page * per + sel
      entry = cards[idx]
      return [[page, sel, nil], PokeAccess::I18n.t(:row_empty)] unless entry.is_a?(Array) && entry[1].is_a?(Hash)
      pages = PokeAccess.ivar_i(scene, :@maxPages)
      [[page, sel, entry[0]], lambda { card_line(entry[1], idx, cards.length, page_note(scene, page, pages)) }]
    end

    # The overlay the album paints on every refresh, its title above and its exit button below: the title is said as
    # the album opens and the exit button's word kept on the scene for the cursor that reaches it.
    def self.overlay(scene, pairs)
      rows = PokeAccess::PaintCapture.lines(pairs)
      opened = PokeAccess.ivar(scene, :@access_amg_labels).nil?
      scene.instance_variable_set(:@access_amg_labels, [rows.first, rows.length > 1 ? rows.last : nil])
      PokeAccess.speak_clean(rows.first, false) if opened
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The question the album's own command list is asked under, said as the list opens: the list shows it in a help
    # window, which no reader looks at.
    def self.prompt(text)
      PokeAccess.speak_clean(text, false)
    end

    # Runs the gift list with its gifts held, for the poll that mirrors its arrows; the cursor starts on the first.
    def self.choosing(gifts)
      @gifts = gifts.is_a?(Array) ? gifts : nil
      @pick = 0
      PokeAccess::Cursor.reset(nil, :amg_pick)
      yield
    ensure
      @gifts = nil
      PokeAccess::Cursor.reset(nil, :amg_pick)
    end

    # One step of the list's arrows as its loop takes it: B and C end the loop first, UP and DOWN stop at the ends and
    # only one of them counts in a frame.
    def self.step_pick(count)
      return if Input.trigger?(Input::B) || Input.trigger?(Input::C)
      if Input.trigger?(Input::UP)
        @pick -= 1 if @pick > 0
      elsif Input.trigger?(Input::DOWN)
        @pick += 1 if @pick < count - 1
      end
    end

    # A gift's row: the title the list paints for it, with its place among the gifts.
    def self.gift_row(gifts, i)
      title = (gifts[i].title rescue nil)
      return if title.nil? || title.to_s.strip.empty?
      PokeAccess::Verbosity.list_entry(PokeAccess.clean(title.to_s), i + 1, gifts.length)
    end

    # Each frame of the gift list: moves the mirrored cursor and says the gift it rests on, the first one queued.
    def self.poll_list
      gifts = @gifts
      return if gifts.nil?
      step_pick(gifts.length)
      PokeAccess::Cursor.announce(nil, :amg_pick, @pick, true, false) { gift_row(gifts, @pick) }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Runs a card screen's paint and says what it painted: the title, the description and, on the album's card, the
    # header and the date. interrupt is false for the card shown on receiving a gift, which follows the game's messages.
    def self.reading_card(interrupt)
      ret = nil
      pairs = PokeAccess::PaintCapture.sample { ret = yield }
      say_card(pairs, interrupt)
      ret
    end

    # The lines a card painted, top to bottom, as sentences.
    def self.say_card(pairs, interrupt)
      PokeAccess.speak(PokeAccess.sentences(PokeAccess::PaintCapture.lines(pairs)), interrupt)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::AltMysteryGift.menu_reader = PokeAccess::SceneWatcher.reader("MysteryGiftScene", :pbMGCommands, :amg_menu, :optional => true) do |scene|
  PokeAccess::AltMysteryGift.menu_focus(scene)
end
PokeAccess::AltMysteryGift.album_reader = PokeAccess::SceneWatcher.reader("CardAlbumScene", :pbMainLoop, :amg_album, :optional => true) do |scene|
  PokeAccess::AltMysteryGift.album_focus(scene)
end

# The whole mystery gift screen runs inside a fade, so the menu's own submenus count from its loop; the download is
# one of them, and the album's fade another.
PokeAccess::Hooks.around_hook("MysteryGiftScene", :pbMGCommands, :optional => true) do |_scene, nxt, _a|
  PokeAccess::MenuReturn.reset_nesting
  nxt.call
end
PokeAccess::MenuReturn.bare("MysteryGiftScene", :pbReceiveGift, :optional => true)
PokeAccess::MenuReturn.on_return { PokeAccess::AltMysteryGift.menu_returned }

PokeAccess::Hooks.around_hook("MysteryGiftScene", :pbChooseGiftFromList, :optional => true) do |_scene, nxt, args|
  PokeAccess::AltMysteryGift.choosing(args[0]) { nxt.call }
end
PokeAccess::Frame.each_pulse { PokeAccess::AltMysteryGift.poll_list }

PokeAccess::Hooks.around_hook("CardAlbumScene", :writeOverlayInfo, :optional => true) do |scene, nxt, _a|
  ret = nil
  pairs = PokeAccess::PaintCapture.sample { ret = nxt.call }
  PokeAccess::AltMysteryGift.overlay(scene, pairs)
  ret
end
PokeAccess::Hooks.before_hook("CardAlbumScene", :pbShowCommandsAlbum, :optional => true) do |_scene, args|
  PokeAccess::AltMysteryGift.prompt(args[0])
end
PokeAccess::Hooks.around_hook("CardAlbumScene", :pbCardCommand, :optional => true) do |_scene, nxt, _a|
  begin
    nxt.call
  ensure
    PokeAccess::AltMysteryGift.album_returned
  end
end
# The album's deletion asks through the BW system message, which no core reader hooks.
PokeAccess::Hooks.wrap_kernel("pbConfirmMessageSystem", "plugin_alt_mystery_gift_confirm", :before) do |args, _r|
  PokeAccess.say_dialogue(args[2])
end

PokeAccess::Hooks.around_hook("WonderCardDetailScene", :pbSetWonderCardText, :optional => true) do |_scene, nxt, _a|
  PokeAccess::AltMysteryGift.reading_card(true) { nxt.call }
end
PokeAccess::Hooks.around_hook("WonderCardReceivedDetails", :pbSetWonderCardText, :optional => true) do |_scene, nxt, _a|
  PokeAccess::AltMysteryGift.reading_card(false) { nxt.call }
end
