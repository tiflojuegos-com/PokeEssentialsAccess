# GameLang: the language the game's build runs in, from its LANGUAGES table at the player's language index, believed
# only when the message file the entry names ships; and pick, which serves a language-keyed value for that build.
class GameLangTest < PokeAccessTest
  Options = Struct.new(:language)
  ENGLISH = ["English", "english.dat"].freeze
  GERMAN = ["Deutsch", "deutsch.dat"].freeze
  BOTH_SHIP = %w[english.dat deutsch.dat].freeze
  GREETING = { :es => "hola", :en => "hello" }.freeze

  test "declares no language without a LANGUAGES table" do
    assert_nil PokeAccess::GameLang.code
  end

  test "names the language of the entry at the player's index when its message file ships" do
    { 0 => :en, 1 => :de }.each do |index, want|
      in_build([ENGLISH, GERMAN], BOTH_SHIP, index) { assert_equal want, PokeAccess::GameLang.code, "at #{index}" }
    end
  end

  test "gives the running entry's name as the build wrote it" do
    in_build([["Français (France)", "lang.dat"]], %w[lang.dat]) do
      assert_equal "Français (France)", PokeAccess::GameLang.declared_name
    end
  end

  test "takes an entry whose message file does not ship for template residue" do
    { ENGLISH => %w[deutsch.dat], ["Deutsch", "deutsch"] => %w[deutsch.dat], ["Deutsch", ""] => BOTH_SHIP,
      ["Deutsch", nil] => BOTH_SHIP, ["Deutsch", "deutsch.dat"] => %w[messages_deutsch.dat.dat] }.each do |entry, files|
      in_build([entry], files) { assert_nil PokeAccess::GameLang.code, "#{entry.inspect} with #{files.inspect}" }
    end
  end

  test "takes an entry whose file name the file system refuses for one that does not ship" do
    in_build([["Deutsch", "deutsch\0.dat"]], BOTH_SHIP) { assert_nil PokeAccess::GameLang.code }
  end

  test "finds a bare name's messages file in each shape a build ships it" do
    %w[messages_deutsch_core.dat messages_deutsch_game.dat messages_deutsch.dat].each do |file|
      in_build([["Deutsch", "deutsch"]], [file]) { assert_equal :de, PokeAccess::GameLang.code, "with #{file}" }
    end
  end

  test "follows a language switch in the game's options, read live" do
    in_build([ENGLISH, GERMAN], BOTH_SHIP, 0) do
      assert_equal :en, PokeAccess::GameLang.code, "before the switch"
      $PokemonSystem.language = 1
      assert_equal :de, PokeAccess::GameLang.code, "after it, with the same table"
    end
  end

  test "falls back to the first entry for an index outside the table or before the options exist" do
    [-1, 2, nil].each do |index|
      in_build([ENGLISH, GERMAN], BOTH_SHIP, index) do
        $PokemonSystem = nil if index.nil?
        assert_equal :en, PokeAccess::GameLang.code, "at #{index.inspect}"
      end
    end
  end

  test "declares nothing for an entry with no name or no file, or an empty table" do
    [[["", "english.dat"]], [[nil, "english.dat"]], ["English"], []].each do |table|
      in_build(table, BOTH_SHIP) do
        assert_equal [nil, nil], [PokeAccess::GameLang.declared_name, PokeAccess::GameLang.code], "for #{table.inspect}"
      end
    end
  end

  test "declares nothing, and does not fail, for an entry it cannot read" do
    in_build([BasicObject.new], BOTH_SHIP) do
      assert_equal [nil, nil], [PokeAccess::GameLang.declared_name, PokeAccess::GameLang.code]
    end
  end

  test "folds a native or accented name to its language's code" do
    names = { "Français" => :fr, "Français".b => :fr, "Español" => :es, "Português" => :pt, "ITALIANO" => :it }
    names.each do |name, want|
      in_build([[name, "lang.dat"]], %w[lang.dat]) { assert_equal want, PokeAccess::GameLang.code, name.inspect }
    end
  end

  test "matches a qualified name by the language it starts with" do
    { "English (UK)" => :en, "Deutsch (Schweiz)" => :de }.each do |name, want|
      in_build([[name, "lang.dat"]], %w[lang.dat]) { assert_equal want, PokeAccess::GameLang.code, "for #{name}" }
    end
  end

  test "gives no code for a language it does not know" do
    in_build([["Klingon", "lang.dat"]], %w[lang.dat]) { assert_nil PokeAccess::GameLang.code }
  end

  test "gives no code, and does not fail, for a name whose bytes are not text" do
    latin1 = "Fran\xE7ais".dup.force_encoding("UTF-8")
    in_build([[latin1, "lang.dat"]], %w[lang.dat]) do
      assert_equal [latin1, nil], [PokeAccess::GameLang.declared_name, PokeAccess::GameLang.code]
    end
  end

  test "reads a modern build's Settings::LANGUAGES when the top-level table is missing or not a list" do
    [nil, { "x" => 1 }].each do |top|
      in_build(top, BOTH_SHIP) do
        with_settings_languages([GERMAN]) { assert_equal :de, PokeAccess::GameLang.code, "top-level #{top.inspect}" }
      end
    end
  end

  test "prefers a top-level table to Settings::LANGUAGES" do
    in_build([ENGLISH], BOTH_SHIP) do
      with_settings_languages([GERMAN]) { assert_equal :en, PokeAccess::GameLang.code }
    end
  end

  test "takes a Settings::LANGUAGES that is not a list for no table" do
    in_build(nil, BOTH_SHIP) do
      with_settings_languages({ "x" => [GERMAN] }) { assert_nil PokeAccess::GameLang.code }
    end
  end

  test "passes a value that is not keyed by language through" do
    ["suelto", nil, %w[a b]].each { |value| assert_same value, PokeAccess::GameLang.pick(value, :es) }
  end

  test "serves the build's own entry of a language-keyed value, else the authored base's" do
    { [ENGLISH] => "hello", [GERMAN] => "hola", nil => "hola" }.each do |table, want|
      in_build(table, BOTH_SHIP) { assert_equal want, PokeAccess::GameLang.pick(GREETING, :es), "for #{table.inspect}" }
    end
  end

  test "serves nothing when neither the build nor the base has an entry" do
    in_build([ENGLISH], BOTH_SHIP) { assert_nil PokeAccess::GameLang.pick({ :fr => "salut" }, :es) }
  end

  private

  # Runs the block in a scratch game folder whose Data/ ships files, with the top-level LANGUAGES set to table (none
  # for nil) and the game's options at language index; all put back afterwards.
  def in_build(table, files = [], index = 0)
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "Data"))
      files.each { |f| File.open(File.join(dir, "Data", f), "wb") { |io| io.write("x") } }
      was = $PokemonSystem
      Object.const_set(:LANGUAGES, table) unless table.nil?
      $PokemonSystem = Options.new(index)
      begin
        Dir.chdir(dir) { yield }
      ensure
        $PokemonSystem = was
        Object.send(:remove_const, :LANGUAGES) if Object.const_defined?(:LANGUAGES, false)
      end
    end
  end

  # Runs the block with modern Essentials' Settings::LANGUAGES set to table, a top-level Settings made for it when
  # the engine has none; put back afterwards.
  def with_settings_languages(table)
    made = !Object.const_defined?(:Settings, false)
    Object.const_set(:Settings, Module.new) if made
    ::Settings.const_set(:LANGUAGES, table)
    yield
  ensure
    if made
      Object.send(:remove_const, :Settings)
    else
      ::Settings.send(:remove_const, :LANGUAGES)
    end
  end
end
