# Sevii's new game (games/sevii/intro.rb) over stand-ins shaped as its scripts: the version, player and starter
# pickers, @option into @textOptions, and the grid of twenty Pokemon, @SelNo over its icons. Their loops are left
# out: a test runs main for the opening and update for each frame.

# The version picker; main is its loop, update one frame of it.
class VersionSelection
  def initialize
    @options = ["HG", "SS"]
    @textOptions = ["Pokémon HeartGold Version", "Pokémon SoulSilver Version"]
    @option = 0
  end
  def main; :looped; end
  def update; :frame; end
  def createTextBox; :box; end
end

# The player picker, as the version one.
class GenderSel
  def initialize
    @options = ["male", "female"]
    @textOptions = ["Male Player", "Female Player"]
    @option = 0
  end
  def main; :looped; end
  def update; :frame; end
  def createTextBox; :box; end
end

# The starter picker, with the question it writes on its own message box before its Yes and No.
class StarterSel
  def initialize
    @options = ["mon1", "mon2", "mon3"]
    @textOptions = ["Chikorita, the Leaf Pokémon", "Cyndaquil, the Fire Mouse Pokémon", "Totodile, the Big Jaw Pokémon"]
    @option = 0
  end
  def main; :looped; end
  def update; :frame; end
  attr_writer :answer
  def pbDisplayConfirm(_text); @answer.nil? ? true : @answer; end
end

SeviiPoolMon = Struct.new(:name)

# One of the grid's cells (PokeSelectDisplay): its Pokemon, and whether it is taken.
class SeviiPoolCell
  attr_accessor :selected
  attr_reader :pokemon
  def initialize(name)
    @pokemon = SeviiPoolMon.new(name)
    @selected = false
  end
end

# The grid of twenty: @SelNo is the cell under the cursor, @selected the Pokemon taken.
class PokeSelect
  def initialize(names)
    @sprites = {}
    names.each_with_index { |n, i| @sprites["pokemon#{i}"] = SeviiPoolCell.new(n) }
    @selected = []
    @SelNo = 0
  end
  def update; :frame; end
  def pbDisplayConfirm(_text); true; end
end

class SeviiIntroTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "sevii", "intro.rb")
  POOL = %w[Pidgeotto Pikachu Nidoking Nidoqueen Aerodactyl Crobat Ampharos Scizor Houndoom Pupitar
            Shiftry Lairon Manectric Vibrava Metang Ambipom Lopunny Croagunk Weavile Mamoswine]

  test "the version picker says what it asks for and how to move, then the version shown, queued, as it opens" do
    open_picker(VersionSelection.new)
    title = PokeAccess::Verbosity.with_hint(t(:sv_version_title), t(:gsel_help_hint))
    assert_equal [[title, true], ["Pokémon HeartGold Version", false]], SpeakCapture.log
  end

  test "the version picker says the other version as the arrows reach it, cutting in, and nothing while it stays" do
    s = open_picker(VersionSelection.new)
    s.instance_variable_set(:@option, 1)
    s.update
    s.update
    assert_equal ["Pokémon SoulSilver Version", true], SpeakCapture.log.last
    assert_equal 3, SpeakCapture.log.length
  end

  test "the player picker opens on choosing a look, then the player shown" do
    open_picker(GenderSel.new)
    title = PokeAccess::Verbosity.with_hint(t(:gsel_help), t(:gsel_help_hint))
    assert_equal [[title, true], ["Male Player", false]], SpeakCapture.log
  end

  test "the starter picker says each starter as its own box writes it, and the question its Yes and No answer" do
    s = open_picker(StarterSel.new)
    s.instance_variable_set(:@option, 2)
    s.update
    assert s.pbDisplayConfirm("Are you sure you want to choose Totodile, the Big Jaw Pokémon?"), "the game's answer"
    assert_equal ["Totodile, the Big Jaw Pokémon", true], SpeakCapture.log[2]
    assert_equal ["Are you sure you want to choose Totodile, the Big Jaw Pokémon?", false], SpeakCapture.log.last
  end

  test "a No to the version's question, which rebuilds the picker's text box, says the version shown again, queued" do
    s = open_picker(VersionSelection.new)
    SpeakCapture.clear
    s.update
    s.createTextBox
    s.update
    assert_equal [["Pokémon HeartGold Version", false]], SpeakCapture.log
  end

  test "a No to the starter's question says the starter shown again after the question; a Yes leaves it said" do
    s = open_picker(StarterSel.new)
    SpeakCapture.clear
    s.answer = false
    refute s.pbDisplayConfirm("Are you sure you want to choose Chikorita, the Leaf Pokémon?"), "the game's answer"
    s.update
    s.answer = true
    s.pbDisplayConfirm("Are you sure you want to choose Chikorita, the Leaf Pokémon?")
    s.update
    question = "Are you sure you want to choose Chikorita, the Leaf Pokémon?"
    assert_equal [[question, false], ["Chikorita, the Leaf Pokémon", false]], SpeakCapture.log
  end

  test "the grid opens on its size and how to use it, then the first cell with its place" do
    open_pool
    grid = PokeAccess::Verbosity.with_hint(t(:sv_pool_grid, :cols => 5, :rows => 4), t(:sv_pool_hint))
    first = PokeAccess.sentences([grid, t(:sv_slot, :name => "Pidgeotto", :row => 1, :col => 1)])
    assert_equal [[first, false]], SpeakCapture.log
  end

  test "the grid says the cell the cursor reaches, by row and column, cutting in" do
    s = open_pool
    move(s, 7)
    assert_equal [t(:sv_slot, :name => "Scizor", :row => 2, :col => 3), true], SpeakCapture.log.last
  end

  test "taking a Pokemon says its cell again as taken, with how many are taken" do
    s = open_pool
    move(s, 1)
    take(s)
    line = PokeAccess.sentences([t(:sv_pool_taken, :name => "Pikachu", :row => 1, :col => 2),
                                 t(:sv_pool_count, :n => 1, :max => 5)])
    assert_equal [line, true], SpeakCapture.log.last
  end

  test "a taken Pokemon is said as taken when the cursor comes back to it, without the count" do
    s = open_pool
    move(s, 1)
    take(s)
    move(s, 2)
    move(s, 1)
    assert_equal [t(:sv_pool_taken, :name => "Pikachu", :row => 1, :col => 2), true], SpeakCapture.log.last
  end

  test "the question on a cell is said queued, the cell not said again" do
    s = open_pool
    move(s, 3)
    SpeakCapture.clear
    assert s.pbDisplayConfirm("Would you like to take Nidoqueen?"), "the game's answer"
    s.update
    assert_equal [["Would you like to take Nidoqueen?", false]], SpeakCapture.log
  end

  test "the fifth Pokemon taken is said with the count before the question that follows at once, and only there" do
    s = open_pool
    [0, 1, 2, 3].each { |i| move(s, i); take(s) }
    move(s, 4)
    cell = s.instance_variable_get(:@sprites)["pokemon4"]
    cell.selected = true
    s.instance_variable_get(:@selected).push(cell.pokemon)
    SpeakCapture.clear
    s.pbDisplayConfirm("Are you satisfied with these choices?")
    s.update
    line = PokeAccess.sentences([t(:sv_pool_taken, :name => "Aerodactyl", :row => 1, :col => 5),
                                 t(:sv_pool_count, :n => 5, :max => 5)])
    assert_equal [[line, true], ["Are you satisfied with these choices?", false]], SpeakCapture.log
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  def open_picker(scene)
    self.class.bind
    scene.main
    scene.update
    scene
  end

  def open_pool
    self.class.bind
    s = PokeSelect.new(POOL)
    s.update
    s
  end

  def move(scene, idx)
    scene.instance_variable_set(:@SelNo, idx)
    scene.update
  end

  # Takes the Pokemon under the cursor as the game does after a Yes, then runs the next frame.
  def take(scene)
    cell = scene.instance_variable_get(:@sprites)["pokemon#{scene.instance_variable_get(:@SelNo)}"]
    cell.selected = true
    scene.instance_variable_get(:@selected).push(cell.pokemon)
    scene.update
  end

  # Evaluates intro.rb once, the profile list put back as it was.
  def self.bind
    return if @bound
    @bound = true
    profiles = PokeAccess::Game.profiles.dup
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
    PokeAccess::Game.instance_variable_set(:@profiles, profiles)
    PokeAccess::Game.instance_variable_set(:@profile_name, nil)
  end
end
