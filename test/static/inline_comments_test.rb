# No full-line comment sits inside a def or a hook block (after, before, around, override, wrap_global, wrap_kernel or
# Hooks.<name> whose line ends in "do") in core, games, plugins, loader or tools; trailing ones would need a parser.
# A body ends at the first line at the opener's indentation plus "end", "end if/unless ..." or "end)".
class InlineCommentsTest < PokeAccessTest
  ROOT = File.expand_path("../..", File.dirname(__FILE__))
  SWEPT = %w[core games plugins loader tools]
  DEF_OPENER = /^(\s*)def\b/
  HOOK_OPENERS = [/^(\s*)(?:after|before|around|override|wrap_global|wrap_kernel)\(/,
                  /^(\s*)(?:PokeAccess::Hooks|Hooks)\.[A-Za-z_][A-Za-z0-9_]*\(/]

  test "no shipped file has a comment inside a method or hook body" do
    files = SWEPT.map { |d| Dir.glob(File.join(ROOT, d, "**", "*.rb")) }.flatten.sort
    assert_operator files.length, :>, 400, "the sweep found the shipped files"
    offenders = files.map do |f|
      comments_inside(File.read(f).split("\n")).map { |n| "#{f[(ROOT.length + 1)..-1].tr("\\", "/")}:#{n}" }
    end.flatten
    assert_equal [], offenders.first(12), "every explanation lives on its method's or hook's header"
  end

  test "flags a full-line comment inside a def or a hook block" do
    {
      ["def read", "  # why", "  1", "end"] => [2],
      ["  def self.read(x)", "    x", "    # why", "  end"] => [3],
      ["after(\"Scene\", :update) do |s|", "  # why", "end"] => [2],
      ["before(\"Scene\", :update) do", "  # why", "end"] => [2],
      ["around(\"Scene\", :update) do", "  # why", "end"] => [2],
      ["override(\"Scene\", :update) do |s, original, args|", "  # why", "end"] => [2],
      ["wrap_global(\"pbMessage\", :tag) do", "  # why", "end"] => [2],
      ["wrap_kernel(\"pbMessage\", :tag) do", "  # why", "end"] => [2],
      ["PokeAccess::Hooks.after_hook(\"Scene\", :update, :optional) do", "  # why", "end"] => [2],
      ["Hooks.wrap_kernel(\"pbMessage\") do |*a|", "  # why", "end"] => [2],
      ["class Reader", "  def a", "    # why", "  end", "  def b", "  end", "end"] => [3]
    }.each { |lines, want| assert_equal want, comments_inside(lines), "in #{lines.inspect}" }
  end

  test "leaves alone headers, trailing comments, one-line defs and hook calls with no do block" do
    [
      ["# what it does", "def read", "  1", "end"],
      ["def read", "  1 # trailing, would need a parser", "end"],
      ["def read; 1; end", "# header of the next", "def b", "end"],
      ["after(\"Scene\", :update) { |s| s }", "# header of the next", "def b", "end"],
      ["after(\"Scene\", :update, :optional)", "# header of the next", "def b", "end"]
    ].each { |lines| assert_equal [], comments_inside(lines), "in #{lines.inspect}" }
  end

  test "closes a body at end, end if, end unless or end) at the opener's indentation" do
    {
      ["def a", "  1", "end", "# next header", "end"] => [],
      ["after(\"S\", :m) do", "  1", "end if defined?(S)", "# next header", "end"] => [],
      ["after(\"S\", :m) do", "  1", "end unless $skip", "# next header", "end"] => [],
      ["after(\"S\", :m) do", "  1", "end)", "# next header", "end"] => [],
      ["after(\"S\", :m) do", "  1", "end.call", "# still inside", "end"] => [4],
      ["  def a", "    1", "    end", "  # still inside", "  end"] => [4]
    }.each { |lines, want| assert_equal want, comments_inside(lines), "in #{lines.inspect}" }
  end

  test "a body that never closes flags nothing" do
    assert_equal [], comments_inside(["def a", "  # inside, but the end is missing", "  1"])
  end

  private

  # The indentation the body this line opens closes at: a def's, or a hook call's whose line ends in a do block;
  # nil for any other line.
  def opener_indent(raw)
    return $1 if raw =~ DEF_OPENER
    hook = HOOK_OPENERS.map { |re| raw[re, 1] }.compact.first
    hook && raw.rstrip =~ /do(\s*\|[^|]*\|)?\z/ ? hook : nil
  end

  # The 1-based numbers of the full-line comments inside a def or hook body among lines.
  def comments_inside(lines)
    inside = {}
    lines.each_with_index do |raw, i|
      indent = opener_indent(raw)
      next if indent.nil? || raw =~ /;\s*end\s*$/
      closer = /\A#{Regexp.escape(indent)}end(?:\s+(?:if|unless)\s+\S.*|\))?\z/
      j = ((i + 1)...lines.length).find { |n| lines[n].rstrip =~ closer }
      ((i + 1)...j).each { |n| inside[n] = true } if j
    end
    inside.keys.sort.select { |n| lines[n].strip[0, 1] == "#" }.map { |n| n + 1 }
  end
end
