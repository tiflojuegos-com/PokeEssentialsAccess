# Every shipped .rb in core, games, plugins, loader and tools parses (the runner loads only one profile per
# pass); compiled and thrown away, so nothing registers and no dependency is needed.
Suite.define("static: every shipped ruby file parses") do
  root = File.expand_path("../..", File.dirname(__FILE__))
  files = %w[core games plugins loader tools].map { |d| Dir.glob(File.join(root, d, "**", "*.rb")) }.flatten.sort

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
