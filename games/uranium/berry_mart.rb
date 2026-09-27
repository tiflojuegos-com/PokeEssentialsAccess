module PokeAccess
  # Uranium's berry shop (PokemonBerryMartScene, written for this game): each row with its quantity and the berries
  # it costs, the player's berries as the scene paints them, and the shop's messages on its help window.
  module UraniumBerryMart
    # A row as the window paints it: the quantity and the item or Pokemon, then its price in berries; CANCEL last.
    # The info key keeps the item's description, or the Pokemon's Pokedex entry the scene shows for it.
    def self.row(win, i)
      stock = PokeAccess.ivar(win, :@stock) || []
      return PokeAccess::I18n.t(:pc_cancel) if i >= stock.length
      item = stock[i]
      mon = (PokeAccess.ivar(win, :@pokemon) || [])[i]
      name = mon ? PBSpecies.getName(item) : PokeAccess.ivar(win, :@adapter).getDisplayName(item)
      qty = (PokeAccess.ivar(win, :@quantity) || [])[i]
      price = price_text((PokeAccess.ivar(win, :@prices) || [])[i])
      parts = [[PokeAccess::I18n.t(:ura_bmart_count, :n => qty, :name => name), :brief]]
      parts.push([PokeAccess::I18n.t(:ura_bmart_price, :list => price), :brief]) unless price.empty?
      whole = PokeAccess::Verbosity.full_line(parts)
      if mon
        entry = (pbGetMessage(MessageTypes::Entries, item) rescue nil)
        PokeAccess::Info.set_info(:text, PokeAccess.sentences([name, PokeAccess.clean(entry.to_s)]), whole)
      else
        PokeAccess::Info.set_info(:item, item, whole)
      end
      PokeAccess::Verbosity.line(:shop_item, parts)
    end

    # A price as the window pairs it, a count and a berry each: "2 Acai Berry, 1 Bacu Berry".
    def self.price_text(price)
      return "" unless price.is_a?(Array)
      (0...(price.length / 2)).map do |k|
        PokeAccess::I18n.t(:ura_bmart_count, :n => price[k * 2], :name => PBItems.getName(price[k * 2 + 1]))
      end.join(", ")
    end

    # The berries the scene paints in its corner, each with the count the player holds; said queued when the counts
    # change (on opening and after a purchase).
    def self.berries(scene)
      list = PokeAccess.ivar(scene, :@berries)
      return unless list.is_a?(Array) && !list.empty?
      counts = list.map { |b| ($PokemonBag.pbQuantity(b) rescue 0).to_i }
      return unless PokeAccess::Cursor.changed?(scene, :ura_bmart_berries, counts)
      held = (0...list.length).map do |k|
        PokeAccess::I18n.t(:ura_bmart_count, :n => counts[k], :name => PBItems.getName(list[k]))
      end
      PokeAccess.speak(PokeAccess::I18n.t(:ura_bmart_have, :list => held.join(", ")), false)
    end
  end
end

PokeAccess::Game.define("uranium") do
  screen_reader("Window_PokemonBerryMart") { |win, i| PokeAccess::UraniumBerryMart.row(win, i) }
  after("PokemonBerryMartScene", :drawCurrentBerries) { |scene, _r, _a| PokeAccess::UraniumBerryMart.berries(scene) }
  [:pbDisplay, :pbDisplayPaused, :pbConfirm].each do |meth|
    before("PokemonBerryMartScene", meth) { |_s, args| PokeAccess.say_screen_message(args) }
  end
end
