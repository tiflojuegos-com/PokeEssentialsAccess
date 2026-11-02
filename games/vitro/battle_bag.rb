# Vitro's battle bag (0245_EliteBattle_NewBattleBag, the Elite Battle System's NewBattleBag in its own variant): four buttons
# with the labels of its PocketText, each listing that kind of item from the whole bag under the name of a bag pocket; the
# last-used item and back; and the use/don't-use confirmation, whose two choices it writes, with the item's description.
module PokeAccess
  module VitroBattleBag
    SLOT = :vitro_bag
    PAGE_SLOT = :vitro_bag_page
    CONFIRM_SLOT = :vitro_bag_confirm
    # Width of one box in the confirmation's selection frame, whose source x starts two boxes in.
    CONFIRM_BOX = 466

    # Forgets what the bag last said, so its opening reads the focused button again.
    def self.opened(bag)
      PokeAccess::Cursor.reset(bag, SLOT)
    end

    # Says the bag's focused entry once per change; silent while a chosen item waits for its confirmation.
    def self.update(bag)
      return if PokeAccess.ivar(bag, :@ret)
      return pocket(bag) unless PokeAccess.ivar(bag, :@selPocket).to_i == 0
      PokeAccess::Cursor.reset(bag, PAGE_SLOT)
      idx = PokeAccess.ivar(bag, :@index)
      PokeAccess::Cursor.announce(bag, SLOT, "m#{idx}") { main_text(bag, idx) }
    end

    # A main-screen button: a label as painted, the last-used item with its name, or back; also the info key's.
    def self.main_text(bag, idx)
      last = PokeAccess.ivar(bag, :@lastUsed)
      return last_text(last) if idx == 4
      text = idx == 5 ? PokeAccess::I18n.t(:bb_back) : (PokeAccess.const_at("NewBattleBag::PocketText") || [])[idx]
      PokeAccess::Info.set_info(:text, text) if text
      text
    end

    # The button of the last-used item; while there is none left, refresh paints its heading alone.
    def self.last_text(item)
      unless item.to_i > 0 && $PokemonBag.pbQuantity(item) > 0
        heading = _INTL("Último objeto usado")
        PokeAccess::Info.set_info(:text, heading)
        return heading
      end
      PokeAccess::Info.set_info(:item, item)
      "#{PokeAccess::I18n.t(:bb_last)}, #{PokeAccess::Data.item_name(item)}"
    end

    # Inside a pocket: the focused item or back, headed by the pocket name and page when the page changes.
    def self.pocket(bag)
      back = PokeAccess.ivar(bag, :@back)
      item = PokeAccess.ivar(bag, :@item).to_i
      key = back ? "back" : "i#{PokeAccess.ivar(bag, :@selPocket)}-#{item}"
      PokeAccess::Cursor.announce(bag, SLOT, key) do
        [header(bag, item), (back ? back_text : entry(bag, item))].compact.join(". ")
      end
    end

    # The pocket's back button; also the info key's.
    def self.back_text
      text = PokeAccess::I18n.t(:bb_back)
      PokeAccess::Info.set_info(:text, text)
      text
    end

    # The pocket name and page the header paints (six items a page), when that page was not the last one said.
    def self.header(bag, item)
      page = item / 6
      return nil unless PokeAccess::Cursor.changed?(bag, PAGE_SLOT, "#{PokeAccess.ivar(bag, :@selPocket)}-#{page}")
      "#{PokeAccess.ivar(bag, :@pname)}, #{page + 1}/#{PokeAccess.ivar(bag, :@pages)}"
    end

    # A pocket slot as its button paints it, the item's name and "x" with the quantity; also the info key's item.
    def self.entry(bag, item)
      row = PokeAccess.ivar(bag, :@pocket)[item]
      PokeAccess::Info.set_info(:item, row[0])
      "#{PokeAccess::Data.item_name(row[0])}, x#{row[1]}"
    end

    # A button that found nothing to list stays on the main screen with only a buzz.
    def self.drew(bag)
      return unless (PokeAccess.ivar(bag, :@pocket) || []).empty?
      PokeAccess.speak(PokeAccess::I18n.t(:vitro_bag_empty), true)
    end

    # The description the confirmation paints, said as it opens.
    def self.description(bag)
      text = PokeAccess::Data.item_description(PokeAccess.ivar(bag, :@ret))
      PokeAccess.speak(PokeAccess.clean(text.to_s), true) unless text.to_s.empty?
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Runs the use/don't-use confirmation: the item's description first, then the box poll finds focused.
    def self.confirm(bag)
      description(bag)
      @confirm = bag
      yield
    ensure
      @confirm = nil
      PokeAccess::Cursor.reset(bag, CONFIRM_SLOT)
      PokeAccess::Cursor.reset(bag, SLOT)
    end

    # Each frame of a confirmation: says the box its selection frame sits on, as the screen writes it, the first queued.
    def self.poll
      bag = @confirm
      return unless bag
      sel = PokeAccess.sprite(bag, "sel")
      idx = sel ? sel.src_rect.x / CONFIRM_BOX - 2 : nil
      return unless idx == 0 || idx == 1
      PokeAccess::Cursor.announce(bag, CONFIRM_SLOT, idx, true, false) { idx == 0 ? _INTL("USAR") : _INTL("NO USAR") }
    end
  end
end

PokeAccess::Game.define("vitro") do
  before("NewBattleBag", :show) { |bag, _a| PokeAccess::VitroBattleBag.opened(bag) }
  after("NewBattleBag", :update, :hook_container => true) { |bag, _r, _a| PokeAccess::VitroBattleBag.update(bag) }
  after("NewBattleBag", :drawPocket) { |bag, _r, _a| PokeAccess::VitroBattleBag.drew(bag) }
  around("NewBattleBag", :useItem?) { |bag, nxt, _a| PokeAccess::VitroBattleBag.confirm(bag) { nxt.call } }
  poll_each_frame { PokeAccess::VitroBattleBag.poll }
end
