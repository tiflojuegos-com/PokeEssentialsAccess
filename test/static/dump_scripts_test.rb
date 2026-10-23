# tools/dump_scripts.rb over synthetic game folders in the real formats: Scripts.rxdata (Marshal of deflated
# sources), PluginScripts.rxdata (the nested plugin shape), a loose script tree and a Game.rgssad archive.
require "zlib"
require "stringio"
require "tmpdir"
require "fileutils"

class DumpScriptsTest < PokeAccessTest
  TOOL = File.expand_path("../../tools/dump_scripts.rb", File.dirname(__FILE__))
  eval(Harness.source(TOOL), TOPLEVEL_BINDING, TOOL) unless defined?(ScriptDumper)

  test "names each script after its load-order index and keeps its inflated source" do
    with_game do |game, out|
      engine(game, [["Main", "class Main; end"], ["Battle", "X = 1"]])
      written, = dump(game, out)
      assert_equal({ "0000_Main.rb" => "class Main; end", "0001_Battle.rb" => "X = 1" }, files(out))
      assert_equal 2, written, "the count it answers"
    end
  end

  test "skips the empty scripts RPG Maker uses as separators and says how many" do
    { 1 => [["", ""]], 2 => [["", ""], ["Gap", "  \n"]] }.each do |n, empties|
      with_game do |game, out|
        engine(game, [["Main", "a = 1"]] + empties)
        written, said = dump(game, out)
        assert_equal ["0000_Main.rb"], files(out).keys, "with #{n} empty"
        assert_equal 1, written, "with #{n} empty"
        assert_includes said, "#{n} empty entries skipped (RPG Maker separators)."
      end
    end
  end

  test "says nothing of empty scripts when there are none" do
    with_game do |game, out|
      engine(game, [["Main", "a = 1"]])
      _written, said = dump(game, out)
      refute_match(/empty entries/, said)
    end
  end

  test "counts a script whose data does not inflate as empty instead of failing" do
    with_game do |game, out|
      File.binwrite(File.join(game, "Data", "Scripts.rxdata"), Marshal.dump([[1, "Broken", "not deflated"]]))
      written, = dump(game, out)
      assert_equal 0, written
      assert_equal({}, files(out))
    end
  end

  test "keeps a name that already starts with a number without a second index" do
    with_game do |game, out|
      engine(game, [["Main", "a = 1"], ["0500 Same", "b = 1"]])
      dump(game, out)
      assert_equal ["0000_Main.rb", "0500 Same.rb"], files(out).keys
    end
  end

  test "keeps every script of a repeated name, numbering the repeats and saying so" do
    with_game do |game, out|
      engine(game, [["0500 Same", "SAME1 = 1"], ["0500 Same", "SAME2 = 2"], ["0500 Same", "SAME3 = 3"]])
      written, said = dump(game, out)
      assert_equal({ "0500 Same.rb" => "SAME1 = 1", "0500 Same~1.rb" => "SAME2 = 2", "0500 Same~2.rb" => "SAME3 = 3" },
                   files(out))
      assert_equal 3, written
      assert_includes said, "2 name collisions, kept with a ~N suffix: 0500 Same"
    end
  end

  test "takes two names that differ only in case for the same file, as Windows does" do
    with_game do |game, out|
      engine(game, [["0500 Same", "a = 1"], ["0500 SAME", "b = 1"]])
      dump(game, out)
      assert_equal ["0500 SAME~1.rb", "0500 Same.rb"], files(out).keys
    end
  end

  test "turns each slash of a name into a folder" do
    with_game do |game, out|
      engine(game, [["Battle/Core/Scene", "a = 1"]])
      dump(game, out)
      assert_equal ["Battle/Core/0000_Scene.rb"], files(out).keys
    end
  end

  test "replaces the characters Windows forbids and drops empty, dot and dot-dot segments" do
    with_game do |game, out|
      engine(game, [["A/B: C?", "a = 1"], ["../up", "b = 1"], ["./x//y", "c = 1"], ["<*|>", "d = 1"]])
      dump(game, out)
      assert_equal ["0001_up.rb", "0003_____.rb", "A/0000_B_ C_.rb", "x/0002_y.rb"], files(out).keys
    end
  end

  test "names a script with no usable name untitled, under its index" do
    with_game do |game, out|
      engine(game, [["Main", "a = 1"], ["", "b = 1"], ["/../", "c = 1"]])
      dump(game, out)
      assert_equal ["0000_Main.rb", "0001_untitled.rb", "0002_untitled.rb"], files(out).keys
    end
  end

  test "drops the .rb a name already carries" do
    with_game do |game, out|
      engine(game, [["Main.rb", "a = 1"]])
      dump(game, out)
      assert_equal ["0000_Main.rb"], files(out).keys
    end
  end

  test "reads a name written in the game's Latin-1 codepage" do
    with_game do |game, out|
      engine(game, [["Pok\xE9mon".b, "a = 1"]])
      dump(game, out)
      assert_equal ["0000_Pokémon.rb"], files(out).keys
    end
  end

  test "writes a plugin's files under _PluginScripts and the plugin's folder, unnumbered" do
    with_game do |game, out|
      engine(game, [["Main", "a = 1"]])
      plugins = [["Cool Plugin", {}, [["001_main.rb", z("P = 1")], ["helpers", z("H = 1")]]]]
      File.binwrite(File.join(game, "Data", "PluginScripts.rxdata"), Marshal.dump(plugins))
      written, = dump(game, out)
      assert_equal({ "0000_Main.rb" => "a = 1", "_PluginScripts/Cool Plugin/001_main.rb" => "P = 1",
                     "_PluginScripts/Cool Plugin/helpers.rb" => "H = 1" }, files(out))
      assert_equal 3, written
    end
  end

  test "reads the loose script tree when Scripts.rxdata only holds its loader, and keeps the loader" do
    with_game do |game, out|
      engine(game, [["Loader", "load_all"]])
      loose(game, "Scripts/001_Core.rb" => "CORE = 1 # " + "x" * 40,
                  "Scripts/Sub/002_Scene.rb" => "SCENE = 1 # " + "x" * 40)
      _written, said = dump(game, out)
      assert_equal ["0000_Loader.rb", "001_Core.rb", "Sub/002_Scene.rb"], files(out).keys
      assert_includes said, "Data/Scripts.rxdata only holds a loader; reading the 2-file script tree instead."
    end
  end

  test "keeps to Scripts.rxdata when it holds more code than a loose tree" do
    with_game do |game, out|
      engine(game, [["Main", "MAIN = 1 # " + "x" * 80]])
      loose(game, "Scripts/001_Stray.rb" => "S = 1")
      dump(game, out)
      assert_equal ["0000_Main.rb"], files(out).keys
    end
  end

  test "reads a game that ships only the loose script tree" do
    with_game do |game, out|
      loose(game, "Scripts/001_Core.rb" => "CORE = 1")
      dump(game, out)
      assert_equal({ "001_Core.rb" => "CORE = 1" }, files(out))
    end
  end

  test "takes the tree from the folder under Data with the most scripts, widened to the top of its script folders" do
    with_game do |game, out|
      loose(game, "Aux/helper.rb" => "AUX = 1", "Scripts/001_Core.rb" => "CORE = 1",
                  "Scripts/Battle/002_A.rb" => "A = 1", "Scripts/Battle/003_B.rb" => "B = 1")
      dump(game, out)
      assert_equal ["001_Core.rb", "Battle/002_A.rb", "Battle/003_B.rb"], files(out).keys
    end
  end

  test "stops widening the tree at a folder that holds anything but scripts" do
    with_game do |game, out|
      loose(game, "Scripts/readme.txt" => "notes", "Scripts/001_Core.rb" => "CORE = 1",
                  "Scripts/Battle/002_A.rb" => "A = 1", "Scripts/Battle/003_B.rb" => "B = 1")
      dump(game, out)
      assert_equal ["002_A.rb", "003_B.rb"], files(out).keys
    end
  end

  test "reads the scripts out of the archive when the game ships its data packed, and says so" do
    %w[Game.rgssad Game.rgss2a].each do |archive|
      with_game do |game, out|
        FileUtils.rm_rf(File.join(game, "Data"))
        packed = Marshal.dump([[1, "Main", z("class Main; end")], [2, "Odd", z("ODD = 12345")]])
        File.binwrite(File.join(game, archive), rgssad("Data\\Scripts.rxdata" => packed))
        written, said = dump(game, out)
        assert_equal({ "0000_Main.rb" => "class Main; end", "0001_Odd.rb" => "ODD = 12345" }, files(out), archive)
        assert_equal 2, written, archive
        assert_includes said, "Read from Game.rgssad (the game ships its data packed)."
      end
    end
  end

  test "reads a script tree packed in the archive, its empty last file included" do
    with_game do |game, out|
      FileUtils.rm_rf(File.join(game, "Data"))
      loader = Marshal.dump([[1, "Loader", z("load_all")]])
      File.binwrite(File.join(game, "Game.rgssad"),
                    rgssad("Data\\Scripts.rxdata" => loader, "Data\\Scripts\\001_Core.rb" => "CORE = 1 # " + "x" * 40,
                           "Data\\Scripts\\002_Empty.rb" => ""))
      _written, said = dump(game, out)
      assert_equal ["0000_Loader.rb", "001_Core.rb"], files(out).keys
      assert_includes said, "1 empty entries skipped (RPG Maker separators).", "the empty file was read, then skipped"
    end
  end

  test "stops reading the archive at an entry it cuts short" do
    with_game do |game, out|
      FileUtils.rm_rf(File.join(game, "Data"))
      plugins = Marshal.dump([["Cool Plugin", {}, [["main", z("P = 1")]]]])
      archive = rgssad("Data\\Scripts.rxdata" => Marshal.dump([[1, "Main", z("M = 1")]]),
                       "Data\\PluginScripts.rxdata" => plugins)
      File.binwrite(File.join(game, "Game.rgssad"), archive.byteslice(0, archive.bytesize - 3))
      dump(game, out)
      assert_equal({ "0000_Main.rb" => "M = 1" }, files(out))
    end
  end

  test "refuses a VX Ace archive" do
    with_game do |game, out|
      FileUtils.rm_rf(File.join(game, "Data"))
      File.binwrite(File.join(game, "Game.rgss3a"), "RGSSAD\x00\x03".b)
      e = assert_raises(RuntimeError) { dump(game, out) }
      assert_equal "Game.rgss3a is an RPG Maker VX Ace archive; this tool reads XP games.", e.message
    end
  end

  test "refuses an archive that is not RGSSAD version 1" do
    { "RGSSAD\x00\x03".b => "Game.rgssad is RGSSAD version 3; this tool reads version 1.",
      "PK\x03\x04 zip".b => "Game.rgssad is not an RGSSAD archive." }.each do |head, message|
      with_game do |game, out|
        FileUtils.rm_rf(File.join(game, "Data"))
        File.binwrite(File.join(game, "Game.rgssad"), head)
        e = assert_raises(RuntimeError) { dump(game, out) }
        assert_equal message, e.message, "for a file starting #{head.inspect}"
      end
    end
  end

  test "refuses a folder without scripts, pointing at a game folder nested inside it" do
    with_game do |game, out|
      FileUtils.rm_rf(File.join(game, "Data"))
      e = assert_raises(RuntimeError) { dump(game, out) }
      assert_equal "No scripts found in #{game} (this should be the folder with Game.exe in it).", e.message
      FileUtils.mkdir_p(File.join(game, "Audio"))
      FileUtils.mkdir_p(File.join(game, "Inner", "Data"))
      e = assert_raises(RuntimeError) { dump(game, out) }
      assert_equal "No scripts found in #{game} (this should be the folder with Game.exe in it).\n" \
                   "       Try: #{File.join(game, 'Inner')}", e.message
    end
  end

  test "refuses a path that is not a folder" do
    with_game do |game, out|
      file = File.join(game, "Game.exe")
      File.binwrite(file, "MZ")
      e = assert_raises(RuntimeError) { dump(file, out) }
      assert_equal "#{file} is not a folder.", e.message
    end
  end

  private

  # A source deflated as RPG Maker stores it.
  def z(src)
    Zlib::Deflate.deflate(src)
  end

  # Yields a game folder with an empty Data folder and an output folder, both in a throwaway directory.
  def with_game
    Dir.mktmpdir("pa-dump") do |dir|
      game = File.join(dir, "game")
      FileUtils.mkdir_p(File.join(game, "Data"))
      yield game, File.join(dir, "out")
    end
  end

  # Writes Data/Scripts.rxdata with the [name, source] scripts, in order.
  def engine(game, scripts)
    rows = scripts.each_with_index.map { |(name, src), i| [i + 1, name, z(src)] }
    File.binwrite(File.join(game, "Data", "Scripts.rxdata"), Marshal.dump(rows))
  end

  # Writes loose .rb files under Data, from { path inside Data => source }.
  def loose(game, sources)
    sources.each do |rel, src|
      path = File.join(game, "Data", rel)
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, src)
    end
  end

  # Dumps the game into out: the count the tool answers and what it printed.
  def dump(game, out)
    was = $stdout
    $stdout = StringIO.new
    written = ScriptDumper.dump(game, out)
    [written, $stdout.string]
  ensure
    $stdout = was
  end

  # { path under out => source } of every .rb the dump wrote, sorted by path.
  def files(out)
    paths = Dir[File.join(out, "**", "*.rb")].map { |f| f[(out.length + 1)..-1] }.sort
    paths.map { |rel| [rel, File.binread(File.join(out, rel)).force_encoding("UTF-8")] }.to_h
  end

  # An RGSSAD v1 archive of { name => data }: lengths, names and data XOR'd with the key the format advances.
  def rgssad(entries)
    key = 0xDEADCAFE
    out = "RGSSAD\x00\x01".b
    entries.each do |name, data|
      data = data.b
      out << [name.bytesize ^ key].pack("V")
      key = (key * 7 + 3) & 0xFFFFFFFF
      name.each_byte do |b|
        out << (b ^ (key & 0xFF)).chr
        key = (key * 7 + 3) & 0xFFFFFFFF
      end
      out << [data.bytesize ^ key].pack("V")
      key = (key * 7 + 3) & 0xFFFFFFFF
      out << xor_stream(data, key)
    end
    out
  end

  # Data XOR'd word by word with a key advancing per word, the tail byte by byte with the key shifted down.
  def xor_stream(data, key)
    out = "".b
    whole = data.bytesize / 4
    data.unpack("V#{whole}").each do |w|
      out << [w ^ key].pack("V")
      key = (key * 7 + 3) & 0xFFFFFFFF
    end
    data.byteslice(whole * 4, data.bytesize - whole * 4).each_byte do |b|
      out << (b ^ (key & 0xFF)).chr
      key >>= 8
    end
    out
  end
end
