# The session recorder: it observes the speech dispatcher, writes only changes, keeps a tab in a line from splitting
# the record, counts the whole session, and does nothing when off.
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

    rec.instance_variable_set(:@lines, [])
    rec.snapshot([:diag_map], "map")
    eq "a dump identical to the previous one collapses to a single marker",
       rec.instance_variable_get(:@lines).length, 1
    truthy "and the marker says so", rec.instance_variable_get(:@lines)[0].include?("igual que el anterior")

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
    PokeAccess::Speech.unobserve(:recorder)
  end
end

# Speech observers see every spoken line as a message; a raising observer cannot silence the mod.
Suite.define("recorder: an observer sees every line as a message and a raising one cannot mute the mod") do
  seen = []
  begin
    PokeAccess::Speech.observe(:spec_observer) { |msg| seen.push(msg) }
    SpeakCapture.clear
    PokeAccess.speak("hola mundo", true, :system)
    eq "the observer saw the line", seen.length, 1
    eq "with its text", seen[0].text, "hola mundo"
    eq "its interrupt flag", seen[0].interrupt, true
    eq "and its category", seen[0].category, :system
    spoke "and the player still heard it", /hola mundo/

    PokeAccess::Speech.observe(:spec_observer) { |_msg| raise "observer exploded" }
    SpeakCapture.clear
    PokeAccess.speak("sigo hablando", true)
    spoke "a raising observer does not stop the speech", /sigo hablando/
    PokeAccess::Speech.unobserve(:spec_observer)
    seen.clear
    PokeAccess.speak("ya nadie escucha", true)
    eq "and one removed hears nothing more", seen.length, 0
  ensure
    PokeAccess::Speech.unobserve(:spec_observer)
  end
end

# The transcript auditor on synthetic transcripts: each rule fires on its own bug and not on the look-alike.
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

  asked ="1.00\tsay\t1\tMT20. Ataca con agua hirviendo\n" +
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

  truthy "hay grabaciones de referencia que auditar (#{Replay.fixtures.length})", Replay.fixtures.length >= 1
  eq "committed fixture recordings all audit clean",
     Replay.fixtures.map { |f| [File.basename(f), Replay.audit(File.read(f))] }.reject { |_n, p| p.empty? }, []
end
