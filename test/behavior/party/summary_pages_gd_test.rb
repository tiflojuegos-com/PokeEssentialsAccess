# Turning the modern summary's pages (drawPage): the opening waits, a turn interrupts, a redraw of the same page is
# quiet, and another member's page is read even when it reads the same, named first unless it is the info page.
class SummaryPagesGdTest < PokeAccessTest
  T = PokeAccess::I18n
  SGD = PokeAccess::SummaryGameData
  FEMALE = "\xE2\x99\x80"

  test "opening reads the data sheet, queued behind what was being said" do
    pika = Poke.build(:name => "Pika", :level => 20)
    PokemonSummary_Scene.new.pbStartScene([pika], 0)
    assert_equal [[SGD.info_text(pika), false]], SpeakCapture.log
  end

  test "turning to another page reads it, interrupting" do
    scene = opened(Poke.build(:name => "Pika", :level => 20))
    scene.drawPage(5)
    assert_equal [[T.t(:sm_ribbons_none), true]], SpeakCapture.log
  end

  test "a redraw of the page on screen says nothing" do
    scene = opened(Poke.build(:name => "Pika", :level => 20))
    scene.drawPage(5)
    SpeakCapture.clear
    scene.drawPage(5)
    assert_nothing_spoken
  end

  test "another member's page is read even when it reads the same, named first" do
    eevee = Poke.build(:name => "Eevee", :level => 5, :gender => 1)
    scene = opened(Poke.build(:name => "Pika", :level => 20), eevee)
    scene.drawPage(5)
    SpeakCapture.clear
    scene.pokemon = eevee
    scene.drawPage(5)
    assert_equal [["#{T.t(:sum_whose, :name => "Eevee #{FEMALE}", :level => 5)}. #{T.t(:sm_ribbons_none)}", true]],
                 SpeakCapture.log
  end

  test "the info key reads the member whose page is on screen" do
    eevee = Poke.build(:name => "Eevee", :level => 5, :gender => 1)
    scene = opened(Poke.build(:name => "Pika", :level => 20), eevee)
    scene.pokemon = eevee
    scene.drawPage(5)
    assert_equal PokeAccess::Info.pokemon_info(eevee), PokeAccess::Info.info_text
  end

  test "with a plugin's page order, the info page on another member goes unnamed and any other page is named" do
    eevee = Poke.build(:name => "Eevee", :level => 5, :gender => 1)
    named = "#{T.t(:sum_whose, :name => "Eevee #{FEMALE}", :level => 5)}. #{T.t(:sm_ribbons_none)}"
    { :page_info => SGD.info_text(eevee), :page_ribbons => named }.each do |id, want|
      scene = PokemonSummary_Scene.new
      scene.instance_variable_set(:@page_id, id)
      scene.pbStartScene([Poke.build(:name => "Pika", :level => 20), eevee], 0)
      SpeakCapture.clear
      scene.pokemon = eevee
      scene.drawPage(1)
      assert_equal [[want, true]], SpeakCapture.log, id.inspect
    end
  end

  private

  # A summary opened on the first of the party, its opening read and cleared.
  def opened(*party)
    scene = PokemonSummary_Scene.new
    scene.pbStartScene(party, 0)
    SpeakCapture.clear
    scene
  end
end
