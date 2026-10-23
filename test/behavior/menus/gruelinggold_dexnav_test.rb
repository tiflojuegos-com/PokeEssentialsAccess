# Grueling Gold's New DexNav (games/gruelinggold/new_dexnav.rb): the area as its window paints it as the DexNav opens,
# then the species under the arrow, followed each frame of its loop, with its Pokedex mark and its place; and the panel
# a search leaves on the map, from main2 or from the quick search the overworld key runs.

# One of the DexNav's text windows: its text as set, and whether it was disposed.
class NewDexNavWindow
  attr_accessor :text, :gone
  def initialize(text); @text = text; end
  def disposed?; @gone ? true : false; end
end

# The DexNav, down to what its hooks see: main makes the name window and runs one frame for each place in frames
# (the arrow's @navChoice and the name the window takes there), then main2 when a search found one; quick_search
# leaves its panel in the class's own @sprites.
class NewDexNav
  NAMES = { :PIDGEY => "Pidgey", :RATTATA => "Rattata", :SENTRET => "Sentret" }

  def initialize(area, species, frames, found = false)
    @encarray = species
    @sprites = { "locwindow" => NewDexNavWindow.new(area) }
    @frames = frames
    @found = found
    @navChoice = 0
  end

  def main
    return :closed if @encarray.empty?
    @sprites["navMon"] = NewDexNavWindow.new("<c2=FFCADE00>#{NAMES[@encarray[0]]}</c2>")
    PokeAccess::Frame.run_pollers
    @frames.each do |i|
      @navChoice = i
      @sprites["navMon"].text = "<c2=FFCADE00>#{NAMES[@encarray[i]]}</c2>"
      PokeAccess::Frame.run_pollers
    end
    main2 if @found
    :closed
  end

  def main2
    @sprites["search"] = NewDexNavWindow.new("Sentret\n<c2=463F0000>Frisk</c2>\nBrave Bird")
  end

  def self.quick_search
    @sprites = { "search" => NewDexNavWindow.new("Pidgey\nKeen Eye\n-") }
  end
end

# The profile's reader, which the harness does not load, evaluated once over the stand-in.
new_dexnav_path = File.join(Harness::ROOT, "games", "gruelinggold", "new_dexnav.rb")
eval(Harness.source(new_dexnav_path), TOPLEVEL_BINDING, new_dexnav_path)

class GruelinggoldDexnavTest < PokeAccessTest
  AREA = "<ac><c2=43F022E8>Route 29</c2></ac><al><c2=FFCADE00>Total encounters for area: 3</c2></al>" \
         "<c2=63184210>-----------------------------------------</c2>"
  SPECIES = [:PIDGEY, :RATTATA, :SENTRET]

  test "the DexNav says the area and its count, then the first species with its place, both queued" do
    assert_equal :closed, NewDexNav.new(AREA, SPECIES, []).main
    assert_equal [["Route 29. Total encounters for area: 3", false],
                  [PokeAccess::Verbosity.list_entry("Pidgey", 1, 3), false]], SpeakCapture.log
  end

  test "the species under the arrow is said as it moves, cutting in, and not again while it stays" do
    NewDexNav.new(AREA, SPECIES, [2, 2, 1]).main
    assert_equal [[PokeAccess::Verbosity.list_entry("Sentret", 3, 3), true],
                  [PokeAccess::Verbosity.list_entry("Rattata", 2, 3), true]], SpeakCapture.log[2..-1]
  end

  test "a species is marked seen or caught as the Pokedex reading marks it" do
    with_dex([:PIDGEY, :RATTATA], [:PIDGEY]) { NewDexNav.new(AREA, SPECIES, [1, 2]).main }
    marks = ["Pidgey, #{t(:dex_caught)}", "Rattata, #{t(:dex_seen)}", "Sentret"]
    assert_equal marks.each_with_index.map { |m, i| PokeAccess::Verbosity.list_entry(m, i + 1, 3) }, SpeakCapture.lines[1..-1]
  end

  test "an area with no encounters says so and nothing more" do
    area = "<ac><c2=43F022E8>Route 29</c2></ac><al><c2=FFCADE00>This area has no encounters</c2></al>" \
           "<c2=63184210>-------</c2>"
    NewDexNav.new(area, [], []).main
    assert_equal ["Route 29. This area has no encounters"], SpeakCapture.lines
  end

  test "a search that finds one says the panel it leaves on the map, line by line, queued" do
    NewDexNav.new(AREA, SPECIES, [], true).main
    assert_equal ["Sentret. Frisk. Brave Bird", false], SpeakCapture.log.last
  end

  test "the quick search says its panel too, the dash of a species with no egg move left out" do
    NewDexNav.quick_search
    assert_equal [["Pidgey. Keen Eye", false]], SpeakCapture.log
  end

  test "once the DexNav has closed, its frames are no longer followed" do
    nav = NewDexNav.new(AREA, SPECIES, [])
    nav.main
    SpeakCapture.clear
    nav.instance_variable_set(:@navChoice, 2)
    PokeAccess::Frame.run_pollers
    assert_nothing_spoken
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # Runs the block with the player having seen and caught the species given, the player's own answers put back.
  def with_dex(seen, owned)
    $Trainer.define_singleton_method(:seen?) { |sp| seen.include?(sp) }
    $Trainer.define_singleton_method(:owned?) { |sp| owned.include?(sp) }
    yield
  ensure
    [:seen?, :owned?].each { |m| $Trainer.singleton_class.send(:remove_method, m) }
  end
end
