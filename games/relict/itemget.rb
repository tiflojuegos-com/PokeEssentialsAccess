# Relict picks up floor items through the QuickPickup addon (FAST_PICK_ITEM_ACTIVE = 1 by default), whose
# pbItemBall plays a silent BOTW-style animation (itemAnim) with NO message on success -- so nothing reads
# it, unlike chests/NPC gifts which use pbMessage. We voice it ourselves from the pbItemBall arguments, the
# same gap fixed for Reminiscencia but with the modern GameData item API instead of gen-6 PBItems.
module PokeAccess
  module RelictItemGet
    # The item as the pickup card writes it: the portion name, plural past one, and for a machine the move
    # it teaches appended -- which is the whole content of that line, since the item name alone is a code.
    def self.card_name(item, qty)
      d = (GameData::Item.get(item) rescue nil)
      base = d ? (qty > 1 ? (d.portion_name_plural rescue nil) : (d.portion_name rescue nil)) : nil
      if base.nil? || base.to_s.empty?
        base = (qty > 1 ? PokeAccess::Data.item_name_plural(item) : PokeAccess::Data.item_name(item))
      end
      return base.to_s unless d && (d.is_machine? rescue false)
      mv = (GameData::Move.get(d.move).name rescue nil)
      (mv && !mv.to_s.empty?) ? PokeAccess::I18n.t(:if_machine, :item => base, :move => mv) : base.to_s
    rescue StandardError
      nil
    end

    # The spoken "found X" line for a pbItemBall call, or nil. item is an id/symbol/GameData::Item.
    def self.say(item, quantity)
      return if item.nil?
      qty = (quantity || 1).to_i
      name = card_name(item, qty)
      return if name.nil? || name.to_s.empty?
      t = (qty > 1) ? PokeAccess::I18n.t(:ri_found_n, :n => qty, :name => name) :
                      PokeAccess::I18n.t(:ri_found, :name => name)
      PokeAccess.speak_clean(t, false)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("relict") do
  # The silent animation is a PLAYER SETTING, not a constant: QuickPickup adds a "Default / Instant" option
  # and pbItemBall falls back to the engine's own message when it is Default (FAST_PICK_ITEM_ACTIVE == 0).
  # Speaking unconditionally would then announce the pickup twice for anyone who chose Default. Unknown or
  # missing constant means the addon's own default, Instant, so the line is spoken.
  # Around and not before: pbItemBall returns true only if $bag.add could take it, and announcing beforehand
  # claimed a pickup that does not happen with a full bag -- and doubled the notice the game itself prints
  # when refusing it. Spoken afterwards, and only if it was really picked up.
  kernel("pbItemBall", :around) do |args, nxt|
    got = nxt.call
    PokeAccess::RelictItemGet.say(args[0], args[1]) if got && (FAST_PICK_ITEM_ACTIVE rescue 1) != 0
    got
  end
end
