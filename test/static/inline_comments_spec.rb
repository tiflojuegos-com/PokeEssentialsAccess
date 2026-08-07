# No comment lives inside a method body.
#
# The project's rule is a brief header per non-trivial method or class and nothing inside: if a line needs
# explaining, the explanation belongs where a reader looking for it will find it, above the method, not
# buried at the statement it happens to sit next to. Getting the tree to zero took clearing 99 lines out of
# 23 core files by hand, which is precisely the kind of work worth not repeating.
#
# Full-line comments only. A trailing comment on a line of code would also break the rule, but telling one
# apart from a # inside a string, a regex or an interpolation needs a real parser, and the tree has none
# today -- a check that misfires on a regex would be worse than the gap it closes.
#
# Bodies are found by indentation: a def at column N ends at the first line that is exactly N spaces and
# "end". Nested blocks close deeper, so they never end the def early, and the whole codebase is uniformly
# two-space indented (a file that was not would report its methods as unclosed and simply not be scanned).
Suite.define("static: no comment sits inside a method body") do
  root = File.expand_path("../..", File.dirname(__FILE__))
  files = %w[core games plugins].map { |d| Dir.glob(File.join(root, d, "**", "*.rb")) }.flatten.sort

  offenders = []
  files.each do |f|
    lines = File.read(f).split("\n")
    inside = {}
    lines.each_with_index do |raw, i|
      m = raw.match(/^(\s*)def\b/)
      next if m.nil? || raw =~ /;\s*end\s*$/
      closer = m[1] + "end"
      j = i + 1
      while j < lines.length
        break if lines[j].rstrip == closer
        j += 1
      end
      next if j >= lines.length
      ((i + 1)...j).each { |n| inside[n] = true }
    end
    inside.keys.sort.each do |n|
      next unless lines[n].strip[0, 1] == "#"
      offenders.push("#{f.sub(root + "/", "").sub(root + "\\", "")}:#{n + 1}")
    end
  end

  eq("every explanation lives on its method's header", offenders[0, 12], [])
  truthy("the sweep found methods to scan (#{files.length} files)", files.length > 180)
end
