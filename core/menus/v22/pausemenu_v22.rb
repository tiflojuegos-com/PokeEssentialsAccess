# v22 pause menu (UI::PauseMenuVisuals): its command window, possibly inactive, is claimed with the mod's own flag
# (never @ignore_input, the engine's) and read here per frame by index; @commands is [[ids], [names]].
if PokeAccess::Engine.has?("UI::PauseMenuVisuals")
  PokeAccess::Hooks.after_hook("UI::PauseMenuVisuals", :set_commands) do |vis, _ret, _args|
    PokeAccess.dedicate((vis.instance_variable_get(:@sprites)[:commands] rescue nil))
  end

  PokeAccess::Hooks.after_hook("UI::PauseMenuVisuals", :update_visuals) do |vis, _ret, _args|
    cmds = PokeAccess.ivar(vis, :@commands)
    win  = (vis.instance_variable_get(:@sprites)[:commands] rescue nil)
    next unless win && cmds && cmds[1]
    idx = (win.index rescue nil)
    next unless idx && idx >= 0
    next if idx == PokeAccess.ivar(vis, :@access_pause_idx)
    vis.instance_variable_set(:@access_pause_idx, idx)
    name = cmds[1][idx]
    PokeAccess.speak(name.to_s, true)
  end
end
