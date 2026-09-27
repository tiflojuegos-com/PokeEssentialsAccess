module PokeAccess
  # The save screen's summary panel (locwindow: map, player, play time, badges, dex counts), painted once by
  # pbStartScreen and read queued.
  module SavePanel
    # Speaks the panel pbStartScreen has just built; a plugin overrides it where that panel can close unseen.
    def self.say(scene)
      win = PokeAccess.sprite(scene, "locwindow")
      t = PokeAccess.clean_fields((win.text rescue nil))
      PokeAccess.speak(t, false) unless t.empty?
    end
  end
end

PokeAccess::Engine.scene_classes("PokemonSaveScene", "PokemonSave_Scene").each do |cn|
  PokeAccess::Hooks.after_hook(cn, :pbStartScreen, :optional => true) do |scene, _r, _a|
    PokeAccess::SavePanel.say(scene)
  end
end
