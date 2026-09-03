# Armonia's sprite-button pause menu (PokemonMenu_Scene, sprite buttons). Registers the shared sprite-button
# menu reader (core/menus/sprite_button_menu.rb) for this profile.
#
# Three of its options open their screen WITHOUT pbFadeOutIn and so came back mute: the PC calls
# pbStartScreen directly, the DexNav opens with X from the loop itself as DexNav.new.startUI, and pokeDex
# enters the region selector via pbLoadRpgxpScene (the live branch with DEXDEPENDSONLOCATION=false).
# Registering it as a nesting level also fixes the phantom announcement: the inner regional Pokedex DOES use
# pbFadeOutIn, and without this level its fade counted as the return to the menu and said "Pokedex" over
# the region list.
PokeAccess::SpriteButtonMenu.define("armonia",
                                    [["PokemonMenu_Scene", :pc],
                                     ["PokemonMenu_Scene", :pokeDex],
                                     ["DexNav", :startUI]])
