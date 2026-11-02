# A recipe of Perseida's workbench (0227_Item Crafter) may make more than one: the third field of its row, which the screen
# multiplies into the amount it paints. Its key bar, painted as written, is said after the first recipe.
module PokeAccess
  module PerseidaCrafting
    BAR = ["C: Crear", "Z: Lista de Recetas", "X: Salir"]

    # A recipe's line, with the bar the first time the screen says one, while key hints are said.
    def self.with_bar(scene, line)
      return line unless line && PokeAccess::Cursor.changed?(scene, :perseida_craft_bar, true)
      PokeAccess::Verbosity.with_hint(line, BAR.map { |key| PokeAccess::KeyHints.localize(key) }.join(", "))
    end
  end
end

PokeAccess::Game.define("perseida") do
  override("PokeAccess::ItemCrafting", :detail_line) do |_mod, original, args|
    PokeAccess::PerseidaCrafting.with_bar(args[0], original.call)
  end
  override("PokeAccess::ItemCrafting", :recipe_yield) do |_mod, _original, args|
    row = (PokeAccess.ivar(args[0], :@stock)[args[1]] rescue nil)
    made = row.is_a?(Array) ? row[2] : nil
    made.is_a?(Integer) && made > 1 ? made : nil
  end
end
