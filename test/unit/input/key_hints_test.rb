# A key hint said as the player has the keys now: the letter of a button rebound with the mod's remap becomes the
# bound key and only the key token changes; with hints left out, the gate drops the hint lines and sentences; the mod's
# own title prompt and help texts name the keys likewise; and Royal's letters are the keys its F1 menu paints.
class InputKeyHintsTest < PokeAccessTest
  KeyHints = PokeAccess::KeyHints
  RGSS = PokeAccess::KeyHints::RGSS_LETTERS
  J = 0x4A
  K = 0x4B
  ROYAL_KEYS = File.expand_path("../../../games/royal/key_hints.rb", File.dirname(__FILE__))

  # The keys Royal's F1 menu gives the standard buttons while the player keeps RPG Maker's.
  ROYAL_DEFAULTS = { :ACTION => "Z", :BACK => "X", :USE => "C", :JUMPUP => "A", :JUMPDOWN => "S", :SPECIAL => "D",
                     :AUX1 => "Q", :AUX2 => "W" }.freeze

  test "with nothing rebound, a hint is left as painted" do
    assert_equal "[A] Curar", KeyHints.localize("[A] Curar", RGSS)
  end

  test "only the key token of a rebound button changes" do
    PokeAccess::Config.rebinds = { :x => J, :c => K }
    [["[A] Curar", "[J] Curar", "a bracketed key"],
     ["[D] Brújula", "[D] Brújula", "a button not rebound keeps its letter"],
     ["C/X: Salir", "K/X: Salir", "a key that labels a line, one of two"],
     ["[A]/[S]: Desplazarse", "[J]/[S]: Desplazarse", "two bracketed keys"],
     ["Pulsa C para acceder", "Pulsa C para acceder", "a sentence, unless asked to read sentences"],
     ["Hora: 12:30", "Hora: 12:30", "a colon after a word that is no key"]].each do |painted, said, what|
      assert_equal said, KeyHints.localize(painted, RGSS), what
    end
  end

  test "a letter the table leaves out is never a key" do
    PokeAccess::Config.rebinds = { :x => J, :c => K }
    assert_equal "[X] Eventos", KeyHints.localize("[X] Eventos", { "A" => :x })
  end

  test "asked to read sentences, the key a verb or 'la tecla' asks for becomes the bound one" do
    PokeAccess::Config.rebinds = { :x => J, :c => K }
    cases = [["Pulsa C para acceder", "Pulsa K para acceder", "after a verb"],
             ["Cambia de modo con la tecla C.", "Cambia de modo con la tecla K.", "after 'la tecla'"],
             ["Press Cancel when ready.", "Press Cancel when ready.", "a button's name is no letter"]]
    cases.each { |painted, said, what| assert_equal said, KeyHints.localize(painted, RGSS, true), what }
  end

  test "a key asked for is swapped once, though two buttons trade their letters, in each language" do
    PokeAccess::Config.rebinds = { :a => 0x58, :b => 0x5A }
    [["Pulsa la tecla Z para confirmar.", "Pulsa la tecla X para confirmar."],
     ["Press the key Z.", "Press the key X."],
     ["Appuie sur la touche Z.", "Appuie sur la touche X."]].each do |painted, said|
      assert_equal said, KeyHints.localize(painted, RGSS, true), "for #{painted.inspect}"
    end
  end

  test "a missing text stays missing" do
    PokeAccess::Config.rebinds = { :x => J }
    assert_nil KeyHints.localize(nil, RGSS)
  end

  test "a game whose profile lists no letters keeps its hints as painted" do
    PokeAccess::Config.rebinds = { :x => J }
    got = [KeyHints.localize("[A] Curar", {}), with_letters(nil) { KeyHints.localize("[A] Curar") }]
    assert_equal ["[A] Curar", "[A] Curar"], got
  end

  test "the profile's table is the letters a hint is read by" do
    PokeAccess::Config.rebinds = { :x => J }
    assert_equal "[J] Vial", with_letters({ "V" => :x }) { KeyHints.localize("[V] Vial") }
  end

  test "the key said for an action is the bound one, else the game's" do
    PokeAccess::Config.rebinds = { :c => K }
    assert_equal ["K", "D"], [KeyHints.key(:c, "C"), KeyHints.key(:z, "D")]
  end

  test "hints are said from the medium verbosity up" do
    lines = ["Medallas: 3", "[D] Radar"]
    assert_equal [["Medallas: 3"], lines, lines], vb_levels { KeyHints.gate(lines) }
  end

  test "without hints, the gate drops hint lines but keeps a count, and takes a dropped hint's label along" do
    PokeAccess::Config.verbosity = :brief
    [[["Pulsa C para acceder"], [], "a hint a verb asks for"],
     [["[D] Radar"], [], "a bracketed hint"],
     [["[A] Vial (2/3)"], ["Vial (2/3)"], "a hint with a count keeps the count"],
     [["LISTA DE TARJETAS:", "Pulsa C para acceder"], [], "the label above a dropped hint goes with it"],
     [["LISTA DE TARJETAS:", "[A] Vial (2/3)"], ["LISTA DE TARJETAS:", "Vial (2/3)"], "and stays above a count"],
     [["Medallas: 3", "[D] Radar"], ["Medallas: 3"], "a line with a figure is no label"]].each do |lines, kept, what|
      assert_equal kept, KeyHints.gate(lines), what
    end
  end

  test "with hints said, a window's hint sentence stays" do
    text = "Peso: 6.9 kg. Press Enter for more details."
    assert_equal text, KeyHints.gate_sentences(text)
  end

  test "without hints, a window's hint sentence goes and a figure stays whole" do
    PokeAccess::Config.verbosity = :brief
    assert_equal "Peso: 6.9 kg.", KeyHints.gate_sentences("Peso: 6.9 kg. Press Enter for more details.")
  end

  test "without hints, a text with no hint sentence is left as it is, line breaks and all" do
    PokeAccess::Config.verbosity = :brief
    ["Nv. 5, 3.5%", "Peso: 6.9 kg.\nAltura: 1.1 m."].each do |text|
      assert_equal text, KeyHints.gate_sentences(text), "for #{text.inspect}"
    end
  end

  test "without hints, a painted capture said whole leaves its key lines out" do
    PokeAccess::Config.verbosity = :brief
    capture = PokeAccess::PaintCapture
    capture.arm(:kh_test)
    capture.note("Tarjeta de Brock")
    capture.note("[C]: Leer la descripción")
    SpeakCapture.clear
    capture.flush_pending(:kh_test, true)
    assert_equal [["Tarjeta de Brock", true]], SpeakCapture.log
  ensure
    PokeAccess::PaintCapture.take(:kh_test)
  end

  test "the title's prompt asks for the key bound to confirm" do
    PokeAccess::Config.rebinds = { :c => K }
    assert_equal "#{t(:title_screen)}. #{t(:title_press, :key => "K")}", PokeAccess::TitleScreen.prompt
  end

  test "with nothing rebound, the title's prompt asks for Enter" do
    assert_equal "#{t(:title_screen)}. #{t(:title_press, :key => t(:key_enter))}", PokeAccess::TitleScreen.prompt
  end

  test "another picture that waits for the key says its own text before the prompt" do
    want = "#{t(:rcr_notice)}. #{t(:title_press, :key => t(:key_enter))}"
    assert_equal want, PokeAccess::TitleScreen.prompt(:rcr_notice)
  end

  test "without hints, the title's prompt is the screen alone" do
    PokeAccess::Config.verbosity = :brief
    assert_equal t(:title_screen), PokeAccess::TitleScreen.prompt
  end

  test "the help texts name the mod's keys as they are bound now, or unassigned" do
    PokeAccess::Config.keys[:field] = 0x42
    vars = PokeAccess::ConfigMenu.key_vars
    assert_equal ["B", t(:key_control), t(:rmp_unassigned)], [vars[:key_field], vars[:key_ctrl], vars[:key_verbosity]]
  end

  test "the glossary's help names the marker key where the player put it" do
    PokeAccess::Config.keys[:field] = 0x42
    said = help_on_row(:sounds) { |item| item[:kind] == :sound && item[:entry].id == :mark }
    assert_equal [[t(:snd_mark_help, :key_ctrl => t(:key_control), :key_field => "B"), true]], said
  end

  test "the target order's help names the previous and next target keys as they are bound now" do
    PokeAccess::Config.keys[:prev] = 0x55
    said = help_on_row(:pathfinder) { |item| item[:row] && item[:row].key == :target_order }
    assert_equal [[t(:help_target_order, :key_prev => "U", :key_next => "L"), true]], said
  end

  test "Royal's letters are RPG Maker's while its F1 menu keeps them" do
    load_royal_keys
    assert_equal RGSS, with_keybinding_reader(ROYAL_DEFAULTS) { PokeAccess::RoyalKeys.letters }
  end

  test "without Royal's key reader, the hints go by the profile's table" do
    load_royal_keys
    assert_equal PokeAccess::Config.key_hint_letters, KeyHints.table
  end

  test "a key Royal's F1 moved is read as the button it has there, which a rebind of that button replaces" do
    load_royal_keys
    got = with_keybinding_reader(ROYAL_DEFAULTS.merge(:SPECIAL => "F", :JUMPUP => "D")) do
      PokeAccess::Config.rebinds = { :z => K }
      moved = [KeyHints.localize("[F] Brújula"), KeyHints.localize("[D] Curar")]
      PokeAccess::Config.rebinds = { :x => J }
      moved.push(KeyHints.localize("[D] Curar"))
    end
    assert_equal ["[K] Brújula", "[D] Curar", "[J] Curar"], got
  end

  test "an unbound button and a blank name are no letters, and a key two buttons share stands for the first" do
    load_royal_keys
    got = with_keybinding_reader(ROYAL_DEFAULTS.merge(:USE => "Z", :AUX1 => "", :AUX2 => "?")) do
      PokeAccess::RoyalKeys.letters
    end
    assert_equal({ "Z" => :a, "X" => :b, "A" => :x, "S" => :y, "D" => :z }, got)
  end

  private

  # A mod text in the language under test.
  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # The block's value with the profile's letter table set to letters, the table put back after.
  def with_letters(letters)
    was = PokeAccess::Config.key_hint_letters
    PokeAccess::Config.key_hint_letters = letters
    yield
  ensure
    PokeAccess::Config.key_hint_letters = was
  end

  # What the configuration menu's info key says on the row of the mode's screen the block picks, as [text, interrupt]
  # pairs; the menu's screen and row put back after.
  def help_on_row(mode)
    cm = PokeAccess::ConfigMenu
    was = [cm.instance_variable_get(:@mode), cm.instance_variable_get(:@index)]
    cm.instance_variable_set(:@mode, mode)
    cm.instance_variable_set(:@index, cm.items.index { |item| yield item })
    SpeakCapture.clear
    cm.speak_help
    SpeakCapture.log.dup
  ensure
    cm.instance_variable_set(:@mode, was[0])
    cm.instance_variable_set(:@index, was[1])
  end

  # Loads Royal's key reader once, as boot does, its override of KeyHints.table standing from then on.
  def load_royal_keys
    eval(Harness.source(ROYAL_KEYS), TOPLEVEL_BINDING, ROYAL_KEYS) unless defined?(PokeAccess::RoyalKeys)
  end

  # The block's value with Royal's KeybindingReader naming each button's key as names does ("?" for one it lacks),
  # taken away after.
  def with_keybinding_reader(names)
    reader = Module.new
    reader.define_singleton_method(:key_name) { |n| names[n] || "?" }
    Object.const_set(:KeybindingReader, reader)
    yield
  ensure
    Object.send(:remove_const, :KeybindingReader) if defined?(::KeybindingReader)
  end
end
