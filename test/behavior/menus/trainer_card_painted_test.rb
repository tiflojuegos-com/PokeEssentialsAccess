# The trainer card read as it paints itself (TrainerCard.read_face, gen-6 PokemonTrainerCardScene): its rows in reading
# order, then the badges its icons show (a region's own count, in a game of several); the fallback for a face of no words.
class TrainerCardPaintedTest < PokeAccessTest
  # The stock gen-6 card's rows, as it paints them, in reading order.
  ROWS = "Nombre Rojo N° ID 01234. Dinero $3000"
  # One badge icon, as the card draws it.
  BADGE = ["Graphics/Pictures/badges", 72, 310, 0, 0, 32, 32].freeze

  test "says its rows in reading order, then as many badges as icons it draws, queued as it opens" do
    { 0 => ROWS, 1 => "#{ROWS}. #{t(:tr_badges, :n => 1)}", 2 => "#{ROWS}. #{t(:tr_badges, :n => 2)}",
      8 => "#{ROWS}. #{t(:tr_badges, :n => 8)}" }.each do |badges, said|
      SpeakCapture.clear
      PokemonTrainerCardScene.new(badges).pbStartScene
      assert_equal [[said, false]], SpeakCapture.log, "#{badges} badges"
    end
  end

  test "a face drawn again on the open card interrupts, as a turn does" do
    card = PokemonTrainerCardScene.new(0)
    card.pbStartScene
    SpeakCapture.clear
    card.pbDrawTrainerCardFront
    assert_equal [[ROWS, true]], SpeakCapture.log
  end

  test "a face that paints no words says the summary it falls back on" do
    PokeAccess::TrainerCard.read_face(Object.new, true, lambda { "Resumen" }) { :painted }
    assert_equal [["Resumen", false]], SpeakCapture.log
  end

  test "a front that draws badge icons and no words says its fallback, not a lone badge count" do
    PokeAccess::TrainerCard.read_face(Object.new, true, lambda { "Resumen" }) { pbDrawImagePositions(nil, [BADGE]) }
    assert_equal [["Resumen", false]], SpeakCapture.log
  end

  test "a face that paints nothing and has no fallback says nothing" do
    PokeAccess::TrainerCard.read_face(Object.new, true) { :painted }
    assert_nothing_spoken
  end

  test "hands back what the face's paint returned" do
    assert_equal :painted, PokeAccess::TrainerCard.read_face(Object.new, true) { :painted }
  end

  test "names the key a face asks for as the player rebound it" do
    letters = PokeAccess::Config.key_hint_letters
    PokeAccess::Config.key_hint_letters = { "C" => :c }
    PokeAccess::Config.rebinds = { :c => 0x4B }
    PokeAccess::TrainerCard.read_face(Object.new, false) do
      pbDrawTextPositions(nil, [["Pulsa C para girar la tarjeta.", 16, 350]])
    end
    assert_equal [["Pulsa K para girar la tarjeta.", false]], SpeakCapture.log
  ensure
    PokeAccess::Config.key_hint_letters = letters
    PokeAccess::Config.rebinds = {}
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end
end
