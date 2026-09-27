module PokeAccess
  # The Elite Battle System's battle bag (NewBattleBag): the four pocket buttons, the last-used item and back, a
  # pocket's item grid under its name and page, and the use/don't-use confirmation with the item's description.
  module UraniumBattleBag
    # The bag pockets the four buttons open, in button order (NewBattleBag#updateMain).
    POCKETS = [2, 3, 5, 7]

    # Width of one box in the confirmation's selection frame, whose source x starts two boxes in.
    CONFIRM_BOX = 466

    # The bag whose use/don't-use confirmation is open, or nil.
    def self.confirming; @confirm; end

    # Forgets what the bag last said, so its opening reads the focused button again.
    def self.opened(bag)
      PokeAccess::Cursor.reset(bag, :ura_bag)
      PokeAccess::Cursor.reset(bag, :ura_bag_page)
    end

    # Says the bag's focused entry once per change; silent while a chosen item waits for its confirmation.
    def self.update(bag)
      return if PokeAccess.ivar(bag, :@ret)
      if PokeAccess.ivar(bag, :@selPocket).to_i == 0
        PokeAccess::Cursor.reset(bag, :ura_bag_page)
        idx = PokeAccess.ivar(bag, :@index)
        PokeAccess::Cursor.announce(bag, :ura_bag, "m#{idx}") { main_text(bag, idx) }
      else
        pocket(bag)
      end
    end

    # A main-screen button: a pocket by the name its header paints, the last-used item with its name, or back.
    def self.main_text(bag, idx)
      case idx
      when 0, 1, 2, 3 then (pbPocketNames[POCKETS[idx]] rescue nil)
      when 4 then "#{PokeAccess::I18n.t(:bb_last)}, #{PBItems.getName(PokeAccess.ivar(bag, :@lastUsed))}"
      when 5 then PokeAccess::I18n.t(:bb_back)
      end
    end

    # Inside a pocket: the focused item or back, headed by the pocket name and page when the page changes.
    def self.pocket(bag)
      back = PokeAccess.ivar(bag, :@back)
      item = PokeAccess.ivar(bag, :@item).to_i
      key = back ? "back" : "i#{PokeAccess.ivar(bag, :@selPocket)}-#{item}"
      PokeAccess::Cursor.announce(bag, :ura_bag, key) do
        [header(bag, item), (back ? PokeAccess::I18n.t(:bb_back) : entry(bag, item))].compact.join(". ")
      end
    end

    # The pocket name and page the header paints (six items a page), when that page was not the last one said.
    def self.header(bag, item)
      page = item / 6
      return nil unless PokeAccess::Cursor.changed?(bag, :ura_bag_page, "#{PokeAccess.ivar(bag, :@selPocket)}-#{page}")
      "#{PokeAccess.ivar(bag, :@pname)}, #{page + 1}/#{PokeAccess.ivar(bag, :@pages)}"
    end

    # A pocket slot as its button paints it, the item's name and "x" with the quantity; also the info key's item.
    def self.entry(bag, item)
      e = (PokeAccess.ivar(bag, :@pocket) || [])[item]
      return nil unless e
      PokeAccess::Info.set_info(:item, e[0])
      "#{PBItems.getName(e[0])}, x#{e[1]}"
    end

    # Runs the use/don't-use confirmation: the item's description first, then the box poll finds focused.
    def self.confirm(bag)
      ret = PokeAccess.ivar(bag, :@ret)
      desc = (pbGetMessage(PokeAccess.const_at("MessageTypes::ItemDescriptions"), ret) rescue nil)
      PokeAccess.speak(PokeAccess.clean(desc.to_s), true) if desc && !desc.to_s.empty?
      @confirm = bag
      yield
    ensure
      @confirm = nil
      PokeAccess::Cursor.reset(bag, :ura_bag_confirm)
      PokeAccess::Cursor.reset(bag, :ura_bag)
    end

    # Each frame of a confirmation: says the box its selection frame sits on (use or don't use), the first queued.
    def self.poll
      bag = @confirm
      return unless bag
      sel = PokeAccess.sprite(bag, "sel")
      idx = sel ? sel.src_rect.x / CONFIRM_BOX - 2 : nil
      return unless idx == 0 || idx == 1
      PokeAccess::Cursor.announce(bag, :ura_bag_confirm, idx, true, false) do
        PokeAccess::I18n.t(idx == 0 ? :ura_bag_use : :ura_bag_dont_use)
      end
    end
  end
end

PokeAccess::Game.define("uranium") do
  before("NewBattleBag", :show) { |bag, _a| PokeAccess::UraniumBattleBag.opened(bag) }
  after("NewBattleBag", :update, :hook_container => true) { |bag, _r, _a| PokeAccess::UraniumBattleBag.update(bag) }
  around("NewBattleBag", :useItem?) { |bag, nxt, _a| PokeAccess::UraniumBattleBag.confirm(bag) { nxt.call } }
  poll_each_frame { PokeAccess::UraniumBattleBag.poll }
end
