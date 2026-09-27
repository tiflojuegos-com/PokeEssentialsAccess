# @access_dedicated mutes the generic reads of a window a dedicated reader claims; never @ignore_input, which gen-6's
# SpriteWindow_Selectable#update also reads to freeze the cursor.
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

# The control: the same window class without the flag is read.
Suite.define("menus: a command window without the flag is still read") do
  cmd = Window_DrawableCommand.new(["Placaje", "Ataque Rapido"])
  cmd.index = 0
  cmd.update
  spoke_once "an un-flagged command window is announced by the generic hook", /Placaje/
end

# The auto-detect net skips a window flagged @access_dedicated too.
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
