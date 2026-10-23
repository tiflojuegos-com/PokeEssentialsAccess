# A multi-line method of core, games or plugins that touches a file and rescues at its own level leaves a trace in its
# rescue (a log line, a swallowed record, a marker, a speak or a raise), but for the two allowed marker writers (the
# mod's, and Uranium's compat script's, which runs before the mod has a log).
class SilentIoTest < PokeAccessTest
  IO_CALL = /\b(File\.(open|read|readlines|foreach|write|delete|rename|binread|unlink)|KVFile\.each|Marshal\.load|IO\.(write|read))\b/
  TRACE = /log_once|swallowed|write_marker|log3d|log_body_failure|PokeAccess\.speak|\braise\b/
  ALLOWED = ["core/foundation/failures.rb write_marker", "games/uranium/compat.rb note"].freeze

  test "finds no method of the mod that touches a file and rescues without a trace" do
    sources = mod_sources
    assert_equal %w[core games plugins], sources.map { |rel, _text| rel[%r{\A[^/]+}] }.uniq, "the folders it sweeps"
    assert_operator sources.length, :>, 500, "every file down each folder"
    assert_operator sources.map { |_rel, text| methods_of(text).length }.inject(0, :+), :>, 3000,
                    "and their multi-line methods one by one"
    assert_equal [], sources.map { |rel, text| silent_in(rel, text) }.flatten
  end

  test "flags a method that reads a file and rescues without a trace, by file, name and line" do
    assert_equal ["core/probe.rb planted:2"], silent_in("core/probe.rb", planted("File.read(path)", "nil"))
  end

  test "counts every kind of file access it watches" do
    calls = ["File.open(path, 'w') { |f| f.write(text) }", "File.read(path)", "File.readlines(path)",
             "File.foreach(path) { |l| l }", "File.write(path, text)", "File.delete(path)", "File.rename(path, text)",
             "File.binread(path)", "File.unlink(path)", "KVFile.each(path) { |k, v| k }", "Marshal.load(text)",
             "IO.write(path, text)", "IO.read(path)"]
    missed = calls.reject { |call| silent_in("core/probe.rb", planted(call, "nil")) == ["core/probe.rb planted:2"] }
    assert_equal [], missed
  end

  test "takes a log, a marker, a speak or a raise in the rescue as its trace" do
    traces = ["PokeAccess.log_once(:probe, e)", "PokeAccess.write_marker(e.message)", "log3d(e)",
              "log_body_failure(e)", "PokeAccess.speak(e.message)", "raise"]
    flagged = traces.reject { |trace| silent_in("core/probe.rb", planted("File.read(path)", trace)).empty? }
    assert_equal [], flagged
  end

  test "does not take a trace written before the rescue" do
    src = "module Probe\n  def self.planted(path)\n    PokeAccess.log_once(:probe, path)\n    File.read(path)\n" \
          "  rescue StandardError\n    nil\n  end\nend\n"
    assert_equal ["core/probe.rb planted:2"], silent_in("core/probe.rb", src)
  end

  test "skips a method written on one line and goes on with the next" do
    src = "module Probe\n  def self.planted_short(path); File.read(path) rescue nil; end\n" \
          "  def self.planted(path)\n    File.read(path)\n  rescue StandardError\n    nil\n  end\nend\n"
    assert_equal ["core/probe.rb planted:3"], silent_in("core/probe.rb", src)
  end

  test "counts only a rescue at the method's own level" do
    src = "module Probe\n  def self.planted(path)\n    begin\n      File.read(path)\n    rescue StandardError\n" \
          "      nil\n    end\n  end\nend\n"
    assert_equal [], silent_in("core/probe.rb", src)
  end

  test "leaves out a method that rescues without touching a file" do
    assert_equal [], silent_in("core/probe.rb", planted("Integer(path)", "nil"))
  end

  test "reads a method's body up to the end at its own indentation" do
    inner = "module Probe\n  def self.planted(path)\n    [path].each do |p|\n      p\n    end\n    File.read(path)\n" \
            "  rescue StandardError\n    nil\n  end\nend\n"
    apart = "module Probe\n  def self.planted_reads(path)\n    File.read(path)\n  end\n" \
            "  def self.planted_rescues(path)\n    Integer(path)\n  rescue StandardError\n    nil\n  end\nend\n"
    assert_equal ["core/probe.rb planted:2"], silent_in("core/probe.rb", inner), "a block's end inside it is not its end"
    assert_equal [], silent_in("core/probe.rb", apart), "its own end keeps the next method's rescue out of it"
  end

  test "lets the allowed marker writers rescue silently, and only in their own file" do
    src = "module PokeAccess\n  def self.write_marker(extra = \"\")\n    File.open(MARK_FILE, \"a\") { |f| f.write(extra) }\n" \
          "  rescue StandardError\n  end\nend\n"
    assert_equal [], silent_in("core/foundation/failures.rb", src), "in its own file"
    assert_equal ["core/other.rb write_marker:2"], silent_in("core/other.rb", src), "anywhere else"
  end

  test "allows only methods that are still there and would be flagged without the allowance" do
    stale = ALLOWED.reject do |tag|
      rel = tag.split(" ").first
      path = File.join(Harness::ROOT, rel)
      File.file?(path) && silent_in(rel, Harness.source(path), []).any? { |hit| hit.start_with?("#{tag}:") }
    end
    assert_equal [], stale
  end

  private

  # [path from the repo root, source] of every Ruby file under core/, games/ and plugins/.
  def mod_sources
    %w[core games plugins].map { |d| Dir.glob(File.join(Harness::ROOT, d, "**", "*.rb")) }.flatten.sort.map do |f|
      [f.sub(Harness::ROOT + "/", ""), Harness.source(f)]
    end
  end

  # [name, def line, indentation, body lines] of each multi-line method of a source, a body ending at the first end
  # at the def's own indentation.
  def methods_of(text)
    lines = text.split("\n")
    found = []
    i = 0
    while i < lines.length
      m = lines[i].match(/^(\s*)def\s+(?:self\.)?([a-zA-Z_][A-Za-z0-9_]*[?!=]?)/)
      if m.nil? || lines[i] =~ /;\s*end\s*$/
        i += 1
        next
      end
      j = i + 1
      j += 1 while j < lines.length && lines[j] !~ /^\s{#{m[1].length}}end\b/
      found.push([m[2], i + 1, m[1].length, lines[(i + 1)...j]])
      i = j + 1
    end
    found
  end

  # "path name:line" of each method of the source that touches a file and rescues at its own level with no trace in
  # the rescue, unless allowed names it.
  def silent_in(rel, text, allowed = ALLOWED)
    methods_of(text).map do |name, line, indent, body|
      r = body.index { |l| l =~ /^\s{#{indent}}rescue\b/ }
      next unless r && body.any? { |l| l =~ IO_CALL } && body[r..-1].none? { |l| l =~ TRACE }
      "#{rel} #{name}:#{line}" unless allowed.include?("#{rel} #{name}")
    end.compact
  end

  # A module whose method planted runs call and rescues with after_rescue.
  def planted(call, after_rescue)
    "module Probe\n  def self.planted(path, text = nil)\n    #{call}\n  rescue StandardError => e\n    #{after_rescue}\n" \
      "  end\nend\n"
  end
end
