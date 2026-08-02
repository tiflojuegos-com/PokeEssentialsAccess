# The cost of a deliberate twin (see static/twins.rb for the list and the why) is that someone fixes one
# copy and forgets the other, and nothing complains: the second game silently keeps the old bug. This turns
# that into a failing test -- the copies must match on everything except each one's own profile name.
require File.expand_path(File.join(File.dirname(__FILE__), "twins"))

Suite.define("static: twinned profile readers stay identical across their games") do
  root = File.expand_path(File.join(File.dirname(__FILE__), "..", ".."))

  # The file with its own profile name blanked out, so the copies compare equal on everything that matters.
  normalize = lambda do |path|
    profile = path.split("/")[1]
    text = File.read(File.join(root, path))
    text.gsub(profile, "<PROFILE>").split("\n")
  end

  TWINS.each do |group|
    missing = group.reject { |p| File.file?(File.join(root, p)) }
    eq "every declared twin exists on disk (#{group.join(', ')})", missing, []
    next unless missing.empty?

    base = normalize.call(group[0])
    group[1..-1].each do |other|
      lines = normalize.call(other)
      first = nil
      [base.length, lines.length].max.times do |i|
        if base[i] != lines[i]
          first = "linea #{i + 1}: #{group[0]} dice #{base[i].inspect}, #{other} dice #{lines[i].inspect}"
          break
        end
      end
      eq "#{other} sigue siendo gemelo de #{group[0]} (si divergen, uno se quedo sin el arreglo)",
         first, nil
    end
  end
end
