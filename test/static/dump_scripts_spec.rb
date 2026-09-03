# tools/dump_scripts.rb is the tool every profile is written against, and nothing ever EXECUTED it: the
# suite only compiled it, so a broken slice, a lost collision or a dropped script would ship silently --
# and a bad dump makes a profile author conclude the game lacks a class it has. Driven here end to end
# over a synthetic Data/ tree in the real formats (Marshal + Zlib for Scripts.rxdata, the nested plugin
# shape for PluginScripts.rxdata).
Suite.define("static: dump_scripts extracts, orders, sanitises and never drops a script") do
  require "zlib"
  require "stringio"
  require "fileutils"
  root = File.expand_path("../..", File.dirname(__FILE__))
  load File.join(root, "tools", "dump_scripts.rb") unless defined?(ScriptDumper)

  base = File.join(File.dirname(__FILE__), "tmp_dump")
  game = File.join(base, "game")
  out  = File.join(base, "out")
  FileUtils.rm_rf(base)
  FileUtils.mkdir_p(File.join(game, "Data"))
  begin
    z = lambda { |src| Zlib::Deflate.deflate(src) }
    engine = [
      [1, "Main",      z.call("class Main; end")],
      [2, "",          z.call("")],
      [3, "A/B: C?",   z.call("module Weird; end")],
      [4, "0500 Same", z.call("SAME1 = 1")],
      [5, "0500 Same", z.call("SAME2 = 2")]
    ]
    File.open(File.join(game, "Data", "Scripts.rxdata"), "wb") { |f| f.write(Marshal.dump(engine)) }
    plugins = [["Cool Plugin", {}, [["file.rb", z.call("PLUGIN_OK = 1")]]]]
    File.open(File.join(game, "Data", "PluginScripts.rxdata"), "wb") { |f| f.write(Marshal.dump(plugins)) }

    written = nil
    orig_stdout = $stdout
    begin
      $stdout = StringIO.new
      written = ScriptDumper.dump(game, out)
    ensure
      $stdout = orig_stdout
    end

    eq "every non-empty script is written, engine and plugin alike", written, 5

    all = Dir[File.join(out, "**", "*.rb")].map { |f| f[(out.length + 1)..-1].tr("\\", "/") }.sort
    truthy "the first script carries its load-order index", all.include?("0000_Main.rb")
    eq "and its source came through the inflate intact",
       File.read(File.join(out, "0000_Main.rb")), "class Main; end"

    # The documented no-silent-drop contract: two scripts under the SAME final name both survive, the
    # second with the ~N suffix.
    truthy "the first of a name collision keeps its name", all.include?("0500 Same.rb")
    truthy "and the second survives with the ~N suffix", all.include?("0500 Same~1.rb")
    eq "each with its own code", File.read(File.join(out, "0500 Same~1.rb")), "SAME2 = 2"

    weird = all.find { |f| f.index("A/") == 0 }
    truthy "a slashed name becomes a subfolder", weird
    falsy "and Windows-illegal characters never reach a filename",
          all.any? { |f| f =~ /[:*?"<>|]/ }

    plug = all.find { |f| f.index("_PluginScripts/Cool Plugin/") == 0 }
    truthy "the plugin tree keeps its game-side folder shape", plug
    eq "with the plugin source intact", File.read(File.join(out, plug)), "PLUGIN_OK = 1"
  ensure
    FileUtils.rm_rf(base)
  end
end
