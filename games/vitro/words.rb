# Core's lines said in Vitro's own words: what its Cut clears is thorns (Kernel.pbCut, 0318_MO Mejoradas). Its bike, Surf and
# money are the ones core names (Surf by that name, though WATERFALL is what it asks; 0362_Pokemon_Followpoke_Bezier); its lens
# goes by the item that works it (lens.rb).
PokeAccess::Game.define("vitro") do
  override("PokeAccess::I18n", :t) do |_mod, original, args|
    args[0] == :loc_cut_tree ? PokeAccess::I18n.t(:perseida_thorns, args[1]) : original.call
  end
end
