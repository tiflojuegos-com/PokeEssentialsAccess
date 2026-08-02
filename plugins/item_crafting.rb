# Item Crafting: the recipe workbench (class ItemCraft_Scene), shipped by several fangames as a plugin.
# Known copies: the "Crafteo" script and the "Item Crafting UI Plus" plugin. Cursor and amount live in
# LOCAL variables inside a blocking loop, so the read points are the redraw calls the loop makes on every
# change -- there is no window and no index ivar to poll.
#
# The two copies seen so far genuinely differ, which is why this reader asks what the scene HAS instead of
# assuming a shape:
#   * redraw is pbRedrawItem in one and pbRedrawMenu (+ refreshNumbers for the detail) in the other
#   * one exposes an @adapter that resolves names AND stock quantities; the other has none, so the item
#     name comes from the engine-agnostic Data provider and the ingredient lines are simply not offered
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
      (PokeAccess::Data.item_name(item) rescue nil)
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
        have = (ad.getQuantity(item) rescue 0)
        name = item_name(scene, item)
        next if name.nil? || name.to_s.empty?
        out.push(PokeAccess::I18n.t(:craft_ingredient, :name => name, :have => have, :need => volume * qty))
      end
      out.empty? ? nil : out
    end

    # Whether every ingredient is in stock, or nil when this copy cannot tell.
    def self.craftable?(scene, pairs, volume)
      ad = PokeAccess.ivar(scene, :@adapter)
      return nil unless ad && ad.respond_to?(:getQuantity)
      ok = true
      pairs.each_slice(2) do |item, qty|
        ok = false if qty && (ad.getQuantity(item) rescue 0) < (volume * qty)
      end
      ok
    end

    # The focused recipe in the LIST: its name, plus a warning when the materials are short. Deduped per
    # scene, so a redraw that changed nothing stays silent.
    def self.announce_list(scene, index)
      r = recipe(scene, index)
      return unless r
      PokeAccess::Cursor.announce(scene, :craft_list, [index, screen_of(scene)], true) do
        name = item_name(scene, r[0])
        next nil if name.nil? || name.to_s.empty?
        can = craftable?(scene, r[1], 1)
        (can == false) ? PokeAccess::I18n.t(:craft_missing, :name => name) : name.to_s
      end
    rescue StandardError
      nil
    end

    # The focused recipe in DETAIL: name, amount, and the ingredients where the plugin can report them.
    def self.announce_detail(scene, index, volume)
      r = recipe(scene, index)
      return unless r
      vol = (volume || 1).to_i
      vol = 1 if vol < 1
      PokeAccess::Cursor.announce(scene, :craft_detail, [index, vol, screen_of(scene)], true) do
        name = item_name(scene, r[0], vol > 1)
        next nil if name.nil? || name.to_s.empty?
        ings = ingredients(scene, r[1], vol)
        head = (vol > 1) ? PokeAccess::I18n.t(:craft_amount, :name => name, :n => vol) : name.to_s
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
