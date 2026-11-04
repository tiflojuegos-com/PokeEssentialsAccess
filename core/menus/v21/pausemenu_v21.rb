module PokeAccess
  # Claim the existing command window before the loop updates it. Waiting for
  # the first Input pulse lets the generic reader announce the opening row too.
  PokeAccess::Hooks.before_hook("PokemonPauseMenu_Scene", :pbShowCommands) do |scene, _args|
    PokeAccess.dedicate(PokeAccess.sprite(scene, "cmdwindow"))
  end

  # The GameData-era pause menu (PokemonPauseMenu_Scene#pbShowCommands): its claimed "cmdwindow"'s focused command,
  # polled each frame by index (the method, else @index) through the generic list introspector.
  PauseMenuV21 = SceneWatcher.reader("PokemonPauseMenu_Scene", :pbShowCommands, :pausemenu_v21) do |s|
    w = PokeAccess.dedicate(PokeAccess.sprite(s, "cmdwindow"))
    idx = w ? (w.index rescue (w.instance_variable_get(:@index) rescue nil)) : nil
    next nil if idx.nil? || idx < 0
    [idx, lambda { PokeAccess::Menus.generic_focus(w, idx) }]
  end
end
