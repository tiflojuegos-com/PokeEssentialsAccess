# Builds field_move_census.txt (field_moves_test) from the decompiled dumps, which are absent on CI: every definition
# of the functions a game clears its obstacles and crosses water with, where it is, the guard of Marin's HM Items it
# sits under, the functions of its own family it calls (a wrapper's original, the rv engine's dialogue) and the names
# its body reads. Run by hand after adding or refreshing a dump:
#   ruby test/static/build_field_move_census.rb ["path\to\decompiled Scripts"]
DEFAULT_DUMPS = File.expand_path("../../../../decompiled Scripts", File.dirname(__FILE__))
OUT = File.join(File.dirname(__FILE__), "field_move_census.txt")
FUNCTIONS = %w[pbCut pbRockSmash pbStrength pbSurf pbWaterfall pbWaterfallDialogue pbDive].freeze
DEF_RE = /^(\s*)def\s+(?:self\.|Kernel\.)?(#{FUNCTIONS.join('|')})\b/

dumps = ARGV[0] || ENV["PA_DUMPS"] || DEFAULT_DUMPS
unless File.directory?(dumps)
  puts "dumps folder not found: #{dumps}"
  puts "usage: ruby test/static/build_field_move_census.rb [path-to-decompiled-Scripts]"
  exit 1
end

# The body of the definition starting at lines[i]: up to the end at its own indentation, or the line alone for a
# one-line definition.
def body_of(lines, i, indent)
  return [lines[i]] if lines[i] =~ /;\s*end\s*\z/
  body = [lines[i]]
  lines[(i + 1)..-1].each do |l|
    body.push(l)
    break if l =~ /^#{indent}end\b/
  end
  body
end

# The USING_<MOVE>_ITEM switch of Marin's HM Items a nested definition sits under, or nil.
def guard_of(lines, i, indent)
  return nil if indent.empty?
  (i - 1).downto(0) do |j|
    l = lines[j]
    next if l.strip.empty?
    own = l[/^\s*/]
    next if own.length >= indent.length
    return l[/^\s*if\s+(USING_\w+_ITEM)\b/, 1]
  end
  nil
end

# The upper-case names a body reads (symbols and PB constants, past its comments and its "::" scopes) and the
# switches it tests, as "switch:<id>".
def names_of(body)
  code = body.reject { |l| l.strip.start_with?("#") }.join("\n")
  names = code.scan(/\bPB(?:Items|Moves)::([A-Z][A-Z0-9_]*)/).flatten
  names += code.scan(/(?<![:\w]):([A-Z][A-Z0-9_]+)\b/).flatten
  names += code.scan(/\$game_switches\[\s*:?([\w:]+)\s*\]/).flatten.map { |s| "switch:#{s}" }
  names.uniq.sort
end

rows = []
Dir.glob(File.join(dumps, "*")).select { |d| File.directory?(d) && File.basename(d) !~ /\A\./ }.sort.each do |dir|
  dump = File.basename(dir)
  Dir.glob(File.join(dir, "**", "*.rb")).sort.each do |f|
    raw = File.binread(f)
    next unless raw =~ /def\s+(?:self\.|Kernel\.)?(?:#{FUNCTIONS.join('|')})\b/
    lines = raw.force_encoding("UTF-8").scrub("?").split("\n")
    skipping = false
    lines.each_with_index do |l, i|
      skipping = true if l.start_with?("=begin")
      skipping = false if l.start_with?("=end")
      next if skipping
      m = l.match(DEF_RE)
      next unless m
      body = body_of(lines, i, m[1])
      calls = body[1..-1].to_a.join("\n").scan(/\b(\w*(?:#{FUNCTIONS.join('|')})\w*)\b/).flatten.uniq.sort - [m[2]]
      rel = f[(dir.length + 1)..-1].tr("\\", "/")
      rows.push([dump, m[2], "#{rel}:#{i + 1}", guard_of(lines, i, m[1]).to_s, calls.join(","), names_of(body).join(",")])
    end
  end
end

File.open(OUT, "wb") do |out|
  out.write("# dump|function|where|guard|calls|names; built by build_field_move_census.rb, do not edit by hand\n")
  rows.sort.each { |r| out.write(r.join("|") + "\n") }
end
puts "#{rows.length} definitions from #{rows.map { |r| r[0] }.uniq.length} dumps -> #{OUT}"
