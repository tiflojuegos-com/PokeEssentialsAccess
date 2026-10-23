# No module method (def self.x) of the mod (core/, games/, plugins/, loader/) is defined and never named: a bare word
# anywhere in the mod or the tests, its own def line aside; a name only built at runtime (send("#{k}=")) is DYNAMIC.
class DeadCodeTest < PokeAccessTest
  ROOT = File.expand_path("../..", File.dirname(__FILE__))
  DYNAMIC = %w[initialize call to_s inspect].freeze
  # A word as a reference: a run of identifier characters after neither @ nor $ (that is an ivar or a global), with
  # the ? or ! that may close it.
  WORD = /(?<![A-Za-z0-9_@$])([A-Za-z0-9_]+)([?!](?![A-Za-z0-9_]))?/

  test "names every module method somewhere besides its definition" do
    mod = %w[core games plugins loader].map { |d| Dir.glob(File.join(ROOT, d, "**", "*.rb")) }.flatten.sort
    tests = Dir.glob(File.join(ROOT, "test", "**", "*.rb")).sort
    corpus = (mod + tests).map { |f| [f.sub(ROOT + "/", ""), File.read(f)] }
    defs = module_defs(corpus.first(mod.length))
    assert_operator defs.length, :>, 1500, "the sweep found methods to check"
    assert_equal [], unreferenced(defs, corpus).first(12), "no module method is defined and never named"
  end

  test "reports a module method nothing names, with its file and line" do
    src = "module Probe\n  def self.planted_used; end\n  def self.planted_orphan; end\nend\nProbe.planted_used\n"
    assert_equal ["core/probe.rb:3 planted_orphan"], unreferenced_in([["core/probe.rb", src]])
  end

  test "counts a name in another file of the mod or in a test as a reference" do
    mod = [["core/probe.rb", "module Probe\n  def self.planted_a; end\n  def self.planted_b; end\nend\n"],
           ["games/x/use.rb", "Probe.planted_a\n"]]
    assert_equal [], unreferenced_in(mod, [["test/unit/probe_test.rb", "Probe.planted_b"]])
  end

  test "counts neither its own def line nor an ivar or a global of that name" do
    src = "module Probe\n  def self.planted_loop; planted_loop; end\n  @planted_loop = 1\n  $planted_loop = 2\nend\n"
    assert_equal ["core/probe.rb:2 planted_loop"], unreferenced_in([["core/probe.rb", src]])
  end

  test "reads a setter by its bare name, and a predicate only with its question mark" do
    src = "module Probe\n  def self.planted_level=(v); end\n  def self.planted_ok?; end\nend\n" \
          "Probe.planted_level = 3\nProbe.planted_ok\n"
    assert_equal ["core/probe.rb:3 planted_ok?"], unreferenced_in([["core/probe.rb", src]])
  end

  test "counts a name as a symbol, after a dot or inside a string" do
    src = "module Probe\n  def self.planted_s; end\n  def self.planted_d; end\n  def self.planted_q; end\nend\n" \
          "send(:planted_s)\nx.planted_d\nputs \"planted_q\"\n"
    assert_equal [], unreferenced_in([["core/probe.rb", src]])
  end

  test "skips the methods Ruby calls by itself" do
    src = "module Probe\n  def self.inspect; end\n  def self.to_s; end\n  def self.call; end\nend\n"
    assert_equal [], unreferenced_in([["core/probe.rb", src]])
  end

  private

  # [name, path, line] of each def self.x in the [path, text] sources.
  def module_defs(sources)
    out = []
    sources.each do |path, text|
      text.split("\n").each_with_index do |l, i|
        out.push([$1, path, i + 1]) if l =~ /^\s*def\s+self\.([a-zA-Z_][A-Za-z0-9_]*[?!=]?)/
      end
    end
    out
  end

  # "path:line name" of each def no line of the [path, text] corpus names but its own (the corpus holds the files
  # that define them): a setter by its bare name, a predicate or bang with its mark, DYNAMIC names aside.
  def unreferenced(defs, corpus)
    lines_with = Hash.new(0)
    corpus.each do |_path, text|
      text.split("\n").each do |l|
        words = {}
        l.scan(WORD) do |run, mark|
          words[run] = true
          words[run + mark] = true if mark
        end
        words.each_key { |w| lines_with[w] += 1 }
      end
    end
    dead = defs.reject { |name, _path, _line| DYNAMIC.include?(name) || lines_with[name.sub(/=\z/, "")] > 1 }
    dead.map { |name, path, line| "#{path}:#{line} #{name}" }
  end

  # unreferenced for planted mod sources, read against them and the planted tests.
  def unreferenced_in(mod, tests = [])
    unreferenced(module_defs(mod), mod + tests)
  end
end
