# Africanvs's bezier pause menu (PokemonMenu_Scene, sprite buttons). Registers the shared sprite-button
# menu reader (core/menus/sprite_button_menu.rb) for this profile.
#
# Four of its eight options open their screen WITHOUT pbFadeOutIn and so came back mute: Save uses
# pbHideMenu/pbShowMenu, Missions calls pbQuestlog (a Questlog.new), Achievements does Logros_Scene.new and
# pokeDex enters the region selector via pbLoadRpgxpScene (Graphics.transition, no engine fade). All of
# them run the whole screen inside the call, so returning from it IS the return to the menu.
PokeAccess::SpriteButtonMenu.define("africanus",
                                    [["PokemonMenu_Scene", :save],
                                     ["PokemonMenu_Scene", :pokeDex],
                                     ["Questlog", :initialize],
                                     ["Logros_Scene", :initialize]])
