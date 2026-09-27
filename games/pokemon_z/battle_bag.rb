# Pokemon Z's battle bag (NewBattleBag, a custom EBS screen rather than Window_PokemonBag): the pocket buttons, a
# pocket's items under its name and page, and the use/don't-use confirmation with the item's description.
module PokeAccess
  module ZBattleBag
    # Width of one box in the confirmation's selection frame, whose source x starts two boxes in.
    CONFIRM_BOX = 466

    # Items a pocket shows per page, in its 2x3 grid.
    PAGE_SIZE = 6

    # Speaks the battle bag by its state: an item just confirmed, the pocket chooser or the item list.
    def self.announce(bag)
      return if announce_chosen(bag)
      selp = bag.instance_variable_get(:@selPocket)
      if selp == 0
        PokeAccess::Cursor.reset(bag, :bb_page)
        announce_pockets(bag)
      else
        announce_items(bag)
      end
    rescue StandardError
      nil
    end

    # Says the item just confirmed, from @ret (confirming resets @selPocket inside update); true while @ret is
    # set, which every rejection path clears, so the state readers stay out.
    def self.announce_chosen(bag)
      ret = bag.instance_variable_get(:@ret)
      return false if ret.nil? || ret.to_i <= 0
      if PokeAccess::Cursor.changed?(bag, :bb_key, "ret#{ret}")
        name = PBItems.getName(ret).to_s
        PokeAccess.speak(name, true)
      end
      true
    end

    # Speaks the pocket-selection screen entry (pocket, last item or back). The pocket labels are the
    # game's own PocketText strings; the two buttons are icons, so their names are mod prose via i18n.
    def self.announce_pockets(bag)
      idx = bag.instance_variable_get(:@index)
      return unless PokeAccess::Cursor.changed?(bag, :bb_key, "main#{idx}")
      labels = (PokeAccess.const_at("NewBattleBag::PocketText") || [])
      txt = case idx
            when 0, 1, 2, 3 then labels[idx].to_s
            when 4
              lu = bag.instance_variable_get(:@lastUsed)
              last = PokeAccess::I18n.t(:bb_last)
              (lu && lu > 0) ? "#{last}, #{PBItems.getName(lu)}" : last
            when 5 then PokeAccess::I18n.t(:bb_back)
            else nil
            end
      PokeAccess.speak(txt, true)
    end

    # Speaks the item-list screen entry (item with quantity or back), headed by the pocket's name and page when that
    # page was not the last one said. One shared slot across the three states, on purpose: the prefixes differ, so
    # switching state re-announces even on the same index.
    def self.announce_items(bag)
      back = bag.instance_variable_get(:@back)
      item = bag.instance_variable_get(:@item).to_i
      return unless PokeAccess::Cursor.changed?(bag, :bb_key, back ? "back" : "it#{item}")
      pocket = bag.instance_variable_get(:@pocket)
      entry = (back || pocket.nil?) ? nil : pocket[item]
      PokeAccess::Info.set_info(:item, entry[0]) if entry
      line = back ? PokeAccess::I18n.t(:bb_back) : (entry ? "#{PBItems.getName(entry[0])}, #{entry[1]}" : nil)
      return if line.nil?
      PokeAccess.speak([header(bag, item), line].compact.join(". "), true)
    end

    # The pocket's name as its bar paints it and, from the positions' medium level, its page ("1/2" on the bar), when
    # the focused item's page was not the last one said (entering the pocket or crossing to another page); else nil.
    def self.header(bag, item)
      page = item / PAGE_SIZE
      return nil unless PokeAccess::Cursor.changed?(bag, :bb_page, "#{bag.instance_variable_get(:@selPocket)}-#{page}")
      pages = bag.instance_variable_get(:@pages).to_i
      pos = PokeAccess::Verbosity.keep?(:positions, :medium) ? PokeAccess::I18n.t(:zbb_page, :n => page + 1, :tot => pages) : nil
      parts = [bag.instance_variable_get(:@pname), pos].reject { |p| p.nil? || p.to_s.strip.empty? }
      parts.empty? ? nil : parts.join(", ")
    end

    # Runs the use/don't-use confirmation: the item's description, queued after its name, then the box the poll finds
    # focused, by the label painted on it.
    def self.confirm(bag)
      desc = PokeAccess::Data.item_description(bag.instance_variable_get(:@ret))
      PokeAccess.speak_clean(desc.to_s, false) if desc && !desc.to_s.strip.empty?
      @labels = []
      @confirm = bag
      yield
    ensure
      @confirm = nil
      PokeAccess::Cursor.reset(bag, :bb_confirm)
    end

    # Keeps a label the open confirmation paints on one of its two overlays (USAR and NO USAR in the Spanish build).
    def self.painted(bitmap, text)
      bag = @confirm
      return if bag.nil? || bitmap.nil?
      [0, 1].each do |i|
        spr = PokeAccess.sprite(bag, "overlay2_#{i + 1}")
        @labels[i] = text.to_s if spr && spr.bitmap.equal?(bitmap)
      end
    rescue StandardError
      nil
    end

    # Each frame of a confirmation: says the box its selection frame sits on, by its painted label (the mod's word for
    # it when none was caught), the first one queued.
    def self.poll
      bag = @confirm
      return unless bag
      sel = PokeAccess.sprite(bag, "sel")
      idx = sel ? sel.src_rect.x / CONFIRM_BOX - 2 : nil
      return unless idx == 0 || idx == 1
      PokeAccess::Cursor.announce(bag, :bb_confirm, idx, true, false) do
        (@labels || [])[idx] || PokeAccess::I18n.t(idx == 0 ? :ura_bag_use : :ura_bag_dont_use)
      end
    end
  end
end

PokeAccess::Game.define("pokemon_z") do
  after("NewBattleBag", :update) do |bag, _r, _a|
    PokeAccess::ZBattleBag.announce(bag)
  end
  around("NewBattleBag", :useItem?) { |bag, nxt, _a| PokeAccess::ZBattleBag.confirm(bag) { nxt.call } }
  kernel("pbDrawOutlineText", :before) { |args, _r| PokeAccess::ZBattleBag.painted(args[0], args[5]) }
  poll_each_frame { PokeAccess::ZBattleBag.poll }
end
