# The BES custom trainer card (plugins/bes_trainer_card.rb, TrainerCard#dorso1 the front and #dorso2 the back): each face
# is read once from what it paints, however many frames it repaints on, with the stars or badges its sprites show, and
# turning the card reads the other face.

# The card as the script runs it, each face's loop cut down to the frames a test gives it: a frame pulses and then
# repaints the whole face, as the real loop does every frame, and the other face is called from inside this one.
class TrainerCard
  FRONT = [["Nombre:", 36, 66, 0], ["Dinero:", 36, 96, 0], ["Pokédex:", 36, 146, 0], ["Misiones:", 36, 182, 0],
           ["Tiempo:", 36, 242, 0], ["Derrotas:", 36, 290, 0], ["Victorias:", 36, 322, 0], ["ID: 12345", 348, 66, 0],
           ["Ayoub", 302, 66, 1], ["3000$", 302, 96, 1], ["12/30", 302, 146, 1], ["1/2", 302, 184, 1],
           ["00:07", 302, 242, 1], ["1", 270, 290, 1], ["4", 270, 322, 1], ["Medallas: Pulsar C", 468, 322, 1]].freeze
  BACK = [["Nº Victorias Alto Mando: 2", 70, 234, 0], ["Nº Curaciones CP: 9", 70, 264, 0]].freeze

  def initialize(turns = 0, frames = 3, front = FRONT)
    @turns = turns
    @frames = frames
    @front = front
  end

  def dorso1
    play(@front)
    turn(:dorso2)
    :front_closed
  end

  def dorso2
    play(BACK)
    turn(:dorso1)
    :back_closed
  end

  private

  def play(rows)
    @frames.times do
      PokeAccess::Frame.run_pollers
      pbDrawTextPositions(nil, rows)
    end
  end

  def turn(face)
    return if @turns <= 0
    @turns -= 1
    send(face)
  end
end

# The plugin's two hooks, which the harness's own load of the file left unbound as the class was not there yet; its
# per-frame poller, registered then, is the one that runs.
BES_CARD_HOOKS = Harness.source(File.join(Harness::ROOT, "plugins", "bes_trainer_card.rb"))
                        .scan(/^PokeAccess::Hooks\.around_hook\("TrainerCard".*?^end\n/m)
BES_CARD_HOOKS.each { |hook| eval(hook, TOPLEVEL_BINDING, "plugins/bes_trainer_card.rb") }

class BesTrainerCardTest < PokeAccessTest
  FRONT_TEXT = "Nombre: Ayoub, ID: 12345, Dinero: 3000$, Pokédex: 12/30, Misiones: 1/2, Tiempo: 00:07, Derrotas: 1, " \
               "Victorias: 4, Medallas: Pulsar C"
  BACK_TEXT = "Nº Victorias Alto Mando: 2, Nº Curaciones CP: 9"

  test "the plugin hooks both faces of the card" do
    chains = PokeAccess::Hooks.instance_variable_get(:@chains)
    assert_equal 2, BES_CARD_HOOKS.length
    assert_equal [true, true], ["TrainerCard#dorso1", "TrainerCard#dorso2"].map { |key| chains.key?(key) }
  end

  test "reads the front once as it paints, each label joined to its value, queued as the card opens" do
    TrainerCard.new.dorso1
    assert_equal [[FRONT_TEXT, false]], SpeakCapture.log
  end

  test "puts the stars the front lights ahead of what it paints" do
    $game_variables[18] = 3
    TrainerCard.new.dorso1
    assert_equal [["#{t(:stars_count, :n => 3)}. #{FRONT_TEXT}", false]], SpeakCapture.log
  end

  test "says the first star and the fifth, the most the card draws" do
    [1, 5].each do |n|
      SpeakCapture.clear
      $game_variables[18] = n
      TrainerCard.new.dorso1
      assert_equal ["#{t(:stars_count, :n => n)}. #{FRONT_TEXT}"], SpeakCapture.lines, "#{n} stars"
    end
  end

  test "says no stars for none, for a value the script lights none for, or for a variable it cannot read" do
    [0, 6, -1, nil, "tres"].each do |value|
      SpeakCapture.clear
      $game_variables[18] = value
      TrainerCard.new.dorso1
      assert_equal [FRONT_TEXT], SpeakCapture.lines, "variable #{value.inspect}"
    end
  end

  test "says no stars where the game's variables cannot be read" do
    was = $game_variables
    $game_variables = nil
    begin
      TrainerCard.new.dorso1
    ensure
      $game_variables = was
    end
    assert_equal [FRONT_TEXT], SpeakCapture.lines
  end

  test "reads the back with the badges its medals show ahead of what it paints" do
    with_badges(3) { TrainerCard.new.dorso2 }
    assert_equal [["#{t(:tr_badges, :n => 3)}. #{BACK_TEXT}", false]], SpeakCapture.log
  end

  test "counts the eight medals the card draws, however many badges the trainer keeps" do
    with_badges(10) { TrainerCard.new.dorso2 }
    assert_equal ["#{t(:tr_badges, :n => 8)}. #{BACK_TEXT}"], SpeakCapture.lines
  end

  test "says no badges as a count of none" do
    with_badges(0) { TrainerCard.new.dorso2 }
    assert_equal ["#{t(:tr_badges, :n => 0)}. #{BACK_TEXT}"], SpeakCapture.lines
  end

  test "reads what a face painted alone where the trainer cannot be asked" do
    was = $Trainer
    $Trainer = nil
    begin
      TrainerCard.new.dorso2
    ensure
      $Trainer = was
    end
    assert_equal [BACK_TEXT], SpeakCapture.lines
  end

  test "turning the card reads the other face, interrupting, and turning it back reads the front again" do
    with_badges(2) { TrainerCard.new(2).dorso1 }
    assert_equal [[FRONT_TEXT, false], ["#{t(:tr_badges, :n => 2)}. #{BACK_TEXT}", true], [FRONT_TEXT, true]],
                 SpeakCapture.log
  end

  test "a card opened again is queued again" do
    2.times { TrainerCard.new.dorso1 }
    assert_equal [[FRONT_TEXT, false], [FRONT_TEXT, false]], SpeakCapture.log
  end

  test "a face repainted on every frame is read once" do
    TrainerCard.new(0, 12).dorso1
    assert_equal [FRONT_TEXT], SpeakCapture.lines
  end

  test "a face closed before its paint is read says nothing, then or on the frames after" do
    TrainerCard.new(0, 1).dorso1
    PokeAccess::Frame.run_pollers
    assert_nothing_spoken
    refute PokeAccess::PaintCapture.armed?(PokeAccess::BesTrainerCard::TAG), "the capture is let go"
  end

  test "hands back what the game's own faces return" do
    assert_equal [:front_closed, :back_closed], [TrainerCard.new.dorso1, TrainerCard.new.dorso2]
  end

  test "a hint line the card paints is left out at brief, where hints are not said, and the rest stays" do
    hint = ["[C]: Girar la tarjeta", 36, 350, 0]
    said = vb_levels do
      SpeakCapture.clear
      TrainerCard.new(0, 3, TrainerCard::FRONT + [hint]).dorso1
      SpeakCapture.lines
    end
    assert_equal [[FRONT_TEXT], ["#{FRONT_TEXT}, [C]: Girar la tarjeta"], ["#{FRONT_TEXT}, [C]: Girar la tarjeta"]],
                 said
  end

  test "a hint the card paints names the key the player has bound, as the game's own hints do" do
    hint = ["Pulsa C para girar la tarjeta", 36, 350, 0]
    was = [PokeAccess::Config.rebinds, PokeAccess::Config.key_hint_letters]
    PokeAccess::Config.key_hint_letters = { "C" => :c }
    PokeAccess::Config.rebinds = { :c => 0x45 }
    begin
      TrainerCard.new(0, 3, TrainerCard::FRONT + [hint]).dorso1
    ensure
      PokeAccess::Config.rebinds, PokeAccess::Config.key_hint_letters = was
    end
    assert_equal ["#{FRONT_TEXT}, Pulsa E para girar la tarjeta"], SpeakCapture.lines
  end

  test "a line painted twice on purpose is said twice" do
    TrainerCard.new(0, 3, [["Igual", 36, 100, 0], ["Igual", 36, 150, 0]]).dorso1
    assert_equal ["Igual, Igual"], SpeakCapture.lines
  end

  test "text painted outside a card is not taken for one" do
    pbDrawTextPositions(nil, TrainerCard::FRONT)
    PokeAccess::Frame.run_pollers
    assert_nothing_spoken
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  def with_badges(count)
    was = $Trainer.badges
    $Trainer.badges = Array.new(count) { true } + Array.new([8 - count, 0].max) { false }
    yield
  ensure
    $Trainer.badges = was
  end
end
