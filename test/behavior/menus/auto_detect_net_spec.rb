# The generic auto-detect safety net, through the engine stub's real chain (SpriteWindow_Selectable ->
# SpriteWindow_SelectableEx -> Window_DrawableCommand): a window sets @index and updates, as the game does.

# The net binds SpriteWindow_Selectable#update (no engine defines Window_Selectable) and says a generic
# selectable's focused option from the window's own list.
Suite.define("menus: auto-detect net binds to SpriteWindow_Selectable and reads a generic selectable") do
  truthy "the real selectable class exists in the engine",
         !PokeAccess.const_at("SpriteWindow_Selectable").nil?
  truthy "the dead token resolves to nothing (the bug)",
         PokeAccess.const_at("Window_Selectable").nil?
  truthy "the net's update is actually wrapped (the saved-original alias exists, so it is not a no-op)",
         SpriteWindow_Selectable.private_method_defined?(:update__pa_orig_SpriteWindow_Selectable) ||
         SpriteWindow_Selectable.method_defined?(:update__pa_orig_SpriteWindow_Selectable)
  falsy "the net binding was not swallowed into Hooks.missing",
        PokeAccess::Hooks.missing.include?("SpriteWindow_Selectable#update")

  win = Class.new(SpriteWindow_Selectable) do
    def initialize(items); super(); @items = items; end
  end.new(["Correr", "Luchar", "Objetos"])
  prev = PokeAccess::Config.auto_detect
  PokeAccess::Config.auto_detect = true
  begin
    win.index = 1
    win.update
    spoke "the net speaks the focused generic option", /Luchar/
    SpeakCapture.clear
    win.index = 2
    win.update
    spoke "moving the cursor re-reads via the net", /Objetos/
    SpeakCapture.clear
    win.update
    silent "an unchanged index does not repeat (deduped per instance)"
  ensure
    PokeAccess::Config.auto_detect = prev
  end
end

# A Window_DrawableCommand is said once, by its own hook: the net also fires through super but skips that class.
Suite.define("menus: the net does not double-read a Window_DrawableCommand already covered by the sibling") do
  prev = PokeAccess::Config.auto_detect
  PokeAccess::Config.auto_detect = true
  begin
    cmd = Window_DrawableCommand.new(["Guardar", "Salir"])
    cmd.index = 0
    cmd.update
    spoke_once "a command-window entry is announced exactly once (no net + sibling overlap)", /Guardar/
  ensure
    PokeAccess::Config.auto_detect = prev
  end
end

# The net says nothing with auto_detect off, nor over non-text rows (pairs, ids).
Suite.define("menus: the net respects the auto_detect flag and stays silent on non-text entries") do
  win = Class.new(SpriteWindow_Selectable) do
    def initialize(items); super(); @items = items; end
  end.new(["Uno", "Dos"])
  prev = PokeAccess::Config.auto_detect

  PokeAccess::Config.auto_detect = false
  begin
    win.index = 1
    win.update
    silent "with auto_detect off the net says nothing"
  ensure
    PokeAccess::Config.auto_detect = prev
  end

  garbage = Class.new(SpriteWindow_Selectable) do
    def initialize(rows); super(); @items = rows; end
  end.new([[1, 2], [3, 4]])
  PokeAccess::Config.auto_detect = true
  begin
    garbage.index = 0
    garbage.update
    silent "the net stays silent over pair/id rows (never speaks garbage)"
  ensure
    PokeAccess::Config.auto_detect = prev
  end
end
