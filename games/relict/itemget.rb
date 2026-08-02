# Relict picks up floor items through the QuickPickup addon (FAST_PICK_ITEM_ACTIVE = 1 by default), whose
# pbItemBall plays a silent BOTW-style animation (itemAnim) with NO message on success -- so nothing reads
# it, unlike chests/NPC gifts which use pbMessage. We voice it ourselves from the pbItemBall arguments, the
# same gap fixed for Reminiscencia but with the modern GameData item API instead of gen-6 PBItems.
module PokeAccess
  module RelictItemGet
    # The spoken "found X" line for a pbItemBall call, or nil. item is an id/symbol/GameData::Item.
    def self.say(item, quantity)
      return if item.nil?
      qty = (quantity || 1).to_i
      name = (qty > 1 ? PokeAccess::Data.item_name_plural(item) : PokeAccess::Data.item_name(item))
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
  kernel("pbItemBall", :before) do |args, _r|
    next if (FAST_PICK_ITEM_ACTIVE rescue 1) == 0
    PokeAccess::RelictItemGet.say(args[0], args[1])
  end
end
