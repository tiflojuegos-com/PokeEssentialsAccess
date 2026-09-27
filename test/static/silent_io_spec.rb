# A method that reads or writes a file and rescues at its own level leaves a trace (a log line, a speak or a
# raise); the marker writers are the exceptions (the mod's, and Uranium's compat script's, which runs before the mod
# has a log), loader/ is out of scope, and one-line defs are skipped.
Suite.define("static: a method that touches a file logs its failure") do
  root = File.expand_path("../..", File.dirname(__FILE__))
  files = %w[core games plugins].map { |d| Dir.glob(File.join(root, d, "**", "*.rb")) }.flatten.sort
  io = /\b(File\.(open|read|readlines|foreach|write|delete|rename|binread|unlink)|KVFile\.each|Marshal\.load|IO\.(write|read))\b/
  logs = /log_once|write_marker|log3d|log_body_failure|PokeAccess\.speak|\braise\b/
  allowed = ["core/speech/markers.rb write_marker", "games/uranium/compat.rb note"]

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
