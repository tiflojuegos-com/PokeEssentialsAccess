module PokeAccess
  # v22 bag screen (Essentials v22: UI::BagVisuals + UI::BagVisualsList). The list window is created with
  # active = false, so it is read here on the screen's own cursor callback rather than by the generic
  # command-window reader. Item navigation goes through refresh_on_index_changed; pocket changes go through
  # set_pocket (which does not), so both are hooked.
  module BagV22
    # The focused bag entry: "Item ×qty" (or just the name for unstackable items), or the close label.
    def self.item_line(vis)
      id = (vis.item rescue nil)
      return PokeAccess::I18n.t(:mn_close_bag) unless id
      data = (GameData::Item.get(id) rescue nil)
      return id.to_s unless data
      PokeAccess::Info.set_info(:item, id)
      name = (data.display_name rescue (data.name rescue id).to_s)
      if (data.show_quantity? rescue false)
        qty = (vis.instance_variable_get(:@bag).quantity(id) rescue nil)
        return PokeAccess::I18n.t(:bag_item, :name => name, :qty => qty) if qty && qty > 0
      end
      name
    end

    # The current pocket's display name.
    def self.pocket_name(vis)
      p = (vis.pocket rescue nil)
      return nil unless p
      (GameData::BagPocket.get(p).name rescue p.to_s)
    end
  end
end

# Item navigation (fires in both the normal and choose-item loops).
PokeAccess::V22.on_nav("UI::BagVisuals") { |vis| PokeAccess::BagV22.item_line(vis) }

# Pocket change (left/right) goes through set_pocket, which does not fire refresh_on_index_changed, so
# announce the new pocket plus its focused item and prime the nav dedup key to avoid an immediate repeat.
if PokeAccess::Engine.has?("UI::BagVisuals")
  PokeAccess::Hooks.after_hook("UI::BagVisuals", :set_pocket) do |vis, _ret, _args|
    line = PokeAccess::BagV22.item_line(vis)
    name = PokeAccess::BagV22.pocket_name(vis)
    parts = []
    parts.push(PokeAccess::I18n.t(:bag_pocket, :name => name)) if name && !name.to_s.empty?
    parts.push(line) if line && !line.to_s.empty?
    unless parts.empty?
      vis.instance_variable_set(:@access_v22_key, [(vis.index rescue nil), line])
      PokeAccess.speak(parts.join(". "), true)
    end
  end
end
