# The save screen's summary panel (locwindow): map name, player, play time, badges and dex counts,
# painted ONCE by pbStartScreen before the confirm question and never again. Nothing else reads it, so
# the player confirmed a save without hearing what state it captures. Read queued, so the panel follows
# the screen's own question instead of cutting it.
PokeAccess::Engine.scene_classes("PokemonSaveScene", "PokemonSave_Scene").each do |cn|
  PokeAccess::Hooks.after_hook(cn, :pbStartScreen, :optional => true) do |scene, _r, _a|
    win = PokeAccess.sprite(scene, "locwindow")
    t = PokeAccess.clean_fields((win.text rescue nil))
    next if t.empty?
    PokeAccess.speak(t, false)
  end
end
