# FL's Game Over (Scene_Gameover, opened by a lost battle or the Game Over command): says the picture and the confirm
# key that goes to the title screen. Its go_to_title tells it from a game's own Scene_Gameover, read by that profile.
PokeAccess::Hooks.before_hook("Scene_Gameover", :main, :optional => true) do |_scene, _args|
  if Object.private_method_defined?(:go_to_title) || Object.method_defined?(:go_to_title)
    PokeAccess.speak(PokeAccess::TitleScreen.prompt(:fl_gameover), false)
  end
end
