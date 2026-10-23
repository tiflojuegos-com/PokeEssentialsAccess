# Ruby 1.8.7, the games' Ruby, hands a block with one parameter all the values a yield passes, as one array; the
# tests' Ruby hands it the first. No call in the mod (core/, games/, plugins/) of a method of the mod that yields two
# or more values passes a block with one plain parameter (a destructuring |(a, b)| is fine). Methods are matched by
# name, less the names Ruby's own collections yield by; blocks kept and called later are test/support/arity_net.rb's.
require "ripper"

class BlockArityTest < PokeAccessTest
  ROOT = File.expand_path("../..", File.dirname(__FILE__))
  STD = %w[each map collect select reject find detect inject each_with_index each_pair each_value each_key any? all?
           none? one? sort_by min_by max_by group_by partition times upto downto step each_slice each_cons each_char
           each_byte each_line count find_all delete_if sort uniq zip cycle].freeze

  test "passes no one-parameter block to a method of the mod that yields several values" do
    files = %w[core games plugins].map { |d| Dir.glob(File.join(ROOT, d, "**", "*.rb")) }.flatten.sort
    assert_operator files.length, :>, 300, "the sweep reaches the mod's files"
    trees = parse(files.map { |f| [f.sub(ROOT + "/", ""), File.read(f)] })
    assert_equal [], trees.select { |_path, sexp| sexp.nil? }.map { |path, _sexp| path }, "Ripper parses every file"
    assert_operator yielders(trees).length, :>=, 5, "the sweep finds the methods that yield several values"
    assert_equal [], violations(trees), "every block of a method that yields several values takes as many"
  end

  test "reports a one-parameter brace or do block given to a method that yields two values" do
    src = <<-RUBY
    module Probe
      def self.probe_pairs; yield(1, 2); end
    end
    Probe.probe_pairs { |a| a }
    Probe.probe_pairs do |a|
      a
    end
    Probe.probe_pairs(3) { |a| a }
    RUBY
    assert_equal ["probe.rb:4 probe_pairs", "probe.rb:5 probe_pairs", "probe.rb:8 probe_pairs"],
                 violations(parse([["probe.rb", src]]))
  end

  test "reports a one-parameter block for a splat yield and for an instance method that yields two" do
    src = <<-RUBY
    module Probe
      def self.probe_spread(*a); yield(*a); end
    end
    class ProbeBox
      def probe_both; yield 1, 2; end
    end
    Probe.probe_spread { |a| a }
    box.probe_both { |a| a }
    RUBY
    assert_equal ["probe.rb:7 probe_spread", "probe.rb:8 probe_both"], violations(parse([["probe.rb", src]]))
  end

  test "spares blocks that take every value, destructure them or keep the rest" do
    src = <<-RUBY
    module Probe
      def self.probe_pairs; yield(1, 2); end
    end
    Probe.probe_pairs { |a, b| a }
    Probe.probe_pairs { |(a, b)| a }
    Probe.probe_pairs { |a, *rest| a }
    Probe.probe_pairs { |a,| a }
    Probe.probe_pairs { |*all| all }
    Probe.probe_pairs { a }
    RUBY
    assert_equal [], violations(parse([["probe.rb", src]]))
  end

  test "spares a one-parameter block for a single-value yield and for Ruby's own collection methods" do
    src = <<-RUBY
    module Probe
      def self.probe_single; yield(1); end
      def self.each; yield(1, 2); end
    end
    Probe.probe_single { |a| a }
    Probe.each { |a| a }
    RUBY
    assert_equal [], violations(parse([["probe.rb", src]]))
  end

  test "matches the yielding method across files, by name" do
    defs = "module Probe\n  def self.probe_pairs; yield(1, 2); end\nend\n"
    assert_equal ["b.rb:1 probe_pairs"], violations(parse([["a.rb", defs], ["b.rb", "Probe.probe_pairs { |a| a }\n"]]))
  end

  private

  # Each node of a Ripper tree, depth first.
  def walk(node, &blk)
    return unless node.is_a?(Array)
    yield node if node[0].is_a?(Symbol)
    node.each { |n| walk(n, &blk) }
  end

  # How many values a yield node passes (99 for a splat), or 0.
  def yield_count(node)
    return 0 unless node[0] == :yield
    args = node[1]
    args = args[1] if args.is_a?(Array) && args[0] == :paren
    args = args[1] if args.is_a?(Array) && args[0] == :args_add_block
    return 0 unless args.is_a?(Array)
    return 99 if args.any? { |a| a.is_a?(Array) && a[0] == :args_add_star }
    args.length
  end

  # [name, line] of the method a call node calls, or nil.
  def called(call)
    case call[0]
    when :method_add_arg then called(call[1])
    when :call, :command_call then ident(call[3])
    when :fcall, :command, :vcall then ident(call[1])
    end
  end

  # [name, line] of an identifier node, or nil.
  def ident(n)
    n.is_a?(Array) && n[0] == :@ident ? [n[1], n[2][0]] : nil
  end

  # True when a block node takes exactly one plain parameter.
  def one_plain_param?(block)
    var = block[1]
    return false unless var.is_a?(Array) && var[0] == :block_var
    params = var[1]
    req = params[1] || []
    rest = [params[2], params[3], params[4]].compact.reject { |x| x.is_a?(Array) && x.empty? }
    req.length == 1 && req[0].is_a?(Array) && req[0][0] == :@ident && rest.empty?
  end

  # The [path, text] sources as [path, Ripper tree], the tree nil for a file Ripper cannot parse.
  def parse(sources)
    sources.map { |path, text| [path, Ripper.sexp(text)] }
  end

  # The names of the methods whose bodies yield two or more values, from the parsed sources.
  def yielders(trees)
    out = {}
    trees.each do |_path, sexp|
      walk(sexp) do |n|
        next unless n[0] == :def || n[0] == :defs
        name = n[0] == :def ? n[1][1] : n[3][1]
        walk(n) { |m| out[name] = true if yield_count(m) >= 2 }
      end
    end
    out
  end

  # Calls of those methods with a one-plain-parameter block, as "path:line name".
  def violations(trees)
    names = yielders(trees)
    out = []
    trees.each do |path, sexp|
      walk(sexp) do |n|
        next unless n[0] == :method_add_block && one_plain_param?(n[2])
        hit = called(n[1])
        next unless hit && names[hit[0]] && !STD.include?(hit[0])
        out.push("#{path}:#{hit[1]} #{hit[0]}")
      end
    end
    out
  end
end
