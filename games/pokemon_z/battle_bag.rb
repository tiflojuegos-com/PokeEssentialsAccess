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
    # when it owns the frame, so the state readers below stay out of the way.
    # Nothing clears @ret when the game refuses an item it cannot use on the chosen target: the bag reopens
    # its dialogue every frame with the same value still set. The dedup keeps that from being repeated, but
    # it also means the frame stays silent -- a dead end of the game's own, inherited rather than caused.
    def self.announce_chosen(bag)
      ret = bag.instance_variable_get(:@ret)
      return false if ret.nil? || ret.to_i <= 0
      key = "ret#{ret}"
      return true if key == (bag.instance_variable_get(:@access_key) rescue nil)
      bag.instance_variable_set(:@access_key, key)
      name = PBItems.getName(ret).to_s
      PokeAccess.speak(name, true) unless name.empty?
      true
    end

    # Speaks the pocket-selection screen entry (pocket, last item or back).
    def self.announce_pockets(bag)
      idx = bag.instance_variable_get(:@index)
      key = "main#{idx}"
      return if key == (bag.instance_variable_get(:@access_key) rescue nil)
      bag.instance_variable_set(:@access_key, key)
      labels = (PokeAccess.const_at("NewBattleBag::PocketText") || [])
      txt = case idx
            when 0, 1, 2, 3 then labels[idx].to_s
            when 4
              lu = bag.instance_variable_get(:@lastUsed)
              (lu && lu > 0) ? "Ultimo objeto, #{PBItems.getName(lu)}" : "Ultimo objeto"
            when 5 then "Atras"
            else nil
            end
      PokeAccess.speak(txt, true) if txt && !txt.empty?
    end

    # Speaks the item-list screen entry (item with quantity or back).
    def self.announce_items(bag)
      if bag.instance_variable_get(:@back)
        return if (bag.instance_variable_get(:@access_key) rescue nil) == "back"
        bag.instance_variable_set(:@access_key, "back")
        return PokeAccess.speak("Atras", true)
      end
      item   = bag.instance_variable_get(:@item)
      pocket = bag.instance_variable_get(:@pocket)
      entry  = (pocket && item) ? pocket[item] : nil
      key = "it#{item}"
      return if key == (bag.instance_variable_get(:@access_key) rescue nil)
      bag.instance_variable_set(:@access_key, key)
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
