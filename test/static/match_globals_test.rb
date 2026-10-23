# Inside a gsub, sub or scan block of core, games or plugins, every match global ($~, $1-$9, $&, $`, $') is read
# before the block calls anything that matches a regex (split, gsub, sub, scan, match, =~): Ruby 1.8.7 resets them in
# the caller's frame there, so a capture read after such a call is nil, while Ruby 3, which the suite runs, keeps it.
require "prism"

class MatchGlobalsTest < PokeAccessTest
  BLOCK_CALLS = %w[gsub gsub! sub sub! scan].freeze
  MATCHERS = %w[split gsub gsub! sub sub! scan match =~ !~].freeze

  test "reads every match global of a gsub, sub or scan block before any call there that matches a regex" do
    sources = %w[core games plugins].map { |d| Dir.glob(File.join(Harness::ROOT, d, "**", "*.rb")) }.flatten.sort
    assert_operator sources.length, :>, 500, "the files it reads"
    assert_equal [], late_reads(sources.map { |f| [f.sub(Harness::ROOT + "/", ""), File.read(f)] })
  end

  test "reports a capture read after a split in the same block, and none read before it" do
    late = "s.gsub(/(a)(b)(c)/) { $1 + $2.split(\"/\").join + $3 }\n"
    early = "s.gsub(/(a)(b)(c)/) { a, b, c = $1, $2, $3; a + b.split(\"/\").join + c }\n"
    assert_equal [["x.rb:1 $3"], []], [late_reads([["x.rb", late]]), late_reads([["x.rb", early]])]
  end

  test "reports a read in a later statement of the block, and $~ as well" do
    src = "s.sub(/(a)/) do\n  t = u.scan(/b/)\n  [$1, $~]\nend\n"
    assert_equal ["x.rb:3 $1", "x.rb:3 $~"], late_reads([["x.rb", src]])
  end

  test "leaves alone a block that calls nothing matching, and reads passed to a call" do
    src = "s.gsub(/(a)/) { swap.call($1) + other($1) }\ns.scan(/(b)/) { list.push($1) }\n"
    assert_equal [], late_reads([["x.rb", src]])
  end

  private

  # "path:line global" for each match global a gsub, sub or scan block of the [path, text] sources reads after a call
  # there that matches a regex.
  def late_reads(sources)
    out = []
    sources.each do |rel, text|
      each_node(Prism.parse(text).value) do |n|
        next unless n.is_a?(Prism::CallNode) && BLOCK_CALLS.include?(n.name.to_s) && n.block.is_a?(Prism::BlockNode)
        ends = []
        reads = []
        each_node(n.block.body) do |m|
          ends.push(m.location.end_offset) if m.is_a?(Prism::CallNode) && MATCHERS.include?(m.name.to_s)
          reads.push(m) if match_global?(m)
        end
        next if ends.empty?
        reads.each { |r| out.push("#{rel}:#{r.location.start_line} #{r.slice}") if r.location.start_offset > ends.min }
      end
    end
    out
  end

  # True for a read of $~, a numbered capture or one of $&, $`, $'.
  def match_global?(node)
    node.is_a?(Prism::NumberedReferenceReadNode) || node.is_a?(Prism::BackReferenceReadNode) ||
      (node.is_a?(Prism::GlobalVariableReadNode) && node.name.to_s == "$~")
  end

  # Yields node and every node below it, depth first.
  def each_node(node, &blk)
    return unless node
    yield node
    node.compact_child_nodes.each { |c| each_node(c, &blk) }
  end
end
