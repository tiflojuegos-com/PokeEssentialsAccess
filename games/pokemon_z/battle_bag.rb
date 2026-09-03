# Battle bag (NewBattleBag, script 232, custom EBS ui; not Window_PokemonBag). Game-prefixed module so this
# Z-specific reader never collides with a core namespace, matching the ZSummary/ZPokedex convention.
module PokeAccess
  module ZBattleBag
    # Speaks the battle bag depending on its state: an item just confirmed, the pocket chooser, or the item
    # list.
    def self.announce(bag)
      return if announce_chosen(bag)
      selp = bag.instance_variable_get(:@selPocket)
      if selp == 0
        announce_pockets(bag)
      else
        announce_items(bag)
      end
    rescue StandardError
      nil
    end

    # Confirming an item calls intoPocket from INSIDE update, and intoPocket puts @selPocket back to 0 before
    # update returns. The after-hook therefore landed on what looks like the pocket chooser and named the
    # pocket the cursor happened to be over: press C on "Pocion, 5" and hear "Medicinas". @ret is what the
    # scene's own loop reads to know an item was picked, so it is the honest signal here too. Returns true
    # when it owns the frame, so the state readers below stay out of the way. Every rejection path clears
    # @ret itself (cancel on the confirm, show, closeCurrent), so a set @ret always means the confirm
    # dialogue is the live UI and owning the frame there is correct.
    def self.announce_chosen(bag)
      ret = bag.instance_variable_get(:@ret)
      return false if ret.nil? || ret.to_i <= 0
      if PokeAccess::Cursor.changed?(bag, :bb_key, "ret#{ret}")
        name = PBItems.getName(ret).to_s
        PokeAccess.speak(name, true) unless name.empty?
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
      PokeAccess.speak(txt, true) if txt && !txt.empty?
    end

    # Speaks the item-list screen entry (item with quantity or back). One shared slot across the three
    # states, on purpose: the prefixes differ, so switching state re-announces even on the same index.
    def self.announce_items(bag)
      if bag.instance_variable_get(:@back)
        return unless PokeAccess::Cursor.changed?(bag, :bb_key, "back")
        return PokeAccess.speak(PokeAccess::I18n.t(:bb_back), true)
      end
      item   = bag.instance_variable_get(:@item)
      pocket = bag.instance_variable_get(:@pocket)
      entry  = (pocket && item) ? pocket[item] : nil
      return unless PokeAccess::Cursor.changed?(bag, :bb_key, "it#{item}")
      if entry
        PokeAccess::Info.set_info(:item, entry[0])
        PokeAccess.speak("#{PBItems.getName(entry[0])}, #{entry[1]}", true)
      end
    end
  end
end

PokeAccess::Game.define("pokemon_z") do
  after("NewBattleBag", :update) do |bag, _r, _a|
    PokeAccess::ZBattleBag.announce(bag)
  end
end
