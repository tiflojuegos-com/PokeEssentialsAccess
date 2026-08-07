# Item Crafting workbench (ItemCraft_Scene), shipped as "Crafteo" and as "Item Crafting UI Plus". Cursor and
# amount are locals inside a blocking loop, so the read points are the scene's own redraw calls.
module PokeAccess
  module ItemCrafting
    # The recipe at an index, as [result_item, flat ingredient pairs], or nil.
    #
    # @stock holds one of two shapes: the inline recipe [item, [ingredient, qty, ...]] in the older copies,
    # or a GameData::Recipe id in the newer one. The shape is read, never assumed.
    def self.recipe(scene, index)
      stock = PokeAccess.ivar(scene, :@stock)
      return nil unless stock.is_a?(Array) && index && index >= 0 && index < stock.length
      row = stock[index]
      return [row[0], (row[1] || [])] if row.is_a?(Array)
      data = (GameData::Recipe.get(row) rescue nil)
      return nil if data.nil?
      [(data.item rescue nil), flatten_pairs((data.ingredients rescue nil))]
    end

    # Ingredients as a flat [item, qty, item, qty...] array, which is what each_slice(2) downstream expects.
    # param ings pairs (GameData copies) or an already flat array (older copies)
    def self.flatten_pairs(ings)
      return [] unless ings.is_a?(Array)
      return ings unless ings[0].is_a?(Array)
      out = []
      ings.each { |pair| out.push(pair[0], pair[1]) }
      out
    end

    # An item's spoken name, through the scene's adapter first and the mod's data provider after.
    #
    # The plural is asked for before anything else, because the adapter's getName only returns the singular.
    # An ingredient may also be a category flag (a plain String such as "berry"); the screen prints what the
    # scene's own FLAG_TO_TEXT says for it, so that table is consulted before falling back to the raw flag.
    # param plural true to ask for the plural form
    def self.item_name(scene, item, plural = false)
      ad = PokeAccess.ivar(scene, :@adapter)
      if plural
        if ad && ad.respond_to?(:getNamePlural)
          n = (ad.getNamePlural(item) rescue nil)
          return n if n && !n.to_s.empty?
        end
        n = (PokeAccess::Data.item_name_plural(item) rescue nil)
        return n if n && !n.to_s.empty?
      elsif ad && ad.respond_to?(:getName)
        n = (ad.getName(item) rescue nil)
        return n if n && !n.to_s.empty?
      end
      n = (PokeAccess::Data.item_name(item) rescue nil)
      return n if n && !n.to_s.empty?
      return nil unless item.is_a?(String)
      table = (ItemCraft_Scene::FLAG_TO_TEXT rescue nil)
      label = (table.is_a?(Hash) ? table[item.downcase] : nil) || item
      (_INTL(label) rescue label)
    end

    # How many the player has of an ingredient, or nil when the adapter cannot say.
    # A category flag has no single item, so every item carrying the flag is added up, as the screen does.
    def self.stock(ad, item)
      return (ad.getQuantity(item) rescue 0) unless item.is_a?(String)
      total = 0
      GameData::Item.each do |it|
        total += (ad.getQuantity(it) rescue 0) if (it.has_flag?(item) rescue false)
      end
      total
    rescue StandardError
      nil
    end

    # Which of the plugin's two screens is showing, when the copy tracks it (0 is the list).
    def self.screen_of(scene)
      PokeAccess.ivar(scene, :@pantalla)
    end

    # "have of needed" per ingredient, or nil when this copy cannot report stock.
    # param volume how many crafts the amount screen is set to
    def self.ingredients(scene, pairs, volume)
      ad = PokeAccess.ivar(scene, :@adapter)
      return nil unless ad && ad.respond_to?(:getQuantity)
      out = []
      pairs.each_slice(2) do |item, qty|
        next unless qty
        have = stock(ad, item)
        name = item_name(scene, item)
        next if name.nil? || name.to_s.empty?
        out.push(if have
                   PokeAccess::I18n.t(:craft_ingredient, :name => name, :have => have, :need => volume * qty)
                 else
                   PokeAccess::I18n.t(:craft_ingredient_need, :name => name, :need => volume * qty)
                 end)
      end
      out.empty? ? nil : out
    end

    # Whether every ingredient is in stock, or nil when this copy cannot tell. Counts through the stock
    # helper so a category flag adds up the same way the detail screen adds it.
    def self.craftable?(scene, pairs, volume)
      ad = PokeAccess.ivar(scene, :@adapter)
      return nil unless ad && ad.respond_to?(:getQuantity)
      ok = true
      pairs.each_slice(2) do |item, qty|
        have = stock(ad, item)
        ok = false if qty && have && have < (volume * qty)
      end
      ok
    end

    # How many one craft produces where the copy has a yield and it is more than one, else nil.
    #
    # A separate datum, never a factor: the screen paints the yield beside the item name and the volume in
    # its own counter, and the two are never multiplied on screen.
    def self.recipe_yield(scene, index)
      stock = PokeAccess.ivar(scene, :@stock)
      return nil unless stock.is_a?(Array) && index && index >= 0 && index < stock.length
      row = stock[index]
      return nil if row.is_a?(Array)
      y = (GameData::Recipe.get(row).yield rescue nil)
      (y.is_a?(Integer) && y > 1) ? y : nil
    rescue StandardError
      nil
    end

    # The focused recipe in the list: its name, plus a warning when the materials are short.
    #
    # The shortage warning is the one place this reader says more than the screen paints, and it is
    # deliberate: it reveals nothing hidden, since the same count sits on the detail screen one keypress
    # away, and a sighted player sees at a glance which rows are worth opening.
    def self.announce_list(scene, index)
      r = recipe(scene, index)
      return unless r
      PokeAccess::Cursor.announce(scene, :craft_list, index, true) do
        name = item_name(scene, r[0])
        next nil if name.nil? || name.to_s.empty?
        can = craftable?(scene, r[1], 1)
        (can == false) ? PokeAccess::I18n.t(:craft_missing, :name => name) : name.to_s
      end
    rescue StandardError
      nil
    end

    # The focused recipe in detail: name, amount, yield and the ingredients where the plugin reports them.
    #
    # One copy switches the screen back to the list before redrawing on the way out, so a redraw with the
    # list showing is the "we just left" signal: it clears both dedup slots instead of describing anything.
    # The detail slot has to go too, because that copy also resets the volume to 1 on the way out, which is
    # the value the next visit opens on.
    #
    # The ingredient line is IN the dedup key, not only in the spoken text. Crafting changes what you have
    # without moving the cursor or the amount, so on [index, volume] alone the counters that just dropped
    # are never read again and the player learns they are short only by failing.
    def self.announce_detail(scene, index, volume)
      r = recipe(scene, index)
      return unless r
      if screen_of(scene) == 0
        PokeAccess::Cursor.reset(scene, :craft_list)
        PokeAccess::Cursor.reset(scene, :craft_detail)
        return
      end
      vol = (volume || 1).to_i
      vol = 1 if vol < 1
      ings = ingredients(scene, r[1], vol)
      PokeAccess::Cursor.announce(scene, :craft_detail, [index, vol, ings], true) do
        name = item_name(scene, r[0], vol > 1)
        next nil if name.nil? || name.to_s.empty?
        head = (vol > 1) ? PokeAccess::I18n.t(:craft_amount, :name => name, :n => vol) : name.to_s
        y = recipe_yield(scene, index)
        head = PokeAccess::I18n.t(:craft_yield, :head => head, :n => y) if y
        ings ? PokeAccess::I18n.t(:craft_detail, :head => head, :list => ings.join(", ")) : head
      end
    rescue StandardError
      nil
    end
  end
end

# One copy redraws everything through pbRedrawItem; the other splits the list (pbRedrawMenu) from the amount
# and ingredients (refreshNumbers). All three bind :optional and dedup on their own slot.
PokeAccess::Hooks.after_hook("ItemCraft_Scene", :pbRedrawItem, :optional => true) do |s, _r, a|
  PokeAccess::ItemCrafting.announce_detail(s, a[0], a[1])
end
PokeAccess::Hooks.after_hook("ItemCraft_Scene", :pbRedrawMenu, :optional => true) do |s, _r, a|
  PokeAccess::ItemCrafting.announce_list(s, a[0])
end
PokeAccess::Hooks.after_hook("ItemCraft_Scene", :refreshNumbers, :optional => true) do |s, _r, a|
  PokeAccess::ItemCrafting.announce_detail(s, a[0], a[1])
end
