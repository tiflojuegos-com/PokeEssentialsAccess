# Modern (v21+) pause menu trigger: reset the info key to read the trainer when the pause menu opens, so it
# does not read a stale :pokemon left over from the party screen or a previous battle. Spoken content is the
# agnostic PokeAccess::Party / Info; this only wires the modern scene. No-op on gen-6 (lacks this scene).
# hook_container: this body only STORES, it never speaks, and pbStartScene calls update_button -- whose hook is
# the one that announces. Guarded, that opening read is dropped as nested_other? and the screen opens
# in silence; the guard is only useful when the outer hook is itself the announcer.
PokeAccess::Hooks.after_hook("PokemonPauseMenu_Scene", :pbStartScene, :hook_container => true) do |_s, _r, _a|
  PokeAccess::Info.set_info(:trainer, nil)
end
