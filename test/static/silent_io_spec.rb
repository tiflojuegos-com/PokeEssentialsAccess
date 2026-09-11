# A method that touches a file does not swallow its failure in silence. Readers rescue everything on
# purpose, but persistence is different: a settings.ini in a read-only folder or a tags file the game cannot
# write failed without a trace until 0.4.6, and the player learned of it by losing their markers. So a
# method whose body reads or writes a file and rescues at its own level must leave a line (log_once,
# write_marker), speak, or re-raise; the marker writer itself is the one allowed exception, and loader/ is
# outside the rule because it runs before PokeAccess exists and keeps its own error file. One-line defs are
# skipped on their own: they close on the def line, and matching them to the next method's end fused it in.
Suite.define("static: a method that touches a file logs its failure") do
  root = File.expand_path("../..", File.dirname(__FILE__))
  files = %w[core games plugins].map { |d| Dir.glob(File.join(root, d, "**", "*.rb")) }.flatten.sort
  io = /\b(File\.(open|read|readlines|foreach|write|delete|rename|binread|unlink)|KVFile\.each|Marshal\.load|IO\.(write|read))\b/
  logs = /log_once|write_marker|log3d|log_body_failure|PokeAccess\.speak|\braise\b/
  allowed = ["core/speech/markers.rb write_marker"]

  silent = []
  defs = 0
  files.each do |f|
    lines = File.read(f).split("\n")
    i = 0
    while i < lines.length
      m = lines[i].match(/^(\s*)def\s+(?:self\.)?([a-zA-Z_][A-Za-z0-9_]*[?!=]?)/)
      if m.nil? || lines[i] =~ /;\s*end\s*$/
        i += 1
        next
      end
      defs += 1
      ind = m[1].length
      j = i + 1
      j += 1 while j < lines.length && lines[j] !~ /^\s{#{ind}}end\b/
      body = lines[(i + 1)...j]
      r = body.index { |l| l =~ /^\s{#{ind}}rescue\b/ }
      if r && body.any? { |l| l =~ io } && body[r..-1].none? { |l| l =~ logs }
        tag = "#{f.sub(root + "/", "")} #{m[2]}"
        silent.push("#{tag}:#{i + 1}") unless allowed.include?(tag)
      end
      i = j + 1
    end
  end

  eq("every file-touching method that rescues also leaves a trace", silent, [])
  truthy("the sweep found files to scan (#{files.length})", files.length > 180)
  truthy("and opened the multi-line methods in them one by one (#{defs})", defs > 1200)
end
