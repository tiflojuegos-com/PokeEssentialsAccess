# Africanvs's bezier pause menu (PokemonMenu_Scene, sprite buttons). Registers the shared sprite-button
# menu reader (core/menus/sprite_button_menu.rb) for this profile.
#
# Tres de sus ocho opciones abren pantalla SIN pbFadeOutIn y por eso volvian mudas: Guardar usa
# pbHideMenu/pbShowMenu, Misiones llama a pbQuestlog -- que es un Questlog.new -- y Logros hace
# Logros_Scene.new. Las tres corren la pantalla entera dentro de la llamada, asi que volver de ella ES el
# retorno al menu.
PokeAccess::SpriteButtonMenu.define("africanus",
                                    [["PokemonMenu_Scene", :save],
                                     ["Questlog", :initialize],
                                     ["Logros_Scene", :initialize]])
