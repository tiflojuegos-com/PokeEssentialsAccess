# Africanvs's bezier pause menu (PokemonMenu_Scene, sprite buttons) on the shared sprite-button reader; the listed
# calls open subscreens without pbFadeOutIn, declared so returning from one still announces once.
PokeAccess::SpriteButtonMenu.define("africanus",
                                    [["PokemonMenu_Scene", :save],
                                     ["PokemonMenu_Scene", :pokeDex],
                                     ["Questlog", :initialize],
                                     ["Logros_Scene", :initialize]])
