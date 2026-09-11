# The automatic language. :auto is a rule, not a file: the system's language, then the one the game
# declares it runs in, then English, then Spanish -- the first one the mod ships. The mod's voice is the
# mod's interface, so the player's own language comes first: an English player hears English whatever
# the game, a Spanish player Spanish, and neither ever opens the menu. The harness pins :es for every
# other suite; these switch to :auto and put everything back.

# Runs the block with the two detectors answering sys and game (game may be a proc, to change its mind
# mid-block), the setting on :auto and the memo cleared; restores detectors, setting and game object after.
def with_lang_sources(sys, game)
  gl = PokeAccess::GameLang
  sl = PokeAccess::SystemLang
  saved = [gl.method(:code), sl.method(:code), PokeAccess::Config.language, $PokemonSystem]
  gl.define_singleton_method(:code) { game.respond_to?(:call) ? game.call : game }
  sl.define_singleton_method(:code) { sys }
  PokeAccess::Config.language = :auto
  PokeAccess::I18n.forget_auto
  yield
ensure
  gl.define_singleton_method(:code, saved[0])
  sl.define_singleton_method(:code, saved[1])
  PokeAccess::Config.language = saved[2]
  $PokemonSystem = saved[3]
  PokeAccess::I18n.forget_auto
end

Suite.define("language: auto follows the system, then the game, then English, then Spanish") do
  i18n = PokeAccess::I18n
  eq "the shipped default is automatic", PokeAccess::Config::SCHEMA.find { |r| r[0] == :language }[1], :auto
  with_lang_sources(:es, :en) do
    eq "a Spanish system wins over a game declaring English", i18n.lang, :es
    eq "and the strings come out of the Spanish table", i18n.t(:lbl_language), "Idioma del mod"
  end
  with_lang_sources(:en, nil) do
    eq "an English system is English whatever the game declares", i18n.lang, :en
    eq "and the strings come out of the English table", i18n.t(:lbl_language), "Mod language"
  end
  with_lang_sources(nil, :en) { eq "a system that does not answer leaves it to the game", i18n.lang, :en }
  with_lang_sources(:ja, :de) { eq "a system language the mod does not ship passes to the game's", i18n.lang, :de }
  with_lang_sources(:ja, nil) { eq "and with no game declaration falls to English", i18n.lang, :en }
  with_lang_sources(nil, nil) { eq "no answer at all is English too", i18n.lang, :en }
  with_lang_sources(:ca, :en) { eq "a Catalan system is a Spanish reader before it is the game's English", i18n.lang, :es }
  with_lang_sources(nil, :xx) { eq "a declared language the mod lacks is skipped, not forced", i18n.lang, :en }
end

Suite.define("language: the system code is one primary language for every regional variant") do
  sl = PokeAccess::SystemLang
  eq "en_US, en-GB and a bare en are all English", [sl.parse("en_US"), sl.parse("en-GB.UTF-8"), sl.parse("en")], [:en, :en, :en]
  eq "es_MX is Spanish", sl.parse("es_MX"), :es
  eq "the C locale and blanks answer nothing", [sl.parse("C"), sl.parse(""), sl.parse(nil)], [nil, nil, nil]
  eq "a Windows LANGID keeps only the primary language: Spanish-Mexico is Spanish", sl::LANGIDS[0x080a & 0x3ff], :es
  eq "and English-Australia is English", sl::LANGIDS[0x0c09 & 0x3ff], :en
  eq "Catalan, Basque and Galician neighbour Spanish", [sl.neighbour(:ca), sl.neighbour(:eu), sl.neighbour(:gl)], [:es, :es, :es]
  eq "a language with no neighbour has none", [sl.neighbour(:ja), sl.neighbour(nil)], [nil, nil]
end

Suite.define("language: the automatic verdict is memoised on the game's language index") do
  i18n = PokeAccess::I18n
  answer = :en
  with_lang_sources(nil, lambda { answer }) do
    $PokemonSystem = Struct.new(:language).new(0)
    eq "first verdict", i18n.lang, :en
    answer = :fr
    eq "the detector changing its mind alone does not move it", i18n.lang, :en
    $PokemonSystem.language = 1
    eq "an in-game language switch re-asks and follows", i18n.lang, :fr
  end
end

Suite.define("language: the menu cycle starts at automatic and names what it resolved to") do
  i18n = PokeAccess::I18n
  langs = i18n.available_languages
  eq "automatic comes first in the cycle", i18n.next_language(:auto), langs.first
  eq "and the last file wraps back to it", i18n.next_language(langs.last), :auto
  with_lang_sources(:en, nil) do
    eq "the automatic entry is labelled with its resolution",
       i18n.language_name(:auto), i18n.t(:lang_auto, :name => "English")
  end
end

# The ini carries a layout version. One written before version 2 holds the old fixed default, Spanish,
# whether chosen or never looked at, so it is turned to :auto exactly once; a versioned ini keeps whatever
# the player chose.
Suite.define("language: auto persists, an old ini migrates to it once, a versioned ini keeps its choice") do
  cfg = PokeAccess::Config
  st = PokeAccess::Settings
  prev = cfg.language
  begin
    cfg.language = :auto
    st.write
    eq "the ini says auto and carries the layout version", [st.read["language"], st.read["settings_version"]], ["auto", st::VERSION.to_s]
    cfg.language = :en
    st.apply
    eq "and reading it back restores the automatic choice", cfg.language, :auto

    File.open(st::FILE, "w") { |f| f.write("language=es\n") }
    st.apply
    eq "an ini from before the version is turned to auto", cfg.language, :auto
    eq "and rewritten with the version, so it happens once", st.read["settings_version"], st::VERSION.to_s

    File.open(st::FILE, "w") { |f| f.write("settings_version=#{st::VERSION}\nlanguage=es\n") }
    cfg.language = :auto
    st.apply
    eq "a versioned ini that names a language keeps it", cfg.language, :es
  ensure
    cfg.language = prev
    (File.delete(st::FILE) rescue nil)
  end
end
