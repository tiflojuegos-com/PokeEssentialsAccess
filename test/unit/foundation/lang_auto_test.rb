# The automatic language (:auto): the first shipped among the system's, its neighbour's, the game's, English and
# Spanish, kept until the game's language index changes; how the system's is read; the setting's cycle, name and save.
class LangAutoTest < PokeAccessTest
  I18n = PokeAccess::I18n
  SystemLang = PokeAccess::SystemLang
  Settings = PokeAccess::Settings
  LOCALE_VARS = %w[LC_ALL LC_MESSAGES LANG LANGUAGE].freeze

  test "ships with the automatic language as the default" do
    assert_equal :auto, PokeAccess::Config.setting(:language).default
  end

  test "resolves to the first shipped language among the system's, its neighbour's, the game's and English" do
    {
      [:es, :en] => [:es, "a Spanish system wins over a game declaring English"],
      [:en, nil] => [:en, "an English system is English"],
      [nil, :de] => [:de, "a system that does not answer leaves it to the game"],
      [:ja, :de] => [:de, "a system language the mod does not ship passes to the game's"],
      [:ja, nil] => [:en, "and with no game declaration falls to English"],
      [nil, nil] => [:en, "no answer at all is English"],
      [:ca, :en] => [:es, "a Catalan system reads Spanish before the game's English"],
      [nil, :xx] => [:en, "a declared language the mod lacks is skipped"]
    }.each do |(sys, game), (want, why)|
      with_lang_sources(sys, game) { assert_equal want, I18n.lang, why }
    end
  end

  test "falls to Spanish when the mod ships no English" do
    with_shipped([:fr, :es]) { with_lang_sources(:ja, :xx) { assert_equal :es, I18n.lang } }
  end

  test "answers English when the mod ships neither English nor Spanish" do
    with_shipped([:fr]) { with_lang_sources(:ja, nil) { assert_equal :en, I18n.lang } }
  end

  test "speaks from the table of the language it resolved to" do
    with_lang_sources(:es, :en) { assert_equal "Idioma del mod", I18n.t(:lbl_language), "a Spanish system" }
    with_lang_sources(:en, :es) { assert_equal "Mod language", I18n.t(:lbl_language), "an English system" }
  end

  test "speaks the language the player chose, whatever the system's" do
    with_lang_sources(:es, :es) do
      PokeAccess::Config.language = :fr
      assert_equal :fr, I18n.lang
    end
  end

  test "takes an unset language for the automatic one" do
    with_lang_sources(:de, nil) do
      PokeAccess::Config.language = nil
      assert_equal :de, I18n.lang
    end
  end

  test "keeps its verdict until the game's language index changes" do
    answer = :en
    with_lang_sources(nil, lambda { answer }) do
      $PokemonSystem = Struct.new(:language).new(0)
      assert_equal :en, I18n.lang, "the first verdict"
      answer = :fr
      assert_equal :en, I18n.lang, "the game's detector changing its mind alone does not move it"
      $PokemonSystem.language = 1
      assert_equal :fr, I18n.lang, "an in-game language switch asks again and follows"
    end
  end

  test "keeps no verdict reached before the system's language detector has loaded" do
    with_lang_sources(:fr, nil) do
      early = without_const(PokeAccess, :SystemLang) { I18n.auto_lang }
      assert_equal [:en, :fr], [early, I18n.lang], "English while loading, the system's once it has loaded"
    end
  end

  test "reads a locale's primary language, whatever its region or encoding" do
    { "en_US" => :en, "en-GB.UTF-8" => :en, "en" => :en, "EN_us" => :en, "es_MX" => :es, "pt" => :pt,
      "ast_ES" => :ast }.each { |locale, want| assert_equal want, SystemLang.parse(locale), "for #{locale.inspect}" }
  end

  test "reads no language from the C locale, a blank or a word that is no language code" do
    ["C", "C.UTF-8", "POSIX", "", nil, "e"].each do |locale|
      assert_nil SystemLang.parse(locale), "for #{locale.inspect}"
    end
  end

  test "reads Windows' UI language by its primary language, whatever its region" do
    { 0x0409 => :en, 0x0809 => :en, 0x0c09 => :en, 0x0c0a => :es, 0x080a => :es, 0x040c => :fr, 0x0407 => :de,
      0x0416 => :pt, 0x0816 => :pt, 0x0415 => :pl, 0x0410 => :it, 0x0411 => :ja, 0x0412 => :ko, 0x0804 => :zh,
      0x0419 => :ru, 0x0413 => :nl, 0x0403 => :ca, 0x042d => :eu, 0x0456 => :gl }.each do |langid, want|
      with_windows_language(langid) { assert_equal want, SystemLang.from_windows, format("for LANGID 0x%04x", langid) }
    end
  end

  test "reads no language from Windows when it answers none, one it does not know, or fails" do
    [0, 0x0401, :raise].each do |langid|
      with_windows_language(langid) { assert_nil SystemLang.from_windows, "for #{langid.inspect}" }
    end
  end

  test "reads the locale variables in their order of precedence" do
    {
      { "LC_ALL" => "de_DE.UTF-8", "LANG" => "fr_FR.UTF-8" } => :de,
      { "LC_MESSAGES" => "pl_PL", "LANG" => "fr_FR" } => :pl,
      { "LANG" => "fr_FR", "LANGUAGE" => "pt" } => :fr,
      { "LANGUAGE" => "pt" } => :pt
    }.each { |vars, want| with_locale_env(vars) { assert_equal want, SystemLang.from_env, "for #{vars.inspect}" } }
    with_locale_env({}) { assert_nil SystemLang.from_env, "with no locale variable set" }
  end

  test "asks mkxp-z first, then Windows, then the locale variables" do
    keeping_system_answer do
      with_locale_env("LANG" => "de_DE") do
        with_windows_language(0x040c) do
          with_runtime_language("pt_BR") { assert_equal :pt, fresh_system_code, "mkxp-z answers first" }
          assert_equal :fr, fresh_system_code, "without mkxp-z's answer, Windows'"
        end
        with_windows_language(0) { assert_equal :de, fresh_system_code, "without either, the locale's" }
      end
      with_locale_env({}) { with_windows_language(0) { assert_nil fresh_system_code, "no source answers" } }
    end
  end

  test "asks the system once, keeping the answer until told to forget it" do
    keeping_system_answer do
      with_locale_env({}) do
        with_windows_language(0x040c) { assert_equal :fr, fresh_system_code }
        with_windows_language(0x0407) do
          assert_equal :fr, SystemLang.code, "asked again, it keeps its first answer"
          assert_equal :de, fresh_system_code, "forgotten, it asks anew"
        end
      end
    end
  end

  test "names the shipped language a system language's speakers also read" do
    { :ca => :es, :eu => :es, :gl => :es, :ast => :es }.each do |code, want|
      assert_equal want, SystemLang.neighbour(code), "for #{code.inspect}"
    end
    [:ja, :es, nil].each { |code| assert_nil SystemLang.neighbour(code), "for #{code.inspect}" }
  end

  test "cycles from automatic to the first language file, and from the last file back to automatic" do
    row = PokeAccess::Config.setting(:language)
    langs = I18n.available_languages
    { [:auto, 1] => langs.first, [langs.last, 1] => :auto, [langs.first, -1] => :auto,
      [:auto, -1] => langs.last }.each do |(from, dir), want|
      PokeAccess::Config.language = from
      assert_equal want, PokeAccess::Config.next_value(row, dir), "from #{from.inspect}, stepping #{dir}"
    end
  end

  test "names the automatic entry after the language it resolves to" do
    with_lang_sources(:es, nil) do
      assert_equal I18n.t(:lang_auto, :name => "Español"), I18n.language_name(:auto)
    end
  end

  test "names a language by its own name, and one with no file by its code" do
    { :es => "Español", :en => "English", :fr => "Français", :de => "Deutsch", :pt => "Português", :pl => "Polski",
      :xx => "xx" }.each { |code, want| assert_equal want, I18n.language_name(code), "for #{code.inspect}" }
  end

  test "names the automatic entry plainly when it could only resolve to itself" do
    with_shipped([:auto]) { with_lang_sources(:auto, nil) { assert_equal "auto", I18n.language_name(:auto) } }
  end

  test "saves the automatic choice as auto, and reads it back as automatic" do
    with_settings_file do
      PokeAccess::Config.language = :auto
      Settings.write
      assert_equal "auto", Settings.read["language"], "the ini says auto"
      PokeAccess::Config.language = :en
      Settings.apply
      assert_equal :auto, PokeAccess::Config.language, "and reading it back restores the automatic choice"
    end
  end

  test "keeps the language an ini names" do
    with_settings_file do
      File.open(Settings::FILE, "w") { |f| f.write("language=es\n") }
      PokeAccess::Config.language = :auto
      Settings.apply
      assert_equal :es, PokeAccess::Config.language
    end
  end

  private

  # Runs the block with the two detectors answering sys and game (game may be a proc, to change its mind mid-block),
  # the setting on :auto and the verdict forgotten; detectors, setting, game options and verdict are put back after.
  def with_lang_sources(sys, game)
    gl = PokeAccess::GameLang
    saved = [gl.method(:code), SystemLang.method(:code), PokeAccess::Config.language, $PokemonSystem]
    gl.define_singleton_method(:code) { game.respond_to?(:call) ? game.call : game }
    SystemLang.define_singleton_method(:code) { sys }
    PokeAccess::Config.language = :auto
    I18n.forget_auto
    yield
  ensure
    gl.define_singleton_method(:code, saved[0])
    SystemLang.define_singleton_method(:code, saved[1])
    PokeAccess::Config.language = saved[2]
    $PokemonSystem = saved[3]
    I18n.forget_auto
  end

  # Runs the block as if the mod shipped only the given language files, the real list put back after.
  def with_shipped(langs)
    was = I18n.instance_variable_get(:@langs)
    I18n.instance_variable_set(:@langs, langs)
    yield
  ensure
    I18n.instance_variable_set(:@langs, was)
    I18n.forget_auto
  end

  # Runs the block with Windows answering langid as the UI language (:raise fails the call), the stub put back after.
  def with_windows_language(langid)
    Win32API.send(:alias_method, :pa_spec_call, :call)
    Win32API.send(:define_method, :call) { |*_a| langid == :raise ? raise("kernel32") : langid }
    yield
  ensure
    Win32API.send(:alias_method, :call, :pa_spec_call)
    Win32API.send(:remove_method, :pa_spec_call)
  end

  # Runs the block with mkxp-z's System answering locale as the user language; System is put back as it was.
  def with_runtime_language(locale)
    had = Object.const_defined?(:System)
    sys = had ? ::System : Object.const_set(:System, Module.new)
    real = sys.respond_to?(:user_language) ? sys.method(:user_language) : nil
    sys.define_singleton_method(:user_language) { locale }
    yield
  ensure
    if !had
      Object.send(:remove_const, :System)
    elsif real
      sys.define_singleton_method(:user_language, real)
    else
      sys.singleton_class.send(:remove_method, :user_language)
    end
  end

  # Runs the block with only the locale variables vars names set, the process's own put back after.
  def with_locale_env(vars)
    saved = LOCALE_VARS.map { |name| [name, ENV[name]] }
    LOCALE_VARS.each { |name| ENV[name] = vars[name] }
    yield
  ensure
    saved.each { |name, value| ENV[name] = value }
  end

  # Runs the block and puts SystemLang's remembered answer back as it found it.
  def keeping_system_answer
    was = [SystemLang.instance_variable_get(:@asked), SystemLang.instance_variable_get(:@code)]
    yield
  ensure
    SystemLang.instance_variable_set(:@asked, was[0])
    SystemLang.instance_variable_set(:@code, was[1])
  end

  # The system's language asked anew.
  def fresh_system_code
    SystemLang.forget
    SystemLang.code
  end

  # The block's value with owner's constant name removed, as before its file loads; the constant is put back after.
  def without_const(owner, name)
    was = owner.const_get(name)
    owner.send(:remove_const, name)
    yield
  ensure
    owner.const_set(name, was) unless owner.const_defined?(name, false)
  end

  # Runs the block and puts settings.ini back as it was (absent stays absent).
  def with_settings_file
    was = File.exist?(Settings::FILE) ? File.binread(Settings::FILE) : nil
    yield
  ensure
    if was
      File.open(Settings::FILE, "wb") { |f| f.write(was) }
    elsif File.exist?(Settings::FILE)
      File.delete(Settings::FILE)
    end
  end
end
