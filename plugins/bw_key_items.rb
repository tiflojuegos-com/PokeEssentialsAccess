# The "BW Key Items" ceremony (GetKeyItemScene; three copies: KleinStudio's FancyItemGet in Reminiscencia
# and the reworks Añil and Royal ship): a jingle, a flash and the item's icon spinning for three seconds,
# with no text at all. A real item gets the game's "obtained" message once the animation ends; an item
# passed as a picture NAME (the Pokévial, the portable healer) never does. The item is named as the
# ceremony starts, so the jingle has a subject. @item is set by every copy's constructor.
module PokeAccess
  module KeyItemGet
    # The spoken name of what the ceremony shows: an item id through the data adapter, a picture name
    # (VIAL_key) with its suffixes shed.
    def self.name_of(item)
      return nil if item.nil?
      if item.is_a?(String)
        s = item.sub(/_key\z/i, "").sub(/\Aitem\d*_?/i, "").tr("_", " ").strip
        return s.empty? ? nil : s.capitalize
      end
      n = (PokeAccess::Data.item_name(item) rescue nil)
      (n && !n.to_s.empty?) ? n.to_s : nil
    end
  end
end

PokeAccess::Hooks.before_hook("GetKeyItemScene", :pbStartScene, :optional => true) do |scene, _a|
  n = PokeAccess::KeyItemGet.name_of(PokeAccess.ivar(scene, :@item))
  PokeAccess.speak(PokeAccess::I18n.t(:key_item_get, :name => n), false) if n
end
