# royal's grid pause menu ([ROYAL] - MIS SCRIPTS/007_Menu Parrilla.rb -> class Menu2), which replaces the
# standard pause menu entirely, so neither the generic command reader nor the standard pause reader sees it.
# Its @items entries are [icon_name, label, method] and @selected_item is the cursor; pbActualizarIconosMenu
# redraws on every cursor move (and on open), so the focused command's label (item[1], e.g. "Mochila",
# "Equipo") is read there, deduped by the selected index.
PokeAccess::Game.define("royal") do
  after("Menu2", :pbActualizarIconosMenu) do |menu, _ret, _args|
    items = PokeAccess.ivar(menu, :@items)
    idx   = PokeAccess.ivar(menu, :@selected_item)
    next unless items.is_a?(Array) && idx && items[idx].is_a?(Array)
    next unless PokeAccess::Cursor.changed?(menu, :pm, idx)
    label = items[idx][1]
    PokeAccess.speak_clean(label.to_s, true) if label && !label.to_s.empty?
  end
end
