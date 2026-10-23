# The gen-6 egg page (the modern one is summary_egg_gd_test.rb): what it paints, never the species inside, read once
# through drawPageOne's hook or, where drawPage reaches the egg page alone (Awakening), through the egg page's own.
class SummaryEggTest < PokeAccessTest
  # What the stub's egg page paints, joined as the reader says it.
  PAINTED = "TRAINER MEMO, Item, Ninguno, Un Huevo misterioso recibido en Ciudad Verde. Parece que tardara mucho en eclosionar."
  # A Pokemon that answers only the modern engine's question, or only gen-6's.
  ModernEgg = Struct.new(:flag) { def egg?; flag; end }
  OldEgg = Struct.new(:flag) { def isEgg?; flag; end }

  # Starts each test with no paint capture armed (see disarm_capture).
  def setup
    super
    disarm_capture
  end

  test "an egg's page one reads what its page paints, never its species" do
    PokemonSummaryScene.new.drawPageOne(egg)
    assert_equal [[PAINTED, false]], SpeakCapture.log
  end

  test "the same egg page drawn again says nothing" do
    scene = PokemonSummaryScene.new
    pk = egg
    scene.drawPageOne(pk)
    SpeakCapture.clear
    scene.drawPageOne(pk)
    assert_nothing_spoken
  end

  test "a hatched Pokemon drawn after the egg gets its data sheet" do
    scene = PokemonSummaryScene.new
    scene.drawPageOne(egg)
    SpeakCapture.clear
    hatched = Poke.build(:name => "Chispa")
    scene.drawPageOne(hatched)
    assert_equal [[PokeAccess::Info.summary_text(hatched), true]], SpeakCapture.log
  end

  test "an egg page reached without drawPageOne is read from its own hook, the Pokemon the scene's" do
    scene = PokemonSummaryScene.new
    scene.pokemon = egg
    PokeAccess::PaintCapture.arm(:summary_egg)
    scene.drawPageOneEgg
    assert_equal [[PAINTED, false]], SpeakCapture.log
  end

  test "a page drawn before the egg's leaves nothing in it, and the egg is not named first" do
    scene = PokemonSummaryScene.new
    scene.pokemon = Poke.build(:name => "Chispa")
    scene.drawPage(4)
    pbDrawTextPositions(nil, [["MOVIMIENTOS", 0, 0]])
    scene.pokemon = egg
    SpeakCapture.clear
    scene.drawPage(1)
    assert_equal [[PAINTED, true]], SpeakCapture.log
  end

  test "a single-page summary leaves the egg to its own reader, its capture taken all the same" do
    was = PokeAccess::Summary.single_page
    PokeAccess::Summary.single_page = true
    PokemonSummaryScene.new.drawPageOne(egg)
    assert_nothing_spoken
    assert_equal false, PokeAccess::PaintCapture.armed?(:summary_egg), "the egg page's capture is not left armed"
  ensure
    PokeAccess::Summary.single_page = was
  end

  test "the page-one composer stands down for an egg, and only on page one" do
    sgd = PokeAccess::SummaryGameData
    pk = egg
    hatched = Poke.build(:name => "Chispa")
    assert_nil sgd.legacy_page_text(pk, 1), "the egg's page one is the egg reader's"
    assert_equal sgd.info_text(hatched), sgd.legacy_page_text(hatched, 1), "a hatched one's page one is its data sheet"
    assert_equal sgd.moves_text(pk), sgd.legacy_page_text(pk, 4), "an egg's moves page is still the moves page"
  end

  test "knows an egg under either engine's question, and nothing else as one" do
    raising = OldEgg.new(true)
    def raising.egg?; raise NoMethodError, "egg?"; end
    [[ModernEgg.new(true), true], [ModernEgg.new(false), false], [ModernEgg.new(1), true], [OldEgg.new(true), true],
     [OldEgg.new(false), false], [raising, true], [Poke.build, false]].each do |pk, want|
      assert_equal want, PokeAccess::Summary.egg?(pk), "for #{pk.inspect}"
    end
    assert_equal false, PokeAccess::Summary.egg?(nil), "nothing at all is no egg"
  end

  private

  # A Pokemon that is an egg, as the modern engine asks it.
  def egg
    pk = Poke.build(:name => "Huevo")
    def pk.egg?; true; end
    pk
  end

  # Leaves no paint capture armed, as at boot: drawPageOne keeps one already armed, so a capture another test left
  # (drawPage arms the egg page's on every page and only page one takes it) would reach these egg pages.
  def disarm_capture
    PokeAccess::PaintCapture.arm(nil)
  end
end
