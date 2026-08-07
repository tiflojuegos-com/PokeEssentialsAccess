# Every shipped .rb parses.
#
# The runner loads core plus ONE profile (pokemon_z for gen6, anil for gamedata), so 67 of the 84 profile
# files -- 3197 lines, twelve games, games/generic among them -- were never handed to a parser by anything
# in the suite. A hard syntax error in any of them left the run green: manifest_check only asserts the file
# EXISTS, check187 excludes the modern profiles outright and pattern-matches the rest line by line, and
# loader/boot.rb rescues per module and writes to a log, so at runtime that game just boots with half its
# profile wired and the screens go quiet.
#
# Parsing is not loading: compile builds the bytecode and throws it away, so no hook registers, no constant
# is defined, and a file may be checked without any of its dependencies being present.
Suite.define("static: every shipped ruby file parses") do
  root = File.expand_path("../..", File.dirname(__FILE__))
  files = %w[core games plugins loader tools].map { |d| Dir.glob(File.join(root, d, "**", "*.rb")) }.flatten.sort

  # 1.8.7 has no InstructionSequence. The mod itself runs there, but this spec runs on the system Ruby, so
  # the only way to reach this branch is a very old local interpreter -- say so rather than pass silently.
  unless defined?(RubyVM::InstructionSequence)
    Assert.check("a parser is available", false, "RubyVM::InstructionSequence missing on #{RUBY_VERSION}")
    next
  end

  bad = []
  verbose = $VERBOSE
  $VERBOSE = nil
  files.each do |f|
    begin
      RubyVM::InstructionSequence.compile(File.read(f), f)
    rescue SyntaxError => e
      bad.push("#{f.sub(root + "/", "").sub(root + "\\", "")}: #{e.message.to_s.split("\n")[0]}")
    end
  end
  $VERBOSE = verbose

  eq("no shipped file has a syntax error", bad, [])
  truthy("the sweep actually found files to parse (#{files.length})", files.length > 200)
end
