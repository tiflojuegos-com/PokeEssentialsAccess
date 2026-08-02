# Replay: AUDITS a session recorded in-game by core/util/recorder.rb. It deliberately does not try to
# re-simulate the session -- rebuilding a real fangame's map faithfully enough to re-derive every reader's
# decision would need more of the world than a recording can hold, and a half-rebuilt map produces failures
# that are the harness's fault, not the mod's. Instead it checks the transcript for the three ways this mod
# actually fails a player, all of them visible in the timeline alone:
#
#   SILENCE   the locator's selection moved and nothing was spoken after it -- the cursor moved and the
#             player was left guessing, which is the bug class the whole mod exists to prevent.
#   REPEAT    the same line spoken twice with NOTHING from the player in between: a dedup that stopped
#             deduping. "Nothing from the player" includes keypresses, or a menu re-read looks like a bug.
#   RAW       a line still carrying RPG Maker control codes (\c[1], \PN): a reader that skipped clean.
#
# Drop a real recording into test/fixtures/recordings/ and it becomes a regression test for free: a play
# session by a blind tester turns into asserts nobody had to write.
module Replay
  RAW_CODE = /\\[A-Za-z]/

  # Parses a recording into [seconds, kind, fields...] rows, skipping the header and blank lines.
  def self.parse(text)
    rows = []
    text.split("\n").each do |line|
      line = line.sub(/\r\z/, "")
      next if line.empty? || line[0, 1] == "#"
      parts = line.split("\t")
      next if parts.length < 2
      rows.push([parts[0].to_f, parts[1]] + parts[2..-1])
    end
    rows
  end

  # Every spoken line that still carries control codes, as "text" strings.
  def self.raw_lines(rows)
    rows.select { |r| r[1] == "say" && r[3].to_s =~ RAW_CODE }.map { |r| r[3] }
  end

  # Lines spoken twice in a row with NOTHING from the player in between: no step, no map or scene change,
  # no locator selection and no keypress. A broken dedup speaks the same entry again on its own; the player
  # walking back to it, cursoring through a menu or pressing the info key twice is legitimate.
  #
  # The keypress ("in") is what makes this usable. Without it, a real session was 4 flags and 4 false
  # positives: navigating a menu moves no position and changes no scene, so every legitimate re-read --
  # returning to the same entry, or asking for a description again -- looked exactly like a broken dedup.
  # Returns "text (+Ns)" so a reader can weigh it: a dedup bug repeats within a frame, a person does not.
  def self.repeats(rows)
    out = []
    last_say = nil
    last_at = 0.0
    rows.each do |r|
      case r[1]
      when "say"
        out.push("#{r[3]} (+#{sprintf('%.2f', r[0] - last_at)}s)") if r[3] == last_say
        last_say = r[3]
        last_at = r[0]
      when "pos", "map", "scene", "sel", "in"
        last_say = nil
      end
    end
    out
  end

  # Selection changes that were never followed by speech before the next change (the silent-cursor bug).
  # Returns the offending "index name" descriptions.
  def self.silent_selections(rows)
    out = []
    pending = nil
    rows.each do |r|
      case r[1]
      when "sel"
        out.push(pending) if pending
        pending = "#{r[2]} #{r[3]}"
      when "say"
        pending = nil
      end
    end
    out.push(pending) if pending
    out
  end

  # Runs the three audits over a recording's text, returning a list of human-readable problems (empty
  # when the session is clean).
  def self.audit(text)
    rows = parse(text)
    problems = []
    raw_lines(rows).each { |t| problems.push("raw control codes spoken: #{t}") }
    repeats(rows).each { |t| problems.push("line repeated with no movement between: #{t}") }
    silent_selections(rows).each { |s| problems.push("selection changed but nothing was spoken: #{s}") }
    problems
  end

  # Audits every recording committed under test/fixtures/recordings/ (none by default: the mechanism is
  # proven by its own spec, and real sessions plug in here).
  def self.fixtures
    dir = File.join(File.dirname(__FILE__), "..", "fixtures", "recordings")
    Dir.glob(File.join(dir, "*.txt")).sort
  end
end
