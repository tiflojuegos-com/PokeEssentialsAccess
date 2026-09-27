# No full-line comment sits inside a def or a hook block (after, before, around, override, wrap_global, wrap_kernel or
# Hooks.<name> whose line ends in "do") in core, games, plugins, loader or tools; trailing ones would need a parser.
# A body ends at the first line at the opener's indentation plus "end", "end if/unless ..." or "end)".
Suite.define("static: no comment sits inside a method body") do
  root = File.expand_path("../..", File.dirname(__FILE__))
  files = %w[core games plugins loader tools].map { |d| Dir.glob(File.join(root, d, "**", "*.rb")) }.flatten.sort

  opener_indent = lambda do |raw|
    if raw =~ /^(\s*)def\b/
      $1
    elsif raw =~ /^(\s*)(?:after|before|around|override|wrap_global|wrap_kernel)\(/ ||
          raw =~ /^(\s*)(?:PokeAccess::Hooks|Hooks)\.[A-Za-z_][A-Za-z0-9_]*\(/
      indent = $1
      raw.rstrip =~ /do(\s*\|[^|]*\|)?\z/ ? indent : nil
    end
  end

  offenders = []
  files.each do |f|
    lines = File.read(f).split("\n")
    inside = {}
    lines.each_with_index do |raw, i|
      indent = opener_indent.call(raw)
      next if indent.nil? || raw =~ /;\s*end\s*$/
      closer = /\A#{Regexp.escape(indent)}end(?:\s+(?:if|unless)\s+\S.*|\))?\z/
      j = i + 1
      while j < lines.length
        break if lines[j].rstrip =~ closer
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

  eq("every explanation lives on its method's or hook's header", offenders[0, 12], [])
  truthy("the sweep found files to scan (#{files.length} files)", files.length > 400)
end
