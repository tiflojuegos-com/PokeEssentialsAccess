# Pokemon Armonia (vanilla Essentials 16.3, gen-6) on the core defaults; X, Z and L are labelled by what they do on
# the map, where they drive the following Pokemon, besides what they do elsewhere.
PokeAccess::Game.define("armonia") do
  button_labels :x => :arm_btn_x, :z => :arm_btn_z, :l => :arm_btn_l

  # Armonia's Input keeps RPG Maker XP's default letters, as in the pause menu's DexNav key, "A".
  key_hints PokeAccess::KeyHints::RGSS_LETTERS
  # Carrying AYUDAPADDUIG counts as Surf: the game's autosurf needs nothing else.
  field_move_item(:SURF, :AYUDAPADDUIG)
end
