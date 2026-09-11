# Voltseon's Pause Menu, a widely installed plugin that replaces the field menu with a carousel of icons.
# It rewrites the two entry points the vanilla pause menu goes through, so the core reader never ran and the
# whole menu was silent -- and there is nothing on screen to fall back on: the focused entry is marked ONLY
# by its icon being drawn larger, with no cursor, no highlight and no text unless the game turns menu names
# on. The entry's own name is what the reader says.
Suite.define("voltseon menu: the focused entry is spoken when the carousel moves, once per move") do
  entry = Class.new do
    attr_reader :name
    def initialize(n); @n = n; end
    def name; @n; end
  end
  menu = Object.new
  menu.instance_variable_set(:@entries, [entry.new("Pokedex"), entry.new("Pokemon"), entry.new("Mochila")])
  menu.instance_variable_set(:@currentSelection, 0)
  vm = PokeAccess::VoltseonMenu

  eq "the focused entry is the one the carousel centres", vm.focused_name(menu), "Pokedex"

  SpeakCapture.clear
  vm.read(menu)
  eq "arriving on it reads it", SpeakCapture.lines, ["Pokedex"]

  SpeakCapture.clear
  vm.read(menu)
  silent "and a refresh that moved nothing says nothing"

  menu.instance_variable_set(:@currentSelection, 2)
  SpeakCapture.clear
  vm.read(menu)
  eq "moving reads the new entry", SpeakCapture.lines, ["Mochila"]

  menu.instance_variable_set(:@currentSelection, 9)
  falsy "a selection past the entries is not an error", vm.focused_name(menu)
  SpeakCapture.clear
  vm.read(menu)
  silent "and says nothing"

  falsy "a menu with no entries at all is not an error", vm.focused_name(Object.new)
end

# The plugin is declared in the detection table, read from the file the loader reads, so a profile that
# ships it is told it exists and the diagnostic can name it even on a game we have no script dump for.
Suite.define("voltseon menu: the plugin is in the detection table, under the class only it defines") do
  root = File.expand_path("../../..", File.dirname(__FILE__))
  table = eval(File.read(File.join(root, "plugins", "manifest.rb")))
  eq "the probe is the menu's own class", table[:voltseon_pausemenu], "VoltseonsPauseMenu"
  truthy "and its reader is where the loader would look for it",
         File.file?(File.join(root, "plugins", "voltseon_pausemenu.rb"))
end
