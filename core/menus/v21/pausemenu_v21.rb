module PokeAccess
  # GameData-era Essentials field/pause menu (PokemonPauseMenu_Scene#pbShowCommands): reads the highlighted
  # command of its Window_CommandPokemon while the menu runs, polled each frame via SceneWatcher.reader.
  # Uses the index METHOD (not the @index ivar, whose name varies) and the generic list introspector
  # (handles @commands/@list/... and string/symbol/object entries), so it reads command windows regardless
  # of how a fork (Sky, Map Zoom...) stores them. No-op on gen-6, which lacks this scene.
  PauseMenuV21 = SceneWatcher.reader("PokemonPauseMenu_Scene", :pbShowCommands, :pausemenu_v21) do |s|
    w = PokeAccess.sprite(s, "cmdwindow")
    idx = w ? (w.index rescue (w.instance_variable_get(:@index) rescue nil)) : nil
    (idx.nil? || idx < 0) ? nil : [idx, (PokeAccess::Menus.generic_focus(w, idx) rescue nil)]
  end
end
