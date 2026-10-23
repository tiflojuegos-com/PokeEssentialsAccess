# Yuko115's Functional Piano (plugins/bes_piano.rb, pbPiano): it paints no text and plays its notes as sounds, so the
# plugin says, as it opens, which key plays which note and how to leave, and holds the mod's own keys back while it runs.

# What the mod's typing hold stood at on each frame of the piano's loop.
module BesPianoFrames
  class << self
    attr_accessor :holds
  end
  self.holds = []
end

# The game's function, cut down to six frames of its loop. Each frame the mod's global poll lets the hold run down by
# one, as Keys.global_poll does before the pollers of the same pulse, which the plugin's must then renew.
def pbPiano
  6.times do
    hold = PokeAccess::Keys.instance_variable_get(:@typing_ttl)
    PokeAccess::Keys.instance_variable_set(:@typing_ttl, [hold - 1, 0].max)
    PokeAccess::Frame.run_pollers
    BesPianoFrames.holds.push(PokeAccess::Keys.instance_variable_get(:@typing_ttl))
  end
  :piano_closed
end

# The plugin's wrap of the function, which the harness's own load of the file made before the function existed; its
# per-frame poller, registered then, is the one that runs.
BES_PIANO_WRAP = Harness.source(File.join(Harness::ROOT, "plugins", "bes_piano.rb"))
                        .match(/^PokeAccess::Hooks\.wrap_kernel\("pbPiano".*?^end\n/m)[0]
eval(BES_PIANO_WRAP, TOPLEVEL_BINDING, "plugins/bes_piano.rb")

class BesPianoTest < PokeAccessTest
  LABELS = { "piano_title" => "Piano", "piano_note_c" => "Do", "piano_note_d" => "Re", "piano_note_e" => "Mi",
             "piano_note_f" => "Fa", "piano_note_g" => "Sol", "piano_note_a" => "La", "piano_note_b" => "Si",
             "piano_sharp" => "%{note} sostenido", "piano_high" => "%{note} agudo",
             "piano_high_sharp" => "%{note} agudo sostenido", "piano_keys" => "Teclas: %{list}",
             "piano_sharps" => "Con %{shift} pulsadas, sostenidos: %{list}", "piano_exit" => "Salir: %{key}" }.freeze

  NATURALS = "Q Do, W Re, E Mi, R Fa, T Sol, Y La, U Si, I Do agudo, O Re agudo, P Mi agudo"
  SHARPS = "Q Do sostenido, W Re sostenido, E Fa sostenido, R Sol sostenido, T La sostenido, Y Do agudo sostenido, " \
           "U Re agudo sostenido"

  def setup
    super
    table = PokeAccess::I18n.table(:es)
    @added = LABELS.keys.reject { |k| table.key?(k) }
    @added.each { |k| table[k] = LABELS[k] }
    BesPianoFrames.holds = []
    PokeAccess::Keys.instance_variable_set(:@typing_ttl, 0)
  end

  def teardown
    @added.each { |k| PokeAccess::I18n.table(:es).delete(k) }
    PokeAccess::Keys.instance_variable_set(:@typing_ttl, 0)
    super
  end

  test "says its name, the notes of its keys, those sharpened under shift and the key that leaves, queued" do
    pbPiano
    help = "Piano. Teclas: #{NATURALS}. Con #{t(:key_shift)} pulsadas, sostenidos: #{SHARPS}. Salir: #{t(:key_escape)}"
    assert_equal [[help, false]], SpeakCapture.log
  end

  test "says only its name where hints are not said" do
    said = vb_levels do
      SpeakCapture.clear
      pbPiano
      SpeakCapture.lines.first
    end
    assert_equal ["Piano", PokeAccess::BesPiano.help, PokeAccess::BesPiano.help], said
  end

  test "names the key the player leaves with as the player has it" do
    PokeAccess::Config.rebinds = { :b => 0x58 }
    pbPiano
    assert_match(/Salir: X\z/, SpeakCapture.lines.first)
  end

  test "maps each key to the note the script plays, and each shifted key to its sharp" do
    assert_equal NATURALS, PokeAccess::BesPiano.key_list(PokeAccess::BesPiano::NATURALS, false)
    assert_equal SHARPS, PokeAccess::BesPiano.key_list(PokeAccess::BesPiano::SHARPS, true)
  end

  test "names a note plainly, sharpened, an octave up, or both" do
    names = [[false, false], [true, false], [false, true], [true, true]].map do |sharp, high|
      PokeAccess::BesPiano.note_name(:piano_note_g, sharp, high)
    end
    assert_equal ["Sol", "Sol sostenido", "Sol agudo", "Sol agudo sostenido"], names
  end

  test "renews the hold on the mod's keys on every frame of the loop and lets it run down when it closes" do
    pbPiano
    assert_equal [4] * 6, BesPianoFrames.holds
    PokeAccess::Keys.instance_variable_set(:@typing_ttl, 0)
    PokeAccess::Frame.run_pollers
    assert_equal 0, PokeAccess::Keys.instance_variable_get(:@typing_ttl)
  end

  test "the piano opens all the same where its help cannot be composed, and still holds the keys" do
    help = PokeAccess::BesPiano.method(:help)
    PokeAccess::BesPiano.define_singleton_method(:help) { raise "no help to give" }
    begin
      ret = pbPiano
    ensure
      PokeAccess::BesPiano.define_singleton_method(:help, help)
    end
    assert_equal [:piano_closed, [], [4] * 6], [ret, SpeakCapture.log, BesPianoFrames.holds]
  end

  test "says nothing of the notes it plays" do
    pbPiano
    assert_equal 1, SpeakCapture.log.length
  end

  test "hands back what the game returns" do
    assert_equal :piano_closed, pbPiano
  end

  test "does not hold the mod's keys outside the piano" do
    PokeAccess::Frame.run_pollers
    assert_equal 0, PokeAccess::Keys.instance_variable_get(:@typing_ttl)
    assert_nothing_spoken
  end

  private

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end
end
