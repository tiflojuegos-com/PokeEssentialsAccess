# Modern pause menu: the info key reads the trainer once it opens. hook_container: this body only stores, and
# the update_button hook inside pbStartScene speaks (a guarded outer hook would drop it as nested_other?).
PokeAccess::Hooks.after_hook("PokemonPauseMenu_Scene", :pbStartScene, :hook_container => true) do |_s, _r, _a|
  PokeAccess::Info.set_info(:trainer, nil)
end
