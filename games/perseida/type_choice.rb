# Perseida's type choice (SeleccionTipo in 0220_Seleccion Elemento, map 35): a grid of pictures under a painted question.
# @items holds each picture's file and name, and the loop redraws the selector every frame.
PokeAccess::Game.define("perseida") do
  read_on_open("SeleccionTipo", :pbStartScene, :optional => true) do |_scene|
    _INTL("Escoge el tipo con el que seas más afin.")
  end
  after("SeleccionTipo", :redrawSelector, :optional => true) do |scene, _r, _a|
    items = PokeAccess.ivar(scene, :@items)
    idx = PokeAccess.ivar(scene, :@selected_item)
    if items.is_a?(Array) && idx.is_a?(Integer) && items[idx]
      PokeAccess::Cursor.announce(scene, :perseida_type, idx, true, false) do
        PokeAccess::Verbosity.list_entry(items[idx][1], idx + 1, items.length)
      end
    end
  end
end
