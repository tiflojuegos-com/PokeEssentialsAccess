# Mr. Gela's HGSS card (plugins/hgss_trainer_card.rb over core's TrainerCard.read_face): each face as painted, the front
# queued and a turn interrupting, its badge icons adding no count, and the front led by the stars its picture shows.
class TrainerCardHgssGdTest < PokeAccessTest
  # The card's faces as the stub card paints them, in reading order.
  FRONT = "NOMBRE Rojo. MEDALLAS 2. Pulsa [D] para girar la tarjeta."
  BACK = "DEBUT HALL DE LA FAMA. Combates Online 4"

  test "says the front as painted, queued, as the card opens" do
    PokemonTrainerCard_Scene.new.pbStartScene
    assert_equal [[FRONT, false]], SpeakCapture.log
  end

  test "turning the card says the back as painted, interrupting, its badge icons adding no count" do
    card = PokemonTrainerCard_Scene.new
    card.pbStartScene
    SpeakCapture.clear
    card.pbDrawTrainerCardBack
    assert_equal [[BACK, true]], SpeakCapture.log
  end

  test "turning back to the front interrupts too" do
    card = PokemonTrainerCard_Scene.new
    card.pbStartScene
    card.pbDrawTrainerCardBack
    SpeakCapture.clear
    card.pbDrawTrainerCardFront
    assert_equal [[FRONT, true]], SpeakCapture.log
  end

  test "with hints left out, the front drops its key line" do
    PokeAccess::Config.verbosity = :brief
    PokemonTrainerCard_Scene.new.pbStartScene
    assert_equal [["NOMBRE Rojo. MEDALLAS 2", false]], SpeakCapture.log
  end

  test "starts the front with the stars the card's picture shows" do
    with_stars(2) { PokemonTrainerCard_Scene.new.pbStartScene }
    assert_equal [["#{PokeAccess::I18n.t(:stars_count, :n => 2)}. #{FRONT}", false]], SpeakCapture.log
  end

  test "the back, whose picture shows the stars too, says only what it paints" do
    with_stars(2) do
      card = PokemonTrainerCard_Scene.new
      card.pbStartScene
      SpeakCapture.clear
      card.pbDrawTrainerCardBack
    end
    assert_equal [[BACK, true]], SpeakCapture.log
  end

  test "notes the stars only into the face being read" do
    noted = nil
    with_stars(2) do
      PokeAccess::PaintCapture.arm(:another_reader)
      begin
        PokeAccess::HGSSTrainerCard.note_stars
      ensure
        noted = PokeAccess::PaintCapture.take(:another_reader)
      end
    end
    assert_equal [], noted, "a capture armed by another reader gets no stars"
  end

  private

  # Runs the block with the player holding n stars, as the card's picture (card_N) shows them; put back as it was after.
  def with_stars(n)
    meta = $player.singleton_class
    had = meta.method_defined?(:stars, false) ? meta.instance_method(:stars) : nil
    meta.send(:define_method, :stars) { n }
    yield
  ensure
    if had
      meta.send(:define_method, :stars, had)
    else
      meta.send(:remove_method, :stars)
    end
  end
end
