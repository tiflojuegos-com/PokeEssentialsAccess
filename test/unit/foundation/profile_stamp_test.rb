# The game the dictionaries stamp their files with (Game.profile_name): a declared profile as is, past a common's;
# else the install's, a generic one qualified by the game's title; and how a file's stamp is read back and matched.
class ProfileStampTest < PokeAccessTest
  Game = PokeAccess::Game
  Marks = PokeAccess::Marks
  INSTALL = "#{PokeAccess::Paths::DATA}/installed.json"
  PROBE = "#{PokeAccess::Paths::DATA}/stamp_probe.txt"

  test "is the first declared profile that is not a common's" do
    as_game(["infinitefusion_common", "infinitefusion_hoenn"], "generic") do
      assert_equal "infinitefusion_hoenn", Game.profile_name
    end
  end

  test "is a declared profile as is, whatever the install says" do
    as_game(["anil"], "generic", "Pokemon Myth") { assert_equal "anil", Game.profile_name }
  end

  test "is the install's profile when every profile declared is a common's" do
    as_game(["infinitefusion_common"], "infinitefusion") { assert_equal "infinitefusion", Game.profile_name }
  end

  test "keeps a named install's profile bare, whatever the game's title" do
    as_game([], "infinitefusion", "Pokemon Myth") { assert_equal "infinitefusion", Game.profile_name }
  end

  test "qualifies a generic install with the game's title, so two unprofiled games differ" do
    { "Pokemon Myth" => "generic:Pokemon Myth", "Pokemon Otro" => "generic:Pokemon Otro",
      "  Pokemon Myth  " => "generic:Pokemon Myth" }.each do |title, want|
      as_game([], "generic", title) { assert_equal want, Game.profile_name, "for the title #{title.inspect}" }
    end
  end

  test "leaves a generic install bare when the game has no title, a blank one, or fails to give one" do
    [nil, "", "   ", :raise].each do |title|
      as_game([], "generic", title) { assert_equal "generic", Game.profile_name, "for #{title.inspect}" }
    end
  end

  test "has no profile name when neither a profile nor the install names one" do
    [nil, '{"version": "0.6.1"}', "not json"].each do |install|
      as_game([], install) { assert_nil Game.profile_name, "for the install #{install.inspect}" }
    end
  end

  test "keeps its answer, a missing one too, until a profile is declared" do
    as_game([], nil) do
      assert_nil Game.profile_name, "first asked"
      write(INSTALL, '{"profile": "anil"}')
      assert_nil Game.profile_name, "asked again, it does not read the install anew"
      Game.define("royal")
      assert_equal "royal", Game.profile_name, "a declared profile asks anew"
    end
  end

  test "reads a file's stamp from its leading comments, spaces and all" do
    { "# game: generic:Pokemon Myth\n1=algo\n" => "generic:Pokemon Myth",
      "# Cabecera\n\n#game:anil  \n1=algo\n" => "anil" }.each do |text, want|
      write(PROBE, text)
      assert_equal want, Marks.file_game(PROBE), "for #{text.inspect}"
    end
  ensure
    delete(PROBE)
  end

  test "reads no stamp past the leading comments, nor from a file without one" do
    ["# Cabecera\n1=algo\n# game: anil\n", "1=algo\n", "# Cabecera\n", ""].each do |text|
      write(PROBE, text)
      assert_nil Marks.file_game(PROBE), "for #{text.inspect}"
    end
  ensure
    delete(PROBE)
  end

  test "reads no stamp from a file it cannot read" do
    assert_nil Marks.file_game("#{PokeAccess::Paths::DATA}/no_such_dir/marks.txt")
  end

  test "takes an import stamped with the running game's own name, and merges it" do
    { [["anil"]] => "anil", [[], "generic", "Spec Game"] => "generic:Spec Game" }.each do |game, stamp|
      as_game(*game) do
        Marks.count
        write(Marks::IMPORT, "# game: #{stamp}\n1:2,2=Propia\n")
        assert_equal [:ready, stamp], Marks.import_status, "for #{stamp}"
        assert_equal 1, Marks.import_now, "#{stamp}: the entry it adds"
        assert_equal "Propia", Marks.get(1, 2, 2), "#{stamp}: in the store"
      end
    end
  end

  test "takes an import stamped with the bare generic of older installs into an unprofiled game" do
    as_game([], "generic", "Spec Game") do
      write(Marks::IMPORT, "# game: generic\n1:2,2=Vieja\n")
      assert_equal [:ready, "generic"], Marks.import_status
    end
  end

  test "refuses an import stamped by another unprofiled game" do
    as_game([], "generic", "Spec Game") do
      write(Marks::IMPORT, "# game: generic:Otro juego\n1:2,2=Ajena\n")
      assert_equal [:foreign, "generic:Otro juego"], Marks.import_status
    end
  end

  test "refuses the bare generic stamp in a game with a profile of its own" do
    as_game(["anil"]) do
      write(Marks::IMPORT, "# game: generic\n1:2,2=Vieja\n")
      assert_equal [:foreign, "generic"], Marks.import_status
    end
  end

  test "takes any game's import while the running game has no name to check it against" do
    as_game([]) do
      write(Marks::IMPORT, "# game: otro_juego\n1:2,2=Ajena\n")
      assert_equal [:ready, "otro_juego"], Marks.import_status
    end
  end

  test "stamps nothing while the running game has no name" do
    as_game([]) do
      Marks.set(1, 2, 3, "Tienda")
      assert_equal Marks.header.map { |line| "# #{line}" } + ["1:2,3=Tienda"],
                   File.readlines(Marks::FILE).map(&:chomp)
    end
  end

  private

  # Runs the block as a game that declares profiles, whose installed.json names install (a profile, or the file's whole
  # text when it is not a bare word; nil for no file) and whose $data_system has title (nil for none, :raise for one
  # that fails), with no marks; profiles, the memo, the install and $data_system are put back after, the marks wiped.
  def as_game(profiles, install = nil, title = nil)
    saved = [Game.profiles.dup, Game.instance_variable_get(:@profile_name), $data_system, read(INSTALL)]
    wipe_marks
    Game.profiles.replace(profiles)
    Game.instance_variable_set(:@profile_name, nil)
    install.nil? ? delete(INSTALL) : write(INSTALL, install =~ /\A\w+\z/ ? "{\"profile\": \"#{install}\"}" : install)
    $data_system = system_with(title)
    yield
  ensure
    Game.profiles.replace(saved[0])
    Game.instance_variable_set(:@profile_name, saved[1])
    $data_system = saved[2]
    saved[3].nil? ? delete(INSTALL) : write(INSTALL, saved[3])
    wipe_marks
  end

  # Deletes the marks' file, their import and its set-aside copy, and forgets the loaded marks.
  def wipe_marks
    [Marks::FILE, Marks::IMPORT, Marks.imported_path].each { |path| delete(path) }
    Marks.reload!
  end

  # A $data_system answering title as its game_title (nil for no system, :raise for one whose game_title fails).
  def system_with(title)
    return nil if title.nil?
    sys = Object.new
    sys.define_singleton_method(:game_title) { title == :raise ? raise("no title") : title }
    sys
  end

  # Writes text to path, byte for byte.
  def write(path, text)
    File.open(path, "wb") { |f| f.write(text) }
  end

  # The bytes of path, or nil when there is no such file.
  def read(path)
    File.exist?(path) ? File.binread(path) : nil
  end

  # Deletes path if it is there.
  def delete(path)
    File.delete(path) if File.exist?(path)
  end
end
