# No module method (def self.x) is defined and never referenced: bare word matches across core, games, plugins,
# loader and test; a name only built at runtime (send("#{k}=")) goes in the skip list.
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
