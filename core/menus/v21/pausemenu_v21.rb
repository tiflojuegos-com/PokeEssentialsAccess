module PokeAccess
  # The GameData-era pause menu (PokemonPauseMenu_Scene#pbShowCommands): its "cmdwindow"'s focused command, polled each
  # frame by index (the method, else @index) through the generic list introspector. The window is claimed as the loop
  # starts: the loop updates it before the first pulse, where the generic reader would say the same row.
  PokeAccess::Hooks.before_hook("PokemonPauseMenu_Scene", :pbShowCommands) do |scene, _args|
    PokeAccess.dedicate(PokeAccess.sprite(scene, "cmdwindow"))
  end

  PauseMenuV21 = SceneWatcher.reader("PokemonPauseMenu_Scene", :pbShowCommands, :pausemenu_v21) do |s|
    w = PokeAccess.sprite(s, "cmdwindow")
    idx = w ? (w.index rescue (w.instance_variable_get(:@index) rescue nil)) : nil
    next nil if idx.nil? || idx < 0
    [idx, lambda { PokeAccess::Menus.generic_focus(w, idx) }]
  end
end
