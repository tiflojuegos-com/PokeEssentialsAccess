# The credits roll (Scene_Credits): the text the scene draws (get_text from v19, CREDIT at the top level or on the
# classic scene, a text per region in Infinite Fusion's Hoenn build) is read once, queued, on the roll's first frame,
# and the reading is stopped when the roll ends.

# The classic scene: main fills CREDIT's plugin placeholder in place, as the game's does, and runs the roll, calling
# update each frame.
class Scene_Credits
  CREDIT = "".dup
  def main
    CREDIT.gsub!(/\{INSERTS_PLUGIN_CREDITS_DO_NOT_REMOVE\}/, "Plugin X por:\nAna<s>Luis")
    3.times { update }
    :rolled
  end

  def update; end
end

# Infinite Fusion's Hoenn build has neither get_text nor CREDIT: its scene keeps one text per region, CREDIT_KANTO and
# CREDIT_HOENN, and main picks one by Settings::KANTO.
class IFHoennCreditsStub
  CREDIT_KANTO = "Fusion Kanto\n"
  CREDIT_HOENN = "<title>Fusion Hoenn\nAna<s>Luis\n"
end

# The reader's hooks were registered with the mod, before the scene above existed: the file's hook section, after its
# module, is evaluated again (as the harness serves it) so they bind to the scene.
credits = File.join(Harness::ROOT, "core", "menus", "credits.rb")
source = Harness.source(credits)
module_end = source.index("\n", source.index(/^end\s*$/)) + 1
eval(source[module_end..-1], TOPLEVEL_BINDING, credits, source[0, module_end].count("\n") + 1)

class CreditsTest < PokeAccessTest
  ROLL = "Mi Juego\n\n{INSERTS_PLUGIN_CREDITS_DO_NOT_REMOVE}\nGracias por jugar\n"

  test "reads the whole roll once, queued, on its first frame, from the text the scene finished" do
    roll(ROLL)
    assert_equal [["Mi Juego. Plugin X por: Ana, Luis. Gracias por jugar.", false]], SpeakCapture.log
  end

  test "leaves the roll's own return value" do
    assert_equal :rolled, roll(ROLL)
  end

  test "stops the reading when the roll is over" do
    assert_equal 1, stops_during { roll(ROLL) }
  end

  test "has nothing more to stop once the roll is over" do
    roll(ROLL)
    assert_equal 0, stops_during { PokeAccess::Credits.finish }
  end

  test "says nothing and stops nothing for a roll with no text" do
    stops = stops_during { roll("\n\n") }
    assert_nothing_spoken
    assert_equal 0, stops, "stops"
  end

  test "ends each line with a full stop unless it ends in its own punctuation" do
    scene = Class.new { def get_text; ["¡Gracias!", "¿Te gustó?", "Programación:", "Ana", "Fin."]; end }.new
    assert_equal "¡Gracias! ¿Te gustó? Programación: Ana. Fin.", PokeAccess::Credits.text(scene)
  end

  test "reads a v19 scene's get_text before any CREDIT, cleaned, its columns joined and its spacers dropped" do
    scene = Class.new { const_set(:CREDIT, "Clásico\n"); def get_text; ["<b>Moderno</b>", "", "Ana<s>Luis"]; end }.new
    assert_equal ["Moderno", "Ana, Luis"], PokeAccess::Credits.lines(scene)
  end

  test "reads a game's top-level CREDIT before the scene's own" do
    with_top_credit("Global\nAna<s>Luis\n") do
      scene = Class.new { const_set(:CREDIT, "Clásico\n") }.new
      assert_equal ["Global", "Ana, Luis"], PokeAccess::Credits.lines(scene)
    end
  end

  test "reads Infinite Fusion's Hoenn build from the text of the region being played" do
    { false => ["Fusion Hoenn", "Ana, Luis"], true => ["Fusion Kanto"] }.each do |kanto, want|
      with_kanto(kanto) { assert_equal want, PokeAccess::Credits.lines(IFHoennCreditsStub.new), "KANTO #{kanto}" }
    end
  end

  test "gives no lines for a scene with no text of any kind" do
    assert_equal [], PokeAccess::Credits.lines(Object.new)
  end

  private

  # Runs the classic scene's roll over the credit text given, its placeholder still to fill; main's return value.
  def roll(text)
    Scene_Credits::CREDIT.replace(text)
    Scene_Credits.new.main
  end

  # How many times the block stopped the speech, the real stop put back after.
  def stops_during
    stops = 0
    original = PokeAccess.method(:stop_speech)
    PokeAccess.define_singleton_method(:stop_speech) { stops += 1; true }
    yield
    stops
  ensure
    PokeAccess.define_singleton_method(:stop_speech, original)
  end

  # Runs the block with a top-level CREDIT holding text, as some games keep it, the one before (if any) put back.
  def with_top_credit(text)
    had = Object.const_defined?(:CREDIT, false)
    was = had ? Object::CREDIT : nil
    Object.send(:remove_const, :CREDIT) if had
    Object.const_set(:CREDIT, text)
    yield
  ensure
    Object.send(:remove_const, :CREDIT) if Object.const_defined?(:CREDIT, false)
    Object.const_set(:CREDIT, was) if had
  end

  # Runs the block with Settings::KANTO at value (Settings made if the engine has none), both put back after.
  def with_kanto(value)
    made = !Object.const_defined?(:Settings, false)
    Object.const_set(:Settings, Module.new) if made
    had = ::Settings.const_defined?(:KANTO, false)
    was = had ? ::Settings::KANTO : nil
    ::Settings.send(:remove_const, :KANTO) if had
    ::Settings.const_set(:KANTO, value)
    yield
  ensure
    ::Settings.send(:remove_const, :KANTO) if ::Settings.const_defined?(:KANTO, false)
    ::Settings.const_set(:KANTO, was) if had
    Object.send(:remove_const, :Settings) if made
  end
end
