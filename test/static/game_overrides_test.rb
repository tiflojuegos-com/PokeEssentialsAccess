# The mod (core/, games/, plugins/, loader/) calls none of the core methods some games redefine: Luka's Scripting
# Utilities make Hash#has_key? false for a nil or false value (Anil, Royal, Relict) and an older copy scans every key
# (Emerald), while Hash#key? is untouched; Marin's give Array a to_hash by index, which Hash[pairs] takes over the
# pairs (Anil, Awakening, Relict, Z's MTS); Armonia's merge writes into the receiver and its Array#first/last take an
# index and answer a boolean, and Africanus' and Awakening's take no count at all; nine games' String#capitalize leaves
# the rest of the word as it is and fails on an empty string.
class GameOverridesTest < PokeAccessTest
  ROOT = File.expand_path("../..", File.dirname(__FILE__))
  BANNED = [[/\.has_key\?/, "has_key? (use key?)"],
            [/\bHash\[/, "Hash[] (build the hash by hand)"],
            [/\.merge\b(?!!)/, "merge (use dup.merge!)"],
            [/\.(first|last)\(/, "first(n)/last(n) (slice with [])"],
            [/\.capitalize\b/, "capitalize (use Util.capitalized)"]].freeze

  test "calls none of the methods a game redefines" do
    sources = %w[core games plugins loader].map { |d| Dir.glob(File.join(ROOT, d, "**", "*.rb")) }.flatten.sort
    assert_operator sources.length, :>, 300, "the sweep reaches the mod's files"
    tree = sources.map { |f| [f.sub(ROOT + "/", ""), File.read(f)] }
    assert_equal [], violations(tree)
  end

  test "reports each banned call with its file, line and the way around it" do
    {
      "ok = h.has_key?(:a)" => "has_key? (use key?)",
      "h = Hash[pairs]" => "Hash[] (build the hash by hand)",
      "both = a.merge(b)" => "merge (use dup.merge!)",
      "top = list.first(3)" => "first(n)/last(n) (slice with [])",
      "tail = list.last(2)" => "first(n)/last(n) (slice with [])",
      "name = word.capitalize" => "capitalize (use Util.capitalized)"
    }.each do |line, what|
      assert_equal ["core/x.rb:2 #{what}"], violations([["core/x.rb", "a = 1\n#{line}\n"]]), "for #{line.inspect}"
    end
  end

  test "spares the safe spellings and comment lines" do
    lines = ["ok = h.key?(:a)", "both = a.dup.merge!(b)", "a.merge!(b)", "top = list.first", "tail = list[-2, 2]",
             "h = {}", "  # h.has_key?(:a) and Hash[pairs] read here", "list.first_unseen(1)"]
    assert_equal [], violations([["core/x.rb", lines.join("\n")]])
  end

  private

  # Each "path:line what" where a code line of the [path, text] sources calls a banned method.
  def violations(sources)
    out = []
    sources.each do |path, text|
      text.split("\n").each_with_index do |line, i|
        next if line.strip.start_with?("#")
        BANNED.each { |re, what| out.push("#{path}:#{i + 1} #{what}") if line =~ re }
      end
    end
    out
  end
end
