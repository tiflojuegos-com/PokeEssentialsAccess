# Pokemon Armonia constants: vanilla Essentials 16.3, the same gen-6 base as the core defaults, so this
# only relabels the field button the remap menu shows (everything generic is already covered by core).
#
# X on the MAP switches to the previous following Pokemon (FOLLOW_KEY_PREVIOUS of the follow script). The
# DexNav is on X too, but only INSIDE the pause menu, so labelling it DexNav in the key menu described an
# action that key does not perform where the player is going to press it.
PokeAccess::Game.define("armonia") do
  button_labels :x => :arm_btn_x
end
