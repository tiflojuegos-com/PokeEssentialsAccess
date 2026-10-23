# Every shipped .rb in core, games, plugins, loader and tools parses (the runner loads only one profile per pass).
# Each is compiled with coverage off and thrown away: nothing registers, and a coverage run keeps the counts of the
# files the suite loaded, which compiling them again under their own paths would zero.
class ParseAllTest < PokeAccessTest
  ROOT = File.expand_path("../..", File.dirname(__FILE__))
  SHIPPED = %w[core games plugins loader tools]

  test "every shipped ruby file parses" do
    files = SHIPPED.map { |d| Dir.glob(File.join(ROOT, d, "**", "*.rb")) }.flatten.sort
    assert_operator files.length, :>, 200, "the sweep found the shipped files"
    sources = files.map { |f| [f[(ROOT.length + 1)..-1].tr("\\", "/"), File.read(f)] }
    assert_equal [], syntax_errors(sources), "no shipped file has a syntax error"
  end

  test "a file that does not parse is reported by its path and the line of its error" do
    errors = syntax_errors([["core/good.rb", "def ok\n  1\nend\n"], ["core/bad.rb", "x = 1\ny = )\nz = 3\n"]])
    assert_equal 1, errors.length, "only the broken file is reported: #{errors.inspect}"
    assert_match(%r{\Acore/bad\.rb:2: syntax error}, errors[0])
  end

  private

  # The first line of the parser's message for each [path, source] that fails to compile, warnings silenced meanwhile.
  def syntax_errors(sources)
    verbose = $VERBOSE
    $VERBOSE = nil
    sources.each_with_object([]) do |(path, src), bad|
      begin
        RubyVM::InstructionSequence.compile(src, path, path, 1, :coverage_enabled => false)
      rescue SyntaxError => e
        bad.push(e.message.to_s.split("\n")[0])
      end
    end
  ensure
    $VERBOSE = verbose
  end
end
