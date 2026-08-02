# The session recorder and the transcript auditor, the two halves of the replay harness. The recorder
# must transcribe through the single on_speak observer (no hooks of its own inside the readers), write
# only CHANGES so the file stays a timeline, survive a tab in a spoken line, and cost nothing when off.
# The auditor must find the three failure modes a real session can show -- and, just as important, NOT
# flag the legitimate look-alikes (the same line after moving away and back).
Suite.define("recorder: transcribes speech and state changes, and stays inert when off") do
  rec = PokeAccess::Recorder
  prev_on = rec.instance_variable_get(:@on)
  prev_path = rec.instance_variable_get(:@path)
  begin
    rec.instance_variable_set(:@on, false)
    rec.instance_variable_set(:@path, nil)
    rec.instance_variable_set(:@lines, [])
    rec.instance_variable_set(:@seen, {})

    rec.note("say", 1, "ignored while off")
    eq "nothing is buffered while stopped", rec.instance_variable_get(:@lines).length, 0

    rec.instance_variable_set(:@on, true)
    rec.note("say", 1, "Centro Pokemon")
    lines = rec.instance_variable_get(:@lines)
    eq "one event buffered", lines.length, 1
    parts = lines[0].split("\t")
    eq "the kind is the second field", parts[1], "say"
    eq "the interrupt flag rides along", parts[2], "1"
    eq "the text is last", parts[3], "Centro Pokemon"
    truthy "the timestamp leads the line", parts[0] =~ /\A\d+\.\d\d\z/

    rec.note("say", 0, "linea\tcon\ttabs\ny salto")
    truthy "tabs and newlines in a line can never split the record",
           rec.instance_variable_get(:@lines).last.split("\t").length == 4

    # The spoken "N events saved" must count the whole session, not the tail still in the buffer: flush
    # empties @lines every FLUSH_EVERY notes, so counting the buffer would under-report a long session
    # by an order of magnitude -- and the debug menu says that number out loud.
    rec.instance_variable_set(:@count, 0)
    rec.instance_variable_set(:@lines, [])
    5.times { |i| rec.note("say", 1, "linea #{i}") }
    rec.instance_variable_set(:@lines, [])
    3.times { |i| rec.note("say", 1, "mas #{i}") }
    eq "the tally survives the buffer being emptied, as a real flush empties it",
       rec.instance_variable_get(:@count), 8
    truthy "and it is NOT the buffer length, which is what used to be reported",
           rec.instance_variable_get(:@lines).length < 8

    rec.instance_variable_set(:@lines, [])
    truthy "a first value reports that it wrote", rec.on_change("pos", :pos, 5, 7)
    falsy "an unchanged field reports that it did not", rec.on_change("pos", :pos, 5, 7)
    eq "and wrote once, not per frame", rec.instance_variable_get(:@lines).length, 1
    rec.on_change("pos", :pos, 5, 8)
    eq "a changed field writes again", rec.instance_variable_get(:@lines).length, 2

    # The context dump: it must reuse the diag's own sections (so it can never drift from them) and
    # never pull in the two that would falsify the perf window or run a 5000-iteration benchmark.
    falsy "the perf window is never snapshotted automatically", rec::SNAP_MAP.include?(:diag_perf)
    falsy "nor the poll micro-benchmark", rec::SNAP_START.include?(:diag_polls)
    truthy "the map snapshot carries the surroundings and the route",
           rec::SNAP_MAP.include?(:diag_locator) && rec::SNAP_MAP.include?(:diag_pathfinder)
    rec.instance_variable_set(:@lines, [])
    rec.instance_variable_set(:@last_snap, {})
    rec.snapshot([:diag_map], "map")
    rows = rec.instance_variable_get(:@lines)
    truthy "a snapshot writes at least one row", rows.length > 0
    truthy "tagged as diag with its reason", rows[0].split("\t")[1] == "diag" && rows[0].split("\t")[2] == "map"
    eq "and the auditor ignores diag rows", Replay.audit(rows.join("\n")), []
    falsy "the diag's own timestamp header never reaches the transcript (it would defeat the check below)",
          rows.any? { |l| l.include?("=== PokeAccess diag") }

    # The scene flips between nil, :message and :in_menu constantly. In a real session those identical
    # six-line dumps were half the file, burying the events that mattered.
    rec.instance_variable_set(:@lines, [])
    rec.snapshot([:diag_map], "map")
    eq "a dump identical to the previous one collapses to a single marker",
       rec.instance_variable_get(:@lines).length, 1
    truthy "and the marker says so", rec.instance_variable_get(:@lines)[0].include?("igual que el anterior")

    # A snapshot taken in the frame of the change photographs the mod BEFORE its own readers react: a real
    # recording showed the new map's size next to the previous map's target list, with coordinates that
    # could not exist on it. The recorder's frame hook runs before the locator's, so it must wait a frame.
    rec.instance_variable_set(:@lines, [])
    rec.instance_variable_set(:@last_snap, {})
    rec.instance_variable_set(:@pending, [])
    rec.defer([:diag_map], "map")
    eq "deferring writes nothing in the frame the change happened",
       rec.instance_variable_get(:@lines).length, 0
    rec.flush_pending
    truthy "and the dump lands on the next frame", rec.instance_variable_get(:@lines).length > 0
    eq "the queue empties once taken", rec.instance_variable_get(:@pending).length, 0
  ensure
    rec.instance_variable_set(:@on, prev_on)
    rec.instance_variable_set(:@path, prev_path)
    rec.instance_variable_set(:@lines, [])
    rec.instance_variable_set(:@seen, {})
    PokeAccess.on_speak = nil
  end
end

# The observer contract: speak() must feed the recorder without the recorder touching any reader, and a
# broken observer must never be able to silence the mod.
Suite.define("recorder: on_speak observes every line and a raising observer cannot mute the mod") do
  seen = []
  begin
    PokeAccess.on_speak = lambda { |text, interrupt| seen.push([text, interrupt]) }
    SpeakCapture.clear
    PokeAccess.speak("hola mundo", true)
    eq "the observer saw the line", seen.length, 1
    eq "with its text", seen[0][0], "hola mundo"
    eq "and its interrupt flag", seen[0][1], true
    spoke "and the player still heard it", /hola mundo/

    PokeAccess.on_speak = lambda { |_t, _i| raise "observer exploded" }
    SpeakCapture.clear
    PokeAccess.speak("sigo hablando", true)
    spoke "a raising observer does not stop the speech", /sigo hablando/
  ensure
    PokeAccess.on_speak = nil
  end
end

# The auditor over synthetic transcripts: each rule must fire on its own bug and stay quiet on the
# look-alike that is NOT a bug.
Suite.define("replay: the transcript auditor finds silence, repeats and raw codes") do
  clean = "# pea-recording 1\tgen6\t16.0\n" +
          "1.00\tmap\t60\tCentro Pokemon\n" +
          "1.10\tsay\t1\tCentro Pokemon\n" +
          "2.00\tsel\t0\tenfermera\n" +
          "2.05\tsay\t1\tenfermera, a 3 pasos\n" +
          "3.00\tpos\t5\t8\n" +
          "3.10\tsay\t1\tenfermera, a 3 pasos\n"
  eq "a healthy session reports nothing", Replay.audit(clean), []

  silent = "1.00\tsel\t0\tenfermera\n1.50\tsel\t1\tcartel\n2.00\tsay\t1\tcartel\n"
  probs = Replay.audit(silent)
  eq "a selection with no speech after it is caught", probs.length, 1
  truthy "and it names the entry", probs[0].include?("enfermera")

  repeat = "1.00\tsay\t1\tcartel\n1.20\tsay\t1\tcartel\n"
  truthy "the same line twice standing still is caught",
         Replay.audit(repeat).any? { |p| p.include?("repeated") }

  moved = "1.00\tsay\t1\tcartel\n1.10\tpos\t5\t9\n1.20\tsay\t1\tcartel\n"
  falsy "but the same line after moving is NOT flagged",
        Replay.audit(moved).any? { |p| p.include?("repeated") }

  truthy "a real repeat says how long after, so a human can weigh it",
         Replay.audit(repeat).any? { |p| p.include?("+0.20s") }

  # Without the keypress, a real session was four flags and four false positives: navigating a menu moves
  # no position and changes no scene, so asking for the same description again looked like a broken dedup.
  asked = "1.00\tsay\t1\tMT20. Ataca con agua hirviendo\n" +
          "1.40\tin\ttecla:info\n" +
          "4.10\tsay\t1\tMT20. Ataca con agua hirviendo\n"
  falsy "asking again with a key is not a broken dedup",
        Replay.audit(asked).any? { |p| p.include?("repeated") }

  cursored = "1.00\tsay\t1\tCaramelo Raro: 999\n1.20\tin\tdir\n1.40\tsay\t1\tCaramelo Raro: 999\n"
  falsy "nor is landing on an identical menu entry after moving the cursor",
        Replay.audit(cursored).any? { |p| p.include?("repeated") }

  raw = "1.00\tsay\t1\tHola \\c[3]entrenador\n"
  truthy "a line with control codes is caught",
         Replay.audit(raw).any? { |p| p.include?("raw control codes") }

  eq "committed fixture recordings all audit clean",
     Replay.fixtures.map { |f| [File.basename(f), Replay.audit(File.read(f))] }.reject { |_n, p| p.empty? }, []
end
