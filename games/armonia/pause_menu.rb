# Armonia's sprite-button pause menu (PokemonMenu_Scene, sprite buttons). Registers the shared sprite-button
# menu reader (core/menus/sprite_button_menu.rb) for this profile.
#
# Dos de sus opciones abren pantalla SIN pbFadeOutIn y por eso volvian mudas: el PC llama a pbStartScreen
# a pelo, y el DexNav se abre con X desde el propio bucle como DexNav.new.startUI.
PokeAccess::SpriteButtonMenu.define("armonia",
                                    [["PokemonMenu_Scene", :pc],
                                     ["DexNav", :startUI]])
