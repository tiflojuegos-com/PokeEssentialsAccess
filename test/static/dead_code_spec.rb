# No module method is defined and never called.
#
# A `def self.x` nobody references is not harmless: it is read, maintained and trusted as if it ran. Two had
# accumulated by 0.4.6, both from the first version (a hidden-objects iterator, and a teleporter-pattern
# registrar no profile could reach until the DSL exposed it), and nothing but a sweep would ever have said
# so. References are counted as bare word matches across core, games, plugins, loader and test, which is
# what keeps this cheap and parser-free; a method reached only through a name built at runtime
# (send("#{k}=")) leaves no bare word to match and belongs in the skip list below, next to the names every
# object answers.
Suite.define("static: every module method is referenced somewhere") do
  root = File.expand_path("../..", File.dirname(__FILE__))
  src = %w[core games plugins loader].map { |d| Dir.glob(File.join(root, d, "**", "*.rb")) }.flatten.sort
  corpus = (src + Dir.glob(File.join(root, "test", "**", "*.rb"))).map { |f| [f, File.read(f).split("\n")] }
  dynamic = %w[initialize call to_s inspect]

  defs = []
  src.each do |f|
    File.read(f).split("\n").each_with_index do |l, i|
      defs.push([$1, f, i + 1]) if l =~ /^\s*def\s+self\.([a-zA-Z_][A-Za-z0-9_]*[?!=]?)/
    end
  end

  unused = []
  defs.each do |name, file, line|
    next if dynamic.include?(name)
    bare = Regexp.escape(name.sub(/=\z/, ""))
    re = /(?:^|[^A-Za-z0-9_@$])#{bare}(?![A-Za-z0-9_])/
    hit = corpus.any? do |cf, lines|
      lines.each_with_index.any? { |l, i| !(cf == file && i + 1 == line) && l =~ re }
    end
    unused.push("#{file.sub(root + "/", "")}:#{line} #{name}") unless hit
  end

  eq("no module method is defined and never referenced", unused[0, 12], [])
  truthy("the sweep found methods to check (#{defs.length})", defs.length > 1500)
end
