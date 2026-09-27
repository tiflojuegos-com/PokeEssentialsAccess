# Voltseon's Pause Menu, a carousel of icons replacing the field menu (the focused one is only drawn larger): the
# focused entry's name is said once per move.
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

# The plugin is in this repo's plugins/manifest.rb, under the class only it defines (VoltseonsPauseMenu).
Suite.define("voltseon menu: the plugin is in the detection table, under the class only it defines") do
  root = File.expand_path("../../..", File.dirname(__FILE__))
  table = eval(File.read(File.join(root, "plugins", "manifest.rb")))
  eq "the probe is the menu's own class", table[:voltseon_pausemenu], "VoltseonsPauseMenu"
  truthy "and its reader is where the loader would look for it",
         File.file?(File.join(root, "plugins", "voltseon_pausemenu.rb"))
end

# The panels painted around the carousel (map name, date and time, Safari counts, new quests) are said once the menu
# opens, queued after the entry; the stand-in paints as the scene does, empty rows included.
class VoltseonPanelsScene
  attr_accessor :panel_rows
  def initialize(menu); @menu = menu; end

  def pbRefresh
    pbDrawTextPositions(nil, [["Ruta 5", 0, 12, 1, nil, nil, true]])
    pbDrawTextPositions(nil, (@panel_rows || []).map { |t| [t, 0, 12, 1, nil, nil] })
  end

  def pbStartScene
    pbRefresh
    PokeAccess::VoltseonMenu.read(@menu)
  end
end

Suite.define("voltseon menu: the panels it paints are said once it opens, after the entry") do
  saved = Object.const_defined?(:VoltseonsPauseMenu_Scene) ? VoltseonsPauseMenu_Scene : nil
  verbose = $VERBOSE
  begin
    Object.send(:remove_const, :VoltseonsPauseMenu_Scene) if saved
    Object.const_set(:VoltseonsPauseMenu_Scene, VoltseonPanelsScene)
    $VERBOSE = nil
    load File.expand_path("../../../plugins/voltseon_pausemenu.rb", File.dirname(__FILE__))
    $VERBOSE = verbose

    entry = Struct.new(:name)
    menu = Object.new
    menu.instance_variable_set(:@entries, [entry.new("Pokedex")])
    menu.instance_variable_set(:@currentSelection, 0)
    scene = VoltseonsPauseMenu_Scene.new(menu)
    scene.panel_rows = ["12 Sep 2026", "03:15 PM", "", "You have 1 new quest!"]

    SpeakCapture.clear
    scene.pbStartScene
    eq "the entry first, then the panels as painted, both queued", SpeakCapture.log,
       [["Pokedex", false], ["Ruta 5, 12 Sep 2026, 03:15 PM, You have 1 new quest!", false]]

    SpeakCapture.clear
    scene.pbRefresh
    silent "a later refresh, back from a submenu, says nothing of its own"
  ensure
    $VERBOSE = verbose
    Object.send(:remove_const, :VoltseonsPauseMenu_Scene)
    Object.const_set(:VoltseonsPauseMenu_Scene, saved) if saved
  end
end
