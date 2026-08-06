module PokeAccess
  # Reminiscencia picks up floor items through the BOTW-like "FastItemGet" plugin, whose pbItemBall plays a
  # silent animated sprite (itemAnim) with NO message on success -- so nothing reads it, unlike chests/NPC
  # gifts which use pbMessage. We voice it ourselves from the pbItemBall arguments (the plugin never does).
  module ReminItemGet
    # The spoken "found X" line for a pbItemBall call, or nil. item may be an id, a name string or a symbol.
    def self.say(item, quantity)
      return if item.nil?
      qty = (quantity || 1).to_i
      name = if item.is_a?(String)
               item
             else
               qty > 1 ? PokeAccess::Data.item_name_plural(item) : PokeAccess::Data.item_name(item)
             end
      return if name.nil? || name.to_s.empty?
      t = (qty > 1) ? PokeAccess::I18n.t(:ri_found_n, :n => qty, :name => name) :
                      PokeAccess::I18n.t(:ri_found, :name => name)
      PokeAccess.speak_clean(t, false)
    rescue StandardError
      nil
    end
  end
end

# pbItemBall is the floor-item entry point; the FastItemGet plugin's version shows only a silent sprite on
# SUCCESS, which is what needs a voice. No-op where pbItemBall is absent.
#
# Around, and only when it returns true. Announcing beforehand claimed the pickup before the bag had been
# asked: with a full bag pbStoreItem fails and the plugin prints its own "<player> found <item>!" followed by
# "But the bag is full...", so the player heard a line that was untrue, then the game's duplicate of it, then
# the refusal. On that path the game speaks for itself and the message reader already carries it.
PokeAccess::Hooks.wrap_kernel("pbItemBall", "hook_remi_itemget", :around) do |args, nxt|
  got = nxt.call
  PokeAccess::ReminItemGet.say(args[0], args[1]) if got
  got
end
