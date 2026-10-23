# Turning the gen-6 summary's pages: the opening waits behind what was being said, a turn interrupts, a redraw of the
# page on screen is quiet, and another member's page is read even when it reads the same, named first.
class SummaryPagesTest < PokeAccessTest
  T = PokeAccess::I18n
  FEMALE = "\xE2\x99\x80"
  # A move as the gen-6 moves page asks it.
  Move = Struct.new(:id, :name, :pp, :totalpp, :type)

  # Leaves no paint capture armed for the next test: drawPage arms the egg page's on every page and only page one takes it.
  def teardown
    PokeAccess::PaintCapture.arm(nil)
    super
  end

  test "opening reads the data sheet, queued behind what was being said" do
    pk = pika
    PokemonSummaryScene.new.pbStartScene([pk], 0)
    assert_equal [[PokeAccess::Info.summary_text(pk), false]], SpeakCapture.log
  end

  test "turning to another page reads it, interrupting" do
    pk = pika
    scene = opened(pk)
    scene.drawPage(4)
    assert_equal [[PokeAccess::Summary.moves_text(pk), true]], SpeakCapture.log
  end

  test "a redraw of the page on screen says nothing" do
    scene = opened(pika)
    scene.drawPage(4)
    SpeakCapture.clear
    scene.drawPage(4)
    assert_nothing_spoken
  end

  test "turning back to a page read before reads it again" do
    pk = pika
    scene = opened(pk)
    scene.drawPage(4)
    SpeakCapture.clear
    scene.drawPage(1)
    assert_equal [[PokeAccess::Info.summary_text(pk), true]], SpeakCapture.log
  end

  test "another member's page is read even when it reads the same, named first as the header shows it" do
    eevee = pika("Eevee", 5, 1)
    scene = opened(pika, eevee)
    scene.drawPage(4)
    SpeakCapture.clear
    scene.pokemon = eevee
    scene.drawPage(4)
    whose = T.t(:sum_whose, :name => "Eevee #{FEMALE}", :level => 5)
    assert_equal [["#{whose}. #{PokeAccess::Summary.moves_text(eevee)}", true]], SpeakCapture.log
  end

  test "the info key reads the member whose page is on screen" do
    eevee = pika("Eevee", 5, 1)
    scene = opened(pika, eevee)
    scene.pokemon = eevee
    scene.drawPage(4)
    assert_equal PokeAccess::Info.pokemon_info(eevee), PokeAccess::Info.info_text
  end

  test "a page that starts with the Pokemon is not named twice" do
    first = pika
    eevee = pika("Eevee", 5, 1)
    scene = opened(first, eevee)
    scene.pokemon = eevee
    scene.drawPage(4)
    SpeakCapture.clear
    scene.pokemon = first
    scene.drawPage(1)
    assert_equal [[PokeAccess::Info.summary_text(first), true]], SpeakCapture.log
  end

  test "a page something covered is read again when it closes, as a turn on the same Pokemon" do
    pk = pika
    scene = opened(pk)
    scene.drawPage(3)
    SpeakCapture.clear
    PokeAccess::Summary.forget_page(scene)
    scene.drawPage(3)
    assert_equal [[PokeAccess::SummaryGen6.stats_text(pk), true]], SpeakCapture.log
  end

  test "forgetting the page before any was read leaves the opening to wait" do
    pk = pika
    scene = PokemonSummaryScene.new
    PokeAccess::Summary.forget_page(scene)
    scene.pbStartScene([pk], 0)
    assert_equal [[PokeAccess::Info.summary_text(pk), false]], SpeakCapture.log
  end

  test "coming back from the move cursor or the ribbon grid reads the page again" do
    pk = pika
    scene = opened(pk)
    scene.drawPage(4)
    [:pbMoveSelection, :pbRibbonSelection].each do |loop_name|
      SpeakCapture.clear
      scene.send(loop_name)
      scene.drawPage(4)
      assert_equal [[PokeAccess::Summary.moves_text(pk), true]], SpeakCapture.log, "back from #{loop_name}"
    end
  end

  test "a page with no text or no Pokemon says nothing and leaves the opening still to come" do
    pk = pika
    scene = PokemonSummaryScene.new
    [[nil, "Datos."], [pk, nil], [pk, ""]].each { |who, text| PokeAccess::Summary.speak_page(scene, who, 1, text) }
    assert_nothing_spoken
    PokeAccess::Summary.speak_page(scene, pk, 1, "Datos.")
    assert_equal [["Datos.", false]], SpeakCapture.log, "the first page with words still opens, queued"
  end

  test "the moves page says each move's pp from brief and its type from medium" do
    tackle = T.t(:mv_pp, :pp => 30, :tot => 35)
    shock = T.t(:mv_pp, :pp => 20, :tot => 30)
    brief = T.t(:sm_moves, :list => "Placaje. #{tackle}, Impactrueno. #{shock}")
    typed = T.t(:sm_moves, :list => "Placaje. #{T.t(:mv_type, :t => 'TipoNORMAL')}. #{tackle}, " \
                                    "Impactrueno. #{T.t(:mv_type, :t => 'TipoELECTRIC')}. #{shock}")
    pk = pika
    assert_equal [brief, typed, typed], vb_levels { PokeAccess::Summary.moves_text(pk) }
  end

  private

  # A Pokemon knowing Placaje and Impactrueno, as the gen-6 moves page lists them.
  def pika(name = "Pika", level = 20, gender = 0)
    Poke.build(:name => name, :level => level, :gender => gender,
               :moves => [Move.new(33, "Placaje", 30, 35, :NORMAL), Move.new(84, "Impactrueno", 20, 30, :ELECTRIC)])
  end

  # A summary opened on the first of the party, its opening read and cleared.
  def opened(*party)
    scene = PokemonSummaryScene.new
    scene.pbStartScene(party, 0)
    SpeakCapture.clear
    scene
  end
end
