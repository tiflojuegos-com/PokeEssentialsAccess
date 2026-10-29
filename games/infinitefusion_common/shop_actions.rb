module PokeAccess
  # The rows of both games' outfit shops that core's mart reader only half reads. An action row (a Symbol in the
  # stock: the hat menus' "Remove hat", the hair shop's "Swap Color"): the description displayNewItem paints under the
  # list (getSpecialItemDescription) follows the caption core reads, said from the full level of descriptions and
  # always kept for the info key and Ctrl+T. An outfit row (clothes, a hat or a hairstyle, an Outfit the game data does
  # not know): the info key says the name the row paints and then the description displayNewItem paints for it
  # (getDescription), as it says an item's name and description. Hoenn's shops mark the outfit on with a "* " before
  # its name, said as worn in place of the mark; Kanto's mark it in no way, their isWornItem? being false, so no row
  # takes the worn colour. The dash a row paints in place of its price is said as what it stands for: an outfit
  # already owned, or in a hair shop, where no hairstyle is ever owned, the hairstyle on.
  module IFShopActions
    # The mark Hoenn's getDisplayName puts before the name of the outfit on.
    WORN_MARK = /\A\*\s*/

    # The description the shop gives an action row, asked of the mart window's adapter and then of the one it wraps
    # (a BuyAdapter, which gives none); nil where there is none.
    def self.description(ad, item)
      d = (ad.getSpecialItemDescription(item) rescue nil)
      d = (ad.getAdapter.getSpecialItemDescription(item) rescue nil) if d.nil?
      d = PokeAccess.clean(d.to_s)
      d.empty? ? nil : d
    end

    # The caption core reads with the row's description: published whole, said at the descriptions' level.
    def self.row(caption, ad, item)
      return nil if caption.nil?
      PokeAccess::Verbosity.info_line(:descriptions, [[caption, :brief], [description(ad, item), :full]], ". ")
    end

    # Whether an outfit row paints the worn mark before its name.
    def self.worn_mark?(ad, item)
      return false unless defined?(::Outfit) && item.is_a?(::Outfit)
      (ad.getDisplayName(item) rescue nil).to_s =~ WORN_MARK ? true : false
    end

    # A row's painted name less the worn mark, which the row's worn word says.
    def self.unmarked(ad, item, name)
      worn_mark?(ad, item) ? name.to_s.sub(WORN_MARK, "") : name
    end

    # A row's painted price, the dash painted in its place said as owned, or as the hairstyle on in the hair shop
    # (HairMartAdapter), which paints it for that one alone; asked of the adapter the window's BuyAdapter wraps.
    def self.price(ad, item, painted)
      return painted unless painted.to_s == "-"
      shop = (ad.getAdapter rescue nil) || ad
      return PokeAccess::I18n.t(:if_outfit_owned) if (shop.itemOwned(item) rescue false)
      (defined?(::HairMartAdapter) && shop.is_a?(::HairMartAdapter)) ? PokeAccess::I18n.t(:if_hair_current) : painted
    end

    # Notes the info key's line for an outfit row: its name as the row paints it, less the worn mark, then its
    # description as the shop paints it, asked of the adapter the window's BuyAdapter wraps; false for any other row.
    def self.note_outfit(ad, item)
      return false unless defined?(::Outfit) && item.is_a?(::Outfit)
      shop = (ad.getAdapter rescue nil) || ad
      name = PokeAccess.clean((ad.getDisplayName(item) rescue nil).to_s).sub(WORN_MARK, "")
      desc = PokeAccess.clean((shop.getDescription(item) rescue nil).to_s)
      @outfit = [item, PokeAccess.sentences([name, desc])]
      true
    end

    # The info key's line for the outfit row noted last, or nil for any other entry.
    def self.outfit_info(item)
      (@outfit && @outfit[0].equal?(item)) ? @outfit[1] : nil
    end
  end
end

PokeAccess::Game.define("infinitefusion_common") do
  override(PokeAccess::Menus, :mart_special) do |_menus, original, args|
    PokeAccess::IFShopActions.row(original.call, args[0], args[1])
  end
  override(PokeAccess::Menus, :mart_note_desc) do |_menus, original, args|
    PokeAccess::IFShopActions.note_outfit(args[0], args[1]) || original.call
  end
  override(PokeAccess::Info, :item_info) do |_info, original, args|
    PokeAccess::IFShopActions.outfit_info(args[0]) || original.call
  end
  override(PokeAccess::Menus, :mart_worn?) do |_menus, original, args|
    PokeAccess::IFShopActions.worn_mark?(args[0], args[1]) || original.call
  end
  override(PokeAccess::Menus, :mart_name) do |_menus, original, args|
    PokeAccess::IFShopActions.unmarked(args[0], args[1], original.call)
  end
  override(PokeAccess::Menus, :mart_price) do |_menus, original, args|
    PokeAccess::IFShopActions.price(args[0], args[1], original.call)
  end
end
