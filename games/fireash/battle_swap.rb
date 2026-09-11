# The battle-swap screen (BattleSwapScene): the player hands three of their own team over and takes three of
# the rival's. Its help window is the only thing that says WHICH of the three choices is being made, a
# standing sprite written with text=, so it is watched; it interrupts, since every line answers a keypress.
# The list swap itself is covered by core's list witness. The scene opens with its OWN two methods, one per
# mode (pbStartRentScene, pbStartSwapScene) and no pbStartScene, so they are declared here.
PokeAccess::Game.define("fireash") do
  # The title first, and queued: it is the only thing that says WHICH of the two the screen is -- "RENTAL
  # POKeMON" when picking three of the six offered, "POKeMON SWAP" when handing three over -- and the two
  # look the same from a list of names.
  info_window "BattleSwapScene", "title", :swap_title,
              :open => ["pbStartRentScene", "pbStartSwapScene"]
  info_window "BattleSwapScene", "help", :swap_help,
              :interrupt => true, :open => ["pbStartRentScene", "pbStartSwapScene"]
end
