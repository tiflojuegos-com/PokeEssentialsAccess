# The "BW Key Items" ceremony (GetKeyItemScene), which paints only the item's icon: said as it starts, leaving the
# item's name to the game's own message after it; a profile whose game shows no message names it from the picture.
module PokeAccess
  module KeyItemGet
    # What the ceremony says as it starts: only what it is.
    def self.announce(_item)
      PokeAccess.speak(PokeAccess::I18n.t(:key_item_ceremony), false)
    end

    # The item a picture name stands for (VIAL_key as "Vial"), for a game whose ceremony no message follows; nil for
    # a real item.
    def self.picture_name(item)
      return nil unless item.is_a?(String)
      s = item.sub(/_key\z/i, "").sub(/\Aitem\d*_?/i, "").tr("_", " ").strip
      s.empty? ? nil : s.capitalize
    end
  end
end

PokeAccess::Hooks.before_hook("GetKeyItemScene", :pbStartScene, :optional => true) do |scene, _a|
  PokeAccess::KeyItemGet.announce(PokeAccess.ivar(scene, :@item))
end
