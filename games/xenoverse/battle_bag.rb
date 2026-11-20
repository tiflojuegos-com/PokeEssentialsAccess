module PokeAccess
  # The battle bag (0177_EliteBattle_UI, NewBattleBag): four category buttons, the last item used and Back, then a paged
  # grid of a pocket's items, then a USE / DON'T USE confirmation whose cursor is the "sel" sprite's frame.
  module XenoverseBattleBag
    SLOT = :xenoverse_battle_bag
    PAGE_SLOT = :xenoverse_battle_bag_page
    CONFIRM_SLOT = :xenoverse_battle_bag_confirm
    # The "sel" sprite's source x over USE, and the step to DON'T USE.
    CONFIRM_FIRST = 931
    CONFIRM_STEP = 465

    # Starts reading a bag that shows.
    def self.opened(bag)
      @active = bag
      PokeAccess::Cursor.reset(bag, SLOT)
      PokeAccess::Cursor.reset(bag, PAGE_SLOT)
    end

    # Forgets the bag as it hides.
    def self.closed(bag)
      @active = nil if @active.equal?(bag)
      PokeAccess::Cursor.reset(bag, SLOT)
      PokeAccess::Cursor.reset(bag, PAGE_SLOT)
      PokeAccess::Info.set_info(:battle_foe, nil)
    end

    # Says the main button or the pocket row under the cursor.
    def self.update(bag)
      return unless @active.equal?(bag)
      return if PokeAccess.ivar(bag, :@ret)
      return pocket(bag) unless PokeAccess.ivar(bag, :@selPocket).to_i == 0
      PokeAccess::Cursor.reset(bag, PAGE_SLOT)
      index = PokeAccess.ivar(bag, :@index)
      return unless index.is_a?(Integer) && index >= 0 && index <= 5
      PokeAccess::Cursor.announce(bag, SLOT, [:main, index, PokeAccess.ivar(bag, :@lastUsed)], true, false) do
        main_text(bag, index)
      end
    end

    # A main button's text: the category getItemText paints, the last item used (the game's own label with none), Back.
    def self.main_text(bag, index)
      if index == 4
        item = PokeAccess.ivar(bag, :@lastUsed).to_i
        if item > 0
          PokeAccess::Info.set_info(:item, item)
          return PokeAccess::I18n.t(:xenoverse_last_item, :name => PokeAccess::Data.item_name(item))
        end
        text = _INTL("ULTIMO STRUMENTO USATO")
      else
        text = index == 5 ? PokeAccess::I18n.t(:bb_back) : bag.getItemText(index)
      end
      PokeAccess::Info.set_info(:text, text, text)
      text
    end

    # The pocket's row under the cursor: its item and quantity, or Back; its name and page when they change.
    def self.pocket(bag)
      index = PokeAccess.ivar(bag, :@item)
      return unless index.is_a?(Integer) && index >= 0
      back = PokeAccess.ivar(bag, :@back)
      selected = PokeAccess.ivar(bag, :@selPocket)
      entries = PokeAccess.ivar(bag, :@pocket)
      entry = entries.is_a?(Array) ? entries[index] : nil
      return unless back || (entry.is_a?(Array) && entry.length >= 2)
      page = PokeAccess.ivar(bag, :@page)
      pages = PokeAccess.ivar(bag, :@pages)
      key = [selected, index, back ? true : false, entry && entry[0], entry && entry[1], page, pages]
      PokeAccess::Cursor.announce(bag, SLOT, key, true, false) do
        name = PokeAccess.ivar(bag, :@pname)
        header = nil
        if PokeAccess::Cursor.changed?(bag, PAGE_SLOT, [selected, page, pages, name])
          header = PokeAccess::I18n.t(:xenoverse_bag_page, :name => name, :n => page.to_i + 1, :tot => pages)
        end
        if back
          text = PokeAccess::I18n.t(:bb_back)
          PokeAccess::Info.set_info(:text, text, text)
        else
          PokeAccess::Info.set_info(:item, entry[0])
          text = PokeAccess::I18n.t(:bag_item, :name => PokeAccess::Data.item_name(entry[0]), :qty => entry[1])
        end
        PokeAccess.sentences([header, text].compact)
      end
    end

    # Runs the confirmation for the chosen item, saying its description first.
    def self.confirm(bag)
      previous = @confirm
      @confirm = bag
      item = PokeAccess.ivar(bag, :@ret)
      PokeAccess::Info.set_info(:item, item)
      description = PokeAccess::Data.item_description(item)
      PokeAccess.speak(PokeAccess.clean(description.to_s), true) unless description.to_s.empty?
      yield
    ensure
      @confirm = previous
      PokeAccess::Cursor.reset(bag, CONFIRM_SLOT)
      PokeAccess::Cursor.reset(bag, SLOT)
    end

    # Says USE or DON'T USE as the game paints them, by the "sel" sprite's frame over the panel.
    def self.poll
      bag = @confirm
      return unless bag && @active.equal?(bag)
      selection = PokeAccess.sprite(bag, "sel")
      return unless selection && !(selection.disposed? rescue false)
      panel = PokeAccess.sprite(bag, "confirm")
      return unless panel && panel.x >= 0 && selection.x == panel.x
      offset = selection.src_rect.x - CONFIRM_FIRST
      return unless offset == 0 || offset == CONFIRM_STEP
      index = offset / CONFIRM_STEP
      PokeAccess::Cursor.announce(bag, CONFIRM_SLOT, index, true, false) do
        text = index == 0 ? _INTL("USE") : _INTL("DON'T USE")
        PokeAccess::Info.set_info(:item, PokeAccess.ivar(bag, :@ret), text)
        text
      end
    end
  end
end

PokeAccess::Game.define("xenoverse") do
  before("NewBattleBag", :show) { |bag, _args| PokeAccess::XenoverseBattleBag.opened(bag) }
  before("NewBattleBag", :hide) { |bag, _args| PokeAccess::XenoverseBattleBag.closed(bag) }
  after("NewBattleBag", :update, :hook_container => true) do |bag, _result, _args|
    PokeAccess::XenoverseBattleBag.update(bag)
  end
  around("NewBattleBag", :useItem?) do |bag, original, _args|
    PokeAccess::XenoverseBattleBag.confirm(bag) { original.call }
  end
  poll_each_frame { PokeAccess::XenoverseBattleBag.poll }
  clear_info_on("NewBattleBag", :hide)
end
