# Item Crafting: the recipe workbench (class ItemCraft_Scene), shipped by several fangames as a plugin.
# Known copies: the "Crafteo" script and the "Item Crafting UI Plus" plugin. Cursor and amount live in
# LOCAL variables inside a blocking loop, so the read points are the redraw calls the loop makes on every
# change -- there is no window and no index ivar to poll.
#
# The two copies seen so far genuinely differ, which is why this reader asks what the scene HAS instead of
# assuming a shape:
#   * redraw is pbRedrawItem in one and pbRedrawMenu (+ refreshNumbers for the detail) in the other
#   * every copy exposes an @adapter that resolves names and stock quantities, so the guards that fall back
#     to the engine-agnostic Data provider are belt and braces rather than a live path
# Every hook is :optional, as every hook in plugins/ must be: the plugin may be absent, or be a version
# that never had this method.
module PokeAccess
  module ItemCrafting
    # The recipe at index, as [result_item, ingredient_pairs], or nil.
    #
    # @stock holds two different things depending on the copy, and this is the divergence that decides
    # whether the reader works or talks nonsense: the older copies store the recipe INLINE as
    # [result_item, [ingredient, qty, ...]], while the GameData-era one stores a recipe ID and keeps the
    # data in GameData::Recipe (item / yield / ingredients). Reading the shape instead of assuming one is
    # what lets a single reader serve both -- and what made it fall silent, rather than wrong, before this
    # branch existed.
    def self.recipe(scene, index)
      stock = PokeAccess.ivar(scene, :@stock)
      return nil unless stock.is_a?(Array) && index && index >= 0 && index < stock.length
      row = stock[index]
      return [row[0], (row[1] || [])] if row.is_a?(Array)
      data = (GameData::Recipe.get(row) rescue nil)
      return nil if data.nil?
      [(data.item rescue nil), flatten_pairs((data.ingredients rescue nil))]
    end

    # GameData recipes list ingredients as pairs already; older copies use a flat [item, qty, item, qty...]
    # array. Everything downstream walks it with each_slice(2), so both arrive in that shape.
    def self.flatten_pairs(ings)
      return [] unless ings.is_a?(Array)
      return ings unless ings[0].is_a?(Array)
      out = []
      ings.each { |pair| out.push(pair[0], pair[1]) }
      out
    end

    # An item's spoken name. The scene's own adapter wins when it has one (it knows the plugin's item ids),
    # falling back to the mod's provider, which covers both engine eras.
    #
    # The plural is asked for FIRST and separately: the adapter's getName only ever returns the singular, so
    # consulting it before the plural made "cantidad 3, Pocion" out of what should be "3 Pociones" -- the
    # branch could never be reached in either game that ships this plugin.
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
      # A recipe ingredient is not always a concrete item: some copies of the plugin write a CATEGORY flag
      # there instead, as a plain String ("berry" for "any berry"). Asking GameData for it answers nothing,
      # and the caller drops a nameless ingredient -- so the recipe was read with a line missing and no hint
      # that anything was missing.
      #
      # The screen does not print the raw flag either: it looks the flag up in the scene's own table and
      # prints what that says ("Any Berry"). Reading the table is what keeps the spoken word and the printed
      # word the same; the raw flag is the fallback for a copy that has no table.
      return nil unless item.is_a?(String)
      table = (ItemCraft_Scene::FLAG_TO_TEXT rescue nil)
      label = (table.is_a?(Hash) ? table[item.downcase] : nil) || item
      (_INTL(label) rescue label)
    end

    # How many the player has of an ingredient. A category flag has no single item to ask about, so the
    # screen adds up every item carrying the flag -- and asking the adapter for the flag itself answers 0,
    # which would state a shortage the screen is not showing.
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

    # Which of the plugin's two screens is showing, when the copy tracks it. It joins both dedup keys
    # because the screens share an index: coming back from the amount screen to the list redraws the SAME
    # recipe, so without this the list stays mute -- and a redraw of the amount screen on the way out
    # re-announces the detail of a screen the player has already left.
    def self.screen_of(scene)
      PokeAccess.ivar(scene, :@pantalla)
    end

    # "have of needed" per ingredient, or nil when this copy of the plugin cannot report stock.
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

    # Whether every ingredient is in stock, or nil when this copy cannot tell. Counts through the same stock
    # helper the detail uses: asking the adapter directly answers 0 for a category flag, so the list would
    # warn "you are short" about a recipe whose detail, one keypress away, says you have twelve.
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

    # How many items one craft produces. The GameData-era copy multiplies the volume by a per-recipe yield
    # and prints "name x5", so saying the volume alone understates what the recipe makes by that factor. The
    # yield is reached the same way the recipe itself is -- through @stock, whose row is the recipe id in
    # that copy and the inline data in the others, which have no yield at all.
    def self.made(scene, index, vol)
      stock = PokeAccess.ivar(scene, :@stock)
      return vol unless stock.is_a?(Array) && index && index >= 0 && index < stock.length
      row = stock[index]
      return vol if row.is_a?(Array)
      y = (GameData::Recipe.get(row).yield rescue nil)
      (y.is_a?(Integer) && y > 0) ? vol * y : vol
    rescue StandardError
      vol
    end

    # The focused recipe in the LIST: its name, plus a warning when the materials are short. Deduped per
    # scene, so a redraw that changed nothing stays silent. The screen is NOT part of the key: it reads 0
    # both before entering the detail and on the way back, so it never distinguished anything -- what makes
    # the list speak again on return is announce_detail clearing this slot.
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

    # The focused recipe in DETAIL: name, amount, and the ingredients where the plugin can report them.
    #
    # Leaving the detail runs this same redraw, and one copy of the plugin switches the screen back BEFORE
    # redrawing -- so the reader was describing a screen the player had just backed out of. That call is
    # exactly the "we just left" signal, so it is used for the one thing that was missing instead: clearing
    # the list's dedup, which otherwise holds the same key it had on the way in and leaves the list mute on
    # return.
    def self.announce_detail(scene, index, volume)
      r = recipe(scene, index)
      return unless r
      if screen_of(scene) == 0
        PokeAccess::Cursor.reset(scene, :craft_list)
        return
      end
      vol = (volume || 1).to_i
      vol = 1 if vol < 1
      PokeAccess::Cursor.announce(scene, :craft_detail, [index, vol], true) do
        name = item_name(scene, r[0], vol > 1)
        next nil if name.nil? || name.to_s.empty?
        ings = ingredients(scene, r[1], vol)
        n = made(scene, index, vol)
        head = (n > 1) ? PokeAccess::I18n.t(:craft_amount, :name => name, :n => n) : name.to_s
        ings ? PokeAccess::I18n.t(:craft_detail, :head => head, :list => ings.join(", ")) : head
      end
    rescue StandardError
      nil
    end
  end
end

# One copy calls pbRedrawItem for everything; the other splits the list (pbRedrawMenu) from the amount and
# ingredients (refreshNumbers). Registering all three is safe because each binds only where it exists and
# each announcement is deduped on its own slot.
PokeAccess::Hooks.after_hook("ItemCraft_Scene", :pbRedrawItem, :optional => true) do |s, _r, a|
  PokeAccess::ItemCrafting.announce_detail(s, a[0], a[1])
end
PokeAccess::Hooks.after_hook("ItemCraft_Scene", :pbRedrawMenu, :optional => true) do |s, _r, a|
  PokeAccess::ItemCrafting.announce_list(s, a[0])
end
PokeAccess::Hooks.after_hook("ItemCraft_Scene", :refreshNumbers, :optional => true) do |s, _r, a|
  PokeAccess::ItemCrafting.announce_detail(s, a[0], a[1])
end
