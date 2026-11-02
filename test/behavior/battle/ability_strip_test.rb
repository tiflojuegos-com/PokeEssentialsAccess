# The ability strip of the games that copied the Elite Battle System's (core/battle/scene_reader.rb): held once the
# strip has slid in, said ahead of the battle's next line unless that line names the ability, or on its own otherwise.
class AbilityStripTest < PokeAccessTest
  STRIP = PokeAccess::BattleScene
  Fighter = Struct.new(:pokemon, :ability)
  Mon = Struct.new(:name)
  PIKACHU = Fighter.new(Mon.new("Pikachu"), 9)

  test "nothing is said while the line is held" do
    STRIP.hold_strip(PIKACHU)
    assert_nothing_spoken
  end

  test "with no line after it, the strip is said queued, once" do
    STRIP.hold_strip(PIKACHU)
    2.times { STRIP.flush_strip }
    assert_equal [[line, false]], SpeakCapture.log
  end

  test "the strip waits through the frames of an animation for its line, which can drop it" do
    STRIP.hold_strip(PIKACHU)
    (STRIP::STRIP_WAIT - 1).times { STRIP.strip_frame }
    assert_nothing_spoken
    STRIP.flush_strip("¡Habilidad9 de Pikachu hizo llover!")
    assert_nothing_spoken
  end

  test "a second strip says the first, still held, and waits for its own line" do
    STRIP.hold_strip(PIKACHU)
    STRIP.hold_strip(Fighter.new(Mon.new("Eevee"), 8))
    assert_equal [[line, false]], SpeakCapture.log
  end

  test "with no line by the end of the wait, the strip is said queued, once" do
    STRIP.hold_strip(PIKACHU)
    (STRIP::STRIP_WAIT + 2).times { STRIP.strip_frame }
    assert_equal [[line, false]], SpeakCapture.log
  end

  test "a line that does not name the ability leaves the strip to be said" do
    STRIP.hold_strip(PIKACHU)
    STRIP.flush_strip("Pikachu cambió de forma.")
    assert_equal [[line, false]], SpeakCapture.log
  end

  test "a line that names the ability alone leaves the strip to say whose it is" do
    STRIP.hold_strip(PIKACHU)
    STRIP.flush_strip("Habilidad9 se activó.")
    assert_equal [[line, false]], SpeakCapture.log
  end

  test "a line that names the ability and the Pokemon drops the strip, even one with its colour tags" do
    ["Habilidad9 de Pikachu le curó el veneno.", "<c2=65467BFF>Habilidad9</c2> de Pikachu."].each do |text|
      STRIP.hold_strip(PIKACHU)
      STRIP.flush_strip(text)
      assert_nothing_spoken text
    end
  end

  test "a line after the strip was said finds nothing held" do
    STRIP.hold_strip(PIKACHU)
    STRIP.flush_strip
    SpeakCapture.clear
    STRIP.flush_strip("Pikachu cambió de forma.")
    assert_nothing_spoken
  end

  test "a battler with no Pokemon or one that tells no ability holds nothing" do
    [Fighter.new(nil, 9), Struct.new(:pokemon).new(Mon.new("Pikachu")), Object.new].each do |battler|
      STRIP.hold_strip(battler)
      STRIP.flush_strip
      assert_nothing_spoken battler.inspect
    end
  end

  test "resetting the caches drops the line held" do
    STRIP.hold_strip(PIKACHU)
    PokeAccess::Caches.reset_all
    STRIP.flush_strip
    assert_nothing_spoken
  end

  private

  def line
    PokeAccess::I18n.t(:bt_ability, :name => "Pikachu", :ability => "Habilidad9")
  end
end
