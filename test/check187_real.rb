# Syntax-checks every dual/gen-6 file with a REAL Ruby 1.8.7 interpreter -- run BY that interpreter
# (check187.py finds it and invokes this; see there). The pattern checker knows the constructs it was
# taught; the real parser knows them all, which is what caught nothing the day a leading-dot chain
# silenced footsteps. Parsing without executing: eval with a BEGIN{throw} -- BEGIN runs first, so the
# whole file is PARSED (SyntaxError surfaces) but its body never evaluates. The eval is safe by
# construction: it only ever receives THIS repo's own source files (a dev-machine syntax check, no
# external input), and the BEGIN throw aborts before any of it runs; 1.8.7 has no ripper/RubyVM
# alternative, so eval IS the syntax checker here.
# The MODERN skip list mirrors check187.py's -- keep both in sync.
MODERN = ["/v21/", "/v22/", "/skyflyer/", "games/anil/", "games/royal/", "games/relict/",
          "games/infinitefusion_hoenn/", "games/infinitefusion/"]

root = (ARGV[0] || File.expand_path(File.join(File.dirname(__FILE__), ".."))).gsub("\\", "/")
files = Dir[File.join(root, "core", "**", "*.rb")] +
        Dir[File.join(root, "games", "**", "*.rb")] +
        # plugins/ is NOT in MODERN and must not be: a third-party plugin can be installed in a gen-6
        # fangame, so its reader has to parse under 1.8.7 like the core does.
        Dir[File.join(root, "plugins", "**", "*.rb")] +
        Dir[File.join(root, "loader", "*.rb")]

bad = []
n = 0
files.each do |f|
  rel = f.gsub("\\", "/")
  next if MODERN.any? { |m| rel.include?(m) }
  n += 1
  src = File.open(f, "rb") { |io| io.read }
  begin
    catch(:pea_syntax_ok) { eval("BEGIN { throw :pea_syntax_ok }; #{src}", TOPLEVEL_BINDING, f) }
  rescue SyntaxError => e
    bad.push(e.message)
  rescue Exception
  end
end

if bad.empty?
  puts "OK: #{n} files parse under real Ruby #{RUBY_VERSION}"
else
  puts "REAL 1.8.7 SYNTAX ERRORS:"
  bad.each { |m| puts "  #{m}" }
  exit 1
end
