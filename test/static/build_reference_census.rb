# Builds reference_census.txt from the reference copies of third-party plugins that no surveyed game ships (each
# PokéLiberty resource, each FL repository and each Eevee Expo resource under repositorios genericos/_refmods, absent
# on CI): the classes, "Class#method" names and instance variables they define. Read by hooked_classes_test,
# ivars_test and plugins_test, which let a reader only the generic profile loads name what these copies define. Run by
# hand after adding a copy:
#   ruby test/static/build_reference_census.rb ["path\to\_refmods"]
require File.expand_path("reader_sites", File.dirname(__FILE__))

DEFAULT_REFMODS = File.expand_path("../../../../../repositorios genericos/_refmods", File.dirname(__FILE__))
OUT = File.join(File.dirname(__FILE__), "reference_census.txt")
# The collections surveyed, and where each source keeps its code inside its folder.
COLLECTIONS = { "pokeliberty" => "files", "FL-essentials" => ".", "eeveeexpo" => "." }
SKIP_FILE = /\A(readme|license|meta)\b/i
SHOWN = 3

refmods = (ARGV[0] if ARGV[0] && !ARGV[0].empty?) || ENV["PA_REFERENCE"] || DEFAULT_REFMODS
unless File.directory?(refmods)
  puts "reference folder not found: #{refmods}"
  puts "usage: ruby test/static/build_reference_census.rb [path-to-_refmods]"
  exit 1
end

sources = {}
COLLECTIONS.each do |coll, sub|
  Dir.glob(File.join(refmods, coll, "*")).sort.each do |dir|
    next unless File.directory?(dir)
    code = File.join(dir, sub)
    sources["#{coll}/#{File.basename(dir)}"] = code if File.directory?(code)
  end
end
if sources.empty?
  puts "no reference sources under #{refmods}"
  exit 1
end

# Read binary (the copies carry Latin-1 and UTF-8 alike); =begin/=end blocks and full-line comments are skipped.
names = {}
note = lambda { |key, src| ((names[key] ||= {}))[src] = true }
sources.each do |src, dir|
  Dir.glob(File.join(dir, "**", "*.{rb,txt}")).sort.each do |f|
    next if f.tr("\\", "/").include?("/.git/") || File.basename(f) =~ SKIP_FILE
    stack = ReaderSites::ClassStack.new
    in_comment = false
    File.open(f, "rb") do |io|
      io.each_line do |line|
        if in_comment
          in_comment = false if line =~ /^=end\b/
          next
        end
        if line =~ /^=begin\b/
          in_comment = true
          next
        end
        next if line =~ /^\s*#/
        cur = stack.feed(line)
        note.call("class:#{$1.split('::').last}", src) if line =~ /^\s*(?:class|module)\s+([A-Z][A-Za-z0-9_:]*)/
        note.call("method:Object##{$1}", src) if line =~ /^def\s+([a-z_][A-Za-z0-9_]*[?!]?)(?=[\s(;]|\z)/
        if cur && line =~ /^(\s*)def\s+(?:self\.)?([a-zA-Z_][A-Za-z0-9_]*[?!]?)(?![=\w])/
          note.call("method:#{stack.owner_at($1.length) || cur}##{$2}", src)
        end
        if cur && (m = line.match(/^(\s*)attr_(?:reader|accessor)\s+(.+)/))
          owner = stack.owner_at(m[1].length) || cur
          m[2].scan(/:([a-zA-Z_][A-Za-z0-9_]*[?!]?)/) { |a| note.call("method:#{owner}##{a[0]}", src) }
        end
        line.scan(/@([a-z_][A-Za-z0-9_]*)/) { |v| note.call("ivar:#{v[0]}", src) }
      end
    end
  end
end

File.open(OUT, "wb") do |io|
  io.print("# Census of the reference copies of third-party plugins no surveyed game ships, for the readers only the\n")
  io.print("# generic profile loads: what each copy defines. Read by hooked_classes_test, ivars_test and plugins_test.\n")
  io.print("# Regenerate with test/static/build_reference_census.rb (see its header). Do not edit by hand.\n")
  io.print("# format: class:<Name> | method:<Class#method> | ivar:<name> = <source>, ... (the first #{SHOWN}, then +N)\n")
  io.print("# reference sources (#{sources.length}): #{COLLECTIONS.keys.join(', ')}\n")
  names.keys.sort.each do |key|
    srcs = names[key].keys.sort
    shown = srcs.first(SHOWN).join(", ")
    shown += ", +#{srcs.length - SHOWN}" if srcs.length > SHOWN
    io.print("#{key} = #{shown}\n")
  end
end

puts "wrote #{OUT}: #{names.length} names from #{sources.length} reference sources"
