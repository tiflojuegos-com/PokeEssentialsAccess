# Syntax-checks every dual and gen-6 file under a real Ruby 1.8.7 (check187.py finds it and runs this). Each file is
# parsed, never run: eval with a BEGIN{throw} aborts before the body evaluates. The eval only receives this repo's own
# source files, and 1.8.7 has no ripper, so eval is the syntax checker here.
# MODERN mirrors check187.py's (mts_mutator_guard_spec pins both to the catalog). plugins/ stays out of it: a plugin
# can be installed in a gen-6 fangame.
MODERN =["games/anil/", "games/fireash/", "games/royal/", "games/relict/", "games/soulstones2/",
          "games/infinitefusion_hoenn/", "games/infinitefusion/", "games/infinitefusion_common/",
          "games/emerald/", "games/skyflyer_common/"]

root = (ARGV[0] || File.expand_path(File.join(File.dirname(__FILE__), ".."))).gsub("\\", "/")
files = Dir[File.join(root, "core", "**", "*.rb")] +
        Dir[File.join(root, "games", "**", "*.rb")] +
        Dir[File.join(root, "plugins", "**", "*.rb")] +
        Dir[File.join(root, "loader", "**", "*.rb")]

bad = []
seen = {}
n = 0
files.each do |f|
  rel = f.gsub("\\", "/")
  next if MODERN.any? { |m| rel.include?(m) }
  n += 1
  seen[rel] = true
  src = File.open(f, "rb") { |io| io.read }
  begin
    catch(:pea_syntax_ok) { eval("BEGIN { throw :pea_syntax_ok }; #{src}", TOPLEVEL_BINDING, f) }
  rescue SyntaxError => e
    bad.push(e.message)
  rescue Exception
  end
end

# The floor, so a broken glob cannot pass: every core/manifest.rb entry, which the loader evaluates in every game,
# must have been parsed.
missing = []
mf = File.join(root, "core", "manifest.rb")
entries = File.exist?(mf) ? (eval(File.read(mf)) rescue nil) : nil
unless entries.is_a?(Array) && !entries.empty?
  puts "REAL 1.8.7 SWEEP INCOMPLETE: core/manifest.rb missing or unreadable at #{mf}"
  exit 1
end
entries.each do |entry|
  rel = File.join(root, "core", "#{entry}.rb").gsub("\\", "/")
  missing.push(entry) unless seen[rel]
end

if !missing.empty?
  puts "REAL 1.8.7 SWEEP INCOMPLETE: #{missing.length} core/manifest.rb entries never parsed"
  missing.first(10).each { |m| puts "  #{m}" }
  exit 1
elsif bad.empty?
  puts "OK: #{n} files parse under real Ruby #{RUBY_VERSION} (#{seen.length} reached, manifest covered)"
else
  puts "REAL 1.8.7 SYNTAX ERRORS:"
  bad.each { |m| puts "  #{m}" }
  exit 1
end
