# The move relearner / egg-move readers mute the generic bare-name read of their command window so they can
# speak the full move detail instead. They set the mod's own @access_dedicated flag and never @ignore_input:
# on gen-6, SpriteWindow_Selectable#update gates its OWN navigation on that one, so muting through it freezes
# the player's cursor -- arrows stop moving through the list and nothing is read. menus.rb honours
# @access_dedicated to skip the window WITHOUT touching the engine's input. These suites prove the flag is
# what mutes the generic reads and that a window without it is still read.
Suite.define("menus: @access_dedicated mutes the generic command reader") do
  cmd = Window_DrawableCommand.new(["Placaje", "Ataque Rapido"])
  cmd.instance_variable_set(:@access_dedicated, true)
  cmd.index = 0
  cmd.update
  silent "a command window flagged @access_dedicated is not read by the generic hook"

  SpeakCapture.clear
  cmd.index = 1
  cmd.update
  silent "moving the cursor in a dedicated window is still not read generically"
end

# Control: the SAME window class WITHOUT the flag is announced by the sibling command hook, so the suite above
# proves the flag is doing the muting (not some other reason the window went quiet).
Suite.define("menus: a command window without the flag is still read") do
  cmd = Window_DrawableCommand.new(["Placaje", "Ataque Rapido"])
  cmd.index = 0
  cmd.update
  spoke_once "an un-flagged command window is announced by the generic hook", /Placaje/
end

# The auto-detect safety net honours @access_dedicated too (its own guard line), so a generic selectable a
# dedicated reader has claimed is not double-read through the net either.
Suite.define("menus: @access_dedicated also skips the auto-detect net") do
  win = Class.new(SpriteWindow_Selectable) do
    def initialize(items); super(); @items = items; end
  end.new(["Uno", "Dos"])
  win.instance_variable_set(:@access_dedicated, true)
  prev = PokeAccess::Config.auto_detect
  PokeAccess::Config.auto_detect = true
  begin
    win.index = 1
    win.update
    silent "the net skips a window claimed by a dedicated reader"
  ensure
    PokeAccess::Config.auto_detect = prev
  end
end
