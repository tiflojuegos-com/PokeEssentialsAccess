# Rejuvenation's Pokedex (games/rejuvenation/pokedex.rb): its list rows, whose fifth field is the base stats and the
# sixth the number, its header with the dex's counts, and the menu of regions it opens with once two dexes are open.
# The profile file is loaded once; the Pokedex and the player stand in for the suite.
module RejuvDexSpec
  # A Pokedex that has seen Bulbasaur in form 0 only and caught Squirtle.
  class Dex
    def seen?(species, form = nil)
      return [:SQUIRTLE, :BULBASAUR].include?(species) if form.nil?
      (species == :BULBASAUR && form == 0) || species == :SQUIRTLE
    end

    def owned?(species, _form = nil); species == :SQUIRTLE; end
  end

  Player = Struct.new(:pokedex)
  Scene = Struct.new(:searchResults)

  def self.load_profile
    return if @loaded
    load File.expand_path("../../../games/rejuvenation/pokedex.rb", File.dirname(__FILE__))
    @loaded = true
  end

  def self.row(species, name, num, form = 0)
    [species, name, 7, 69, [45, 49, 49, 65, 65, 45], num, nil, form]
  end

  # Runs the block with the stand-in player and the dex index given, putting back what was there.
  def self.with_player(index)
    had = $Trainer
    $Trainer = Player.new(Dex.new)
    $PokemonGlobal.define_singleton_method(:pokedexIndex) { index }
    yield
  ensure
    $Trainer = had
    (class << $PokemonGlobal; self; end).send(:remove_method, :pokedexIndex)
  end
end

class PokemonPokedexScene
  def pbRefreshMainMenu(index, *_opts); index; end
  def pbStartRegionScene; @activeScene = :region; end
  def pbUpdate(_sprites = nil); nil; end
end

Suite.define("rejuvenation dex: each list row says its number, its name and caught or seen, as drawItem paints it") do
  RejuvDexSpec.load_profile
  t = PokeAccess::I18n
  RejuvDexSpec.with_player(0) do
    win = Window_Pokedex.new([RejuvDexSpec.row(:BULBASAUR, "Bulbasaur", 1), RejuvDexSpec.row(:IVYSAUR, "Ivysaur", 2),
                              RejuvDexSpec.row(:SQUIRTLE, "Squirtle", 7)])
    win.instance_variable_set(:@scene, RejuvDexSpec::Scene.new(false))
    seen = PokeAccess::Menus.dex_row(1, :BULBASAUR, "Bulbasaur", true, false)
    eq "a seen species: its number (the sixth field, not the base stats) and name, and seen", PokeAccess::Menus.focused_text(win), seen
    match "which names it", seen, /Bulbasaur/
    win.index = 1
    eq "an unseen one: its number and unknown", PokeAccess::Menus.focused_text(win), "2, #{t.t(:dex_unknown)}"
    win.index = 2
    match "a caught one says caught", PokeAccess::Menus.focused_text(win), /Squirtle/

    alola = Window_Pokedex.new([RejuvDexSpec.row(:BULBASAUR, "Bulbasaur", 1, 1)])
    alola.instance_variable_set(:@scene, RejuvDexSpec::Scene.new(false))
    match "in the national dex a form counts as seen when the species is", PokeAccess::Menus.focused_text(alola), /Bulbasaur/
    alola.instance_variable_set(:@scene, RejuvDexSpec::Scene.new(true))
    eq "in a search only the row's own form counts", PokeAccess::Menus.focused_text(alola), "1, #{t.t(:dex_unknown)}"
  end
  RejuvDexSpec.with_player(2) do
    win = Window_Pokedex.new([RejuvDexSpec.row(:BULBASAUR, "Bulbasaur", 3, 1)])
    win.instance_variable_set(:@scene, RejuvDexSpec::Scene.new(false))
    eq "and in a regional dex too", PokeAccess::Menus.focused_text(win), "3, #{t.t(:dex_unknown)}"
  end
  eq "a gen-6 row keeps the core's reading", PokeAccess::Menus.dex_list_row(nil, [4, "Charmander", 6, 85, 4, false]),
     PokeAccess::Menus.dex_row(4, 4, "Charmander")
end

Suite.define("rejuvenation dex: the header says the dex and its counts when they change") do
  RejuvDexSpec.load_profile
  t = PokeAccess::I18n
  scene = PokemonPokedexScene.new
  wins = { "dexname" => FakeTextWin.new("<ac>Floria Dex</ac>"), "seen" => FakeTextWin.new("Seen:<r>12"),
           "owned" => FakeTextWin.new("Owned:<r>5") }
  scene.instance_variable_set(:@pokedexSprites, wins)
  SpeakCapture.clear
  scene.pbRefreshMainMenu(nil)
  eq "the name and the counts, queued", SpeakCapture.log,
     [[t.t(:dex_region_counts, :name => "Floria Dex", :seen => "12", :owned => "5"), false]]
  SpeakCapture.clear
  scene.pbRefreshMainMenu(false, :full => false)
  silent "a move down the list repaints nothing new and says nothing"
  wins["dexname"].text = "<ac>Search Results - 3</ac>"
  scene.pbRefreshMainMenu(0)
  eq "a search's results are said", SpeakCapture.lines,
     [t.t(:dex_region_counts, :name => "Search Results - 3", :seen => "12", :owned => "5")]
end

Suite.define("rejuvenation dex: the region menu says the region on open and on each turn") do
  RejuvDexSpec.load_profile
  t = PokeAccess::I18n
  scene = PokemonPokedexScene.new
  scene.instance_variable_set(:@list, { 0 => { :name => "National Dex", :seen => "30", :owned => "10", :total => 400 },
                                        1 => { :name => "Floria Dex", :seen => "12", :owned => "5", :total => 150 } })
  scene.instance_variable_set(:@regionMenuIndex, 1)
  floria = t.t(:dex_region_counts_tot, :name => "Floria Dex", :seen => "12", :owned => "5", :tot => 150)
  SpeakCapture.clear
  scene.pbStartRegionScene
  eq "the region it opens on, with its counts, queued", SpeakCapture.log, [[floria, false]]
  SpeakCapture.clear
  scene.pbUpdate(nil)
  silent "nothing again while it stays"
  scene.instance_variable_set(:@regionMenuIndex, 0)
  scene.pbUpdate(nil)
  eq "a turn cuts in with the next region", SpeakCapture.log,
     [[t.t(:dex_region_counts_tot, :name => "National Dex", :seen => "30", :owned => "10", :tot => 400), true]]
  SpeakCapture.clear
  scene.instance_variable_set(:@activeScene, :pokedex)
  scene.instance_variable_set(:@regionMenuIndex, 1)
  scene.pbUpdate(nil)
  silent "once the list is up the menu is not read"
  scene.pbStartRegionScene
  eq "back on the menu it is said again", SpeakCapture.lines, [floria]
end
