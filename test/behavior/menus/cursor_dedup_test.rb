# The dedup under every cursor reader (Cursor): an entry is spoken only when its key changes, per holder and slot; a
# reset or a fresh cursor reads again, a blank line is retried for a while, and the opening read can be queued.
class CursorDedupTest < PokeAccessTest
  Cursor = PokeAccess::Cursor

  test "speaks a focused entry once while its key stays the same" do
    holder = Object.new
    3.times { Cursor.announce(holder, :slot, 5) { "entry five" } }
    assert_equal [["entry five", true]], SpeakCapture.log
  end

  test "speaks again when the key changes" do
    holder = Object.new
    Cursor.announce(holder, :slot, 5) { "entry five" }
    Cursor.announce(holder, :slot, 6) { "entry six" }
    assert_equal [["entry five", true], ["entry six", true]], SpeakCapture.log
  end

  test "reads the same key again after a reset" do
    holder = Object.new
    Cursor.announce(holder, :slot, 6) { "entry six" }
    Cursor.reset(holder, :slot)
    Cursor.announce(holder, :slot, 6) { "entry six" }
    assert_equal [["entry six", true], ["entry six", true]], SpeakCapture.log
  end

  test "answers true when it spoke and nil when it did not" do
    holder = Object.new
    answers = [Cursor.announce(holder, :slot, 1) { "uno" }, Cursor.announce(holder, :slot, 1) { "uno" },
               Cursor.announce(holder, :slot, 2) { nil }]
    assert_equal [true, nil, nil], answers, "a new key, the same key again, a blank line"
  end

  test "speaks the line cleaned of the game's text codes" do
    Cursor.announce(Object.new, :slot, 1) { "\\c[2]Poción<br>x3" }
    assert_equal [["Poción x3", true]], SpeakCapture.log
  end

  test "files its reading under the menu category of the history" do
    Cursor.announce(Object.new, :slot, 1) { "Mochila" }
    assert_equal ["Mochila"], PokeAccess::History.lines_of(:menu).map { |m| m.text }
  end

  test "a nil key is never a change and leaves the last key held" do
    holder = Object.new
    Cursor.changed?(holder, :g, "a")
    refute Cursor.changed?(holder, :g, nil), "a nil key"
    refute Cursor.changed?(holder, :g, "a"), "the key before it is still held"
  end

  test "compares tuple keys by value" do
    holder = Object.new
    assert_equal [true, false, true], [[1, 2], [1, 2], [1, 3]].map { |k| Cursor.changed?(holder, :a, k) }
  end

  test "keeps each slot of a holder and each holder apart" do
    a = Object.new
    b = Object.new
    assert_equal [true, true, true], [[a, :x], [a, :y], [b, :x]].map { |h, s| Cursor.changed?(h, s, 1) }
  end

  test "takes a slot with or without its leading @ for the same slot" do
    holder = Object.new
    Cursor.changed?(holder, :@access_x, 1)
    refute Cursor.changed?(holder, :access_x, 1)
  end

  test "keeps a nil holder's keys in the module-wide table, which a reset re-arms" do
    answers = [Cursor.changed?(nil, :global_slot, 1), Cursor.changed?(nil, :global_slot, 1)]
    Cursor.reset(nil, :global_slot)
    answers.push(Cursor.changed?(nil, :global_slot, 1))
    assert_equal [true, false, true], answers
  end

  test "drops the module-wide table when the caches are reset on a map change" do
    Cursor.changed?(nil, :global_slot, 1)
    PokeAccess::Caches.reset_all
    assert Cursor.changed?(nil, :global_slot, 1)
  end

  test "a holder that cannot keep its key never reports a change, so its reader stays silent, and takes a reset" do
    holder = Object.new.freeze
    refute Cursor.changed?(holder, :g, 1), "changed?"
    Cursor.announce(holder, :g, 1) { "uno" }
    Cursor.reset(holder, :g)
    assert_nothing_spoken
  end

  test "is pending until a fresh or reset cursor holds its first key" do
    holder = Object.new
    states = [Cursor.pending?(holder, :p)]
    Cursor.changed?(holder, :p, [1, 2])
    states.push(Cursor.pending?(holder, :p))
    Cursor.reset(holder, :p)
    states.push(Cursor.pending?(holder, :p))
    assert_equal [true, false, true], states, "fresh, holding a key, reset"
  end

  test "is still pending while its first line is blank" do
    holder = Object.new
    Cursor.announce(holder, :p, 1) { nil }
    assert Cursor.pending?(holder, :p)
  end

  test "reads a row whose text arrives a few polls late" do
    holder = Object.new
    text = nil
    2.times { Cursor.announce(holder, :lb, 1) { text } }
    text = "llegó"
    Cursor.announce(holder, :lb, 1) { text }
    assert_equal [["llegó", true]], SpeakCapture.log
  end

  test "takes an empty line for a blank one" do
    holder = Object.new
    Cursor.announce(holder, :lb, 1) { "" }
    Cursor.announce(holder, :lb, 1) { "llegó" }
    assert_equal [["llegó", true]], SpeakCapture.log
  end

  test "gives up on a row still blank after twenty polls" do
    { 19 => [["llegó", true]], 20 => [] }.each do |blank, want|
      holder = Object.new
      blank.times { Cursor.announce(holder, :lb, 1) { nil } }
      SpeakCapture.clear
      Cursor.announce(holder, :lb, 1) { "llegó" }
      assert_equal want, SpeakCapture.log, "the text arriving after #{blank} blank polls"
    end
  end

  test "counts a new row's blank polls afresh" do
    holder = Object.new
    19.times { Cursor.announce(holder, :lb, 1) { nil } }
    19.times { Cursor.announce(holder, :lb, 2) { nil } }
    Cursor.announce(holder, :lb, 2) { "dos" }
    assert_equal [["dos", true]], SpeakCapture.log
  end

  test "re-reads the previous row when coming back from one that stays blank" do
    holder = Object.new
    Cursor.announce(holder, :lb, 1) { "uno" }
    Cursor.announce(holder, :lb, 2) { nil }
    Cursor.announce(holder, :lb, 1) { "uno" }
    assert_equal [["uno", true], ["uno", true]], SpeakCapture.log
  end

  test "does not retry a line whose reader raised" do
    holder = Object.new
    answer = Cursor.announce(holder, :lb, 1) { raise "row not drawn" }
    Cursor.announce(holder, :lb, 1) { "uno" }
    assert_nil answer, "the raising read"
    assert_nothing_spoken
  end

  test "queues the opening read of a fresh or reset cursor and interrupts the moves after it" do
    holder = Object.new
    Cursor.announce(holder, :cf, 0, true, false) { "primero" }
    Cursor.announce(holder, :cf, 1, true, false) { "segundo" }
    Cursor.reset(holder, :cf)
    Cursor.announce(holder, :cf, 1, true, false) { "segundo" }
    assert_equal [["primero", false], ["segundo", true], ["segundo", false]], SpeakCapture.log
  end

  test "keeps the opening read queued when its text arrives late" do
    holder = Object.new
    Cursor.announce(holder, :cf, 0, true, false) { nil }
    Cursor.announce(holder, :cf, 0, true, false) { "primero" }
    assert_equal [["primero", false]], SpeakCapture.log
  end

  test "without a first interrupt every read takes the plain one" do
    plain = { true => [["primero", true], ["segundo", true]], false => [["primero", false], ["segundo", false]] }
    plain.each do |interrupt, want|
      SpeakCapture.clear
      holder = Object.new
      Cursor.announce(holder, :cf, 0, interrupt) { "primero" }
      Cursor.announce(holder, :cf, 1, interrupt) { "segundo" }
      assert_equal want, SpeakCapture.log, "interrupt #{interrupt}"
    end
  end

  test "runs an on_change block only on a change, giving its value" do
    holder = Object.new
    runs = 0
    answers = [1, 1, 2].map { |k| Cursor.on_change(holder, :oc, k) { runs += 1; "fila #{k}" } }
    assert_equal ["fila 1", nil, "fila 2"], answers
    assert_equal 2, runs, "runs of the block"
  end

  test "gives nil when an on_change block raises" do
    assert_nil Cursor.on_change(Object.new, :oc, 1) { raise "broken reader" }
  end
end
