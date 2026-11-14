# Xenoverse official source 3356658c (game 1.5.5, Essentials gen6 lineage).
# Preserve generic obstacle naming until its PokeWES field rules are verified.
PokeAccess::Game.define("xenoverse") do
  field_moves_unnamed
  # 226_NewBag.rb paints Q/W for Input::L/R, Z for A and X for B.
  key_hints 'Q' => :l, 'W' => :r, 'Z' => :a, 'X' => :b
end
