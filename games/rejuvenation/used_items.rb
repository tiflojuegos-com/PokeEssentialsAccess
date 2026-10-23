module PokeAccess
  # Rejuvenation's used-items window (pbUsedItemsDisplay): each item the party's auto-heal used, how many and how many
  # are left, painted in windows beside the message that says the party was healed; said right after that message.
  module RejuvUsedItems
    # The items as the windows paint them: name, how many were used and how many the bag has left; nil for none.
    def self.text(useditems)
      parts = []
      (useditems || []).each do |item, amount|
        name = PokeAccess.clean(PokeAccess::Data.item_name(item))
        parts.push(PokeAccess::I18n.t(:rj_used_item, :name => name, :n => amount.to_i,
                                      :left => $PokemonBag.pbQuantity(item).to_i))
      end
      parts.empty? ? nil : parts.join(", ")
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  kernel("pbUsedItemsDisplay", :before) do |args, _r|
    t = PokeAccess::RejuvUsedItems.text(args[1])
    PokeAccess.after_next_line(t) if t
  end
end
