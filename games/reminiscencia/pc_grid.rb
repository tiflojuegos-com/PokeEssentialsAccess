# Reminiscencia's PC box is eight slots wide over seven rows: the columns are the game's NUMROWS, which is the
# horizontal stride its cursor moves by (the names are swapped in its script).
PokeAccess::Game.define("reminiscencia") do
  override("PokeAccess::Party", :box_columns) do |_mod, original, _args|
    n = (PokeAccess.const_at("NUMROWS") rescue nil)
    (n.is_a?(Integer) && n > 0) ? n : original.call
  end
end
