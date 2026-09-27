# Builds test/static/arity_census.txt from the decompiled dumps (outside the repo, absent on CI): for every hooked
# method, the min and max parameter count across the games (a splat or block parameter makes it open ended) and
# the distinct signatures they declare. Run: ruby test/static/build_arity_census.rb ["path\to\decompiled Scripts"]
require "find"
require File.expand_path("reader_sites", File.dirname(__FILE__))

DEFAULT_DUMPS = File.expand_path("../../../../decompiled Scripts", File.dirname(__FILE__))
ROOT = File.expand_path("../..", File.dirname(__FILE__))
OUT = File.join(File.dirname(__FILE__), "arity_census.txt")

dumps = ARGV[0] || ENV["PA_DUMPS"] || DEFAULT_DUMPS
unless File.directory?(dumps)
  puts "usage: ruby test/static/build_arity_census.rb [path-to-decompiled-Scripts]"
  puts "not a directory: #{dumps}"
  exit 1
end

# The parameters of one "def" line split at depth zero, so a default holding a comma stays whole.
def split_params(params)
  return [] if params.nil? || params.strip.empty?
  depth = 0
  parts = [""]
  params.each_char do |ch|
    case ch
    when "(", "[", "{" then depth += 1; parts[-1] << ch
    when ")", "]", "}" then depth -= 1; parts[-1] << ch
    when ","           then depth > 0 ? parts[-1] << ch : parts.push("")
    else                    parts[-1] << ch
    end
  end
  parts.map { |p| p.strip }.reject { |p| p.empty? }
end

# The parameter count of one "def" line: [count, open_ended]. A splat or a block parameter makes it open.
def arity_of(params)
  parts = split_params(params)
  [parts.length, parts.any? { |p| p =~ /\A[*&]/ }]
end

# The parameter names of one "def" line, defaults dropped and a splat or block kept with its marker, joined
# with commas: "helptext,commands,index" -- the signature the census prints for a game.
def names_of(params)
  split_params(params).map { |p| p.sub(/\s*=.*\z/, "").sub(/:\s*.*\z/, "").sub(/\A\*\*/, "*").strip }.join(",")
end

VANILLA = File.expand_path("../../../../pokemon-essentials/Data/Scripts", File.dirname(__FILE__))

wanted = ReaderSites.hooked_pairs
seen = {}
games = []
supers = {}
defs = {}
wanted_names = {}
wanted.keys.each { |k| wanted_names[k.split("#", 2)[1]] = true }

# Files one game's definition of a hooked method under its row: the arity range, the signature and the game.
credit = lambda do |key, n, open, names, g|
  row = (seen[key] ||= { :min => nil, :max => 0, :open => false, :games => [], :sigs => [] })
  row[:min] = n if row[:min].nil? || n < row[:min]
  row[:max] = n if n > row[:max]
  row[:open] = true if open
  row[:games].push(g) unless row[:games].include?(g)
  row[:sigs].push(names) unless row[:sigs].include?(names) || row[:sigs].length >= 4
end

# Every dump folder plus the stock Essentials tree, which the other censuses count too. Each class is keyed by its
# full owner path, or the bare leaf for a top-level class, so a nested class is not taken for a namesake; attr_*
# lines define methods too (a getter of arity 0, a setter of 1).
sources = {}
Dir.entries(dumps).sort.each do |g|
  next if g.start_with?(".")
  path = File.join(dumps, g)
  sources[g] = path if File.directory?(path)
end
vanilla = ENV["PA_VANILLA"] || VANILLA
if File.directory?(vanilla)
  sources["vanilla"] = vanilla
else
  puts "note: vanilla Essentials tree not found at #{vanilla}"
end

sources.keys.sort.each do |g|
  path = sources[g]
  games.push(g)
  Find.find(path) do |f|
    next unless f =~ /\.rb\z/i
    src = (File.open(f, "rb") { |h| h.read } rescue nil)
    next if src.nil?
    src = src.gsub(/[^\t\n\r -~]/n, "?")
    stack = ReaderSites::ClassStack.new
    src.each_line do |line|
      stack.feed(line)
      if line =~ /^\s*class\s+([A-Z][A-Za-z0-9_:]*)\s*<\s*([A-Z][A-Za-z0-9_:]*)/
        (supers[g] ||= {})[$1.split("::").last] = $2.split("::").last
      end
      found = []
      if line =~ /^(\s*)def\s+(?:self\.)?([a-zA-Z_][A-Za-z0-9_?!]*=?)\s*(?:\((.*?)\))?\s*(?:;|#|$)/
        found << [$1.length, $2, $3]
      elsif line =~ /^(\s*)attr_(accessor|reader|writer)\s+(.+)$/
        ind, kind = $1.length, $2
        $3.scan(/:([a-zA-Z_][A-Za-z0-9_]*)/).flatten.each do |nm|
          found << [ind, nm, nil] unless kind == "writer"
          found << [ind, "#{nm}=", "v"] unless kind == "reader"
        end
      end
      found.each do |indent, meth, params|
        full = stack.owner_path_at(indent)
        next if full.nil?
        leaf = stack.owner_at(indent)
        n, open = arity_of(params)
        names = names_of(params)
        ((defs[g] ||= {})["#{leaf}##{meth}"] ||= [n, open, names]) if wanted_names[meth]
        key = "#{full}##{meth}"
        key = "#{leaf}##{meth}" if !wanted.has_key?(key) && stack.owner_depth_at(indent) == 1
        next unless wanted.has_key?(key)
        credit.call(key, n, open, names, g)
      end
    end
  end
end

# An inherited hooked method is credited too, walked by leaf name up each game's superclass lines, the way
# Engine.has? answers through inheritance.
wanted.keys.each do |key|
  cls, meth = key.split("#", 2)
  leaf = cls.split("::").last
  games.each do |g|
    next if seen[key] && seen[key][:games].include?(g)
    anc = (supers[g] || {})[leaf]
    hops = 0
    while anc && hops < 12
      if (hit = (defs[g] || {})["#{anc}##{meth}"])
        credit.call(key, hit[0], hit[1], hit[2], g)
        break
      end
      anc = supers[g][anc]
      hops += 1
    end
  end
end

File.open(OUT, "w") do |f|
  f.write("# GENERATED by test/static/build_arity_census.rb -- do not edit by hand.\n")
  f.write("#\n")
  f.write("# How many arguments each hooked method really takes in the games that define it, so a reader\n")
  f.write("# that indexes args[N] can be checked against what any game passes. See the builder's header.\n")
  f.write("# format: <Class#method> = <min>,<max>,<open ? 1 : 0>,<how many games define it>;<signature>|<signature>...\n")
  f.write("# a signature is the parameter names of one game's def, defaults dropped (at most four distinct ones)\n")
  f.write("# surveyed games (#{games.length}): #{games.join(', ')}\n")
  f.write("# hooked pairs: #{wanted.length} / found in some game: #{seen.length}\n")
  seen.keys.sort.each do |k|
    r = seen[k]
    f.write("#{k} = #{r[:min]},#{r[:max]},#{r[:open] ? 1 : 0},#{r[:games].length};#{r[:sigs].join('|')}\n")
  end
end
puts "wrote #{OUT}: #{seen.length} of #{wanted.length} hooked pairs found in #{games.length} sources"
