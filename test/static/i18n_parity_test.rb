# The shipped lang/ files are in parity: every key in every language, none twice in a file, the same %{var}s and the
# plural forms each language's rule asks for; the check reports each of those faults planted in a file of its own,
# and none while a language stands alone.
require "tmpdir"
require "fileutils"

class I18nParityTest < PokeAccessTest
  I18n = PokeAccess::I18n
  LANG = File.expand_path("../../lang", File.dirname(__FILE__))

  test "sees every language file in lang/ and loads each one" do
    codes = Dir.glob(File.join(LANG, "*.txt")).map { |f| File.basename(f, ".txt").to_sym }.sort
    assert_operator codes.length, :>=, 2, "lang/ ships several languages"
    assert_equal codes, I18n.available_languages.sort
    assert_equal [], codes.reject { |c| I18n.table(c).length > 100 }, "languages whose table came back nearly empty"
  end

  test "finds the shipped language files in parity" do
    tables = {}
    I18n.available_languages.each { |code| tables[code] = I18n.table(code) }
    assert_equal [], I18n.parity_of(tables), "compared without the rescue that would pass a crash off as parity"
    assert_equal [], I18n.parity_issues, "no key written twice in a file either"
  end

  test "the French file asks the player with tu throughout, never with the vous of Appuyez" do
    assert_equal [], I18n.table(:fr).select { |_key, text| text.to_s.include?("Appuyez") }.map { |key, _text| key }
  end

  test "reports a key missing from a language, a key written twice and placeholders that differ" do
    issues = with_lang_files("en" => "__credits__=Team\ngreet=Hello %{name}\nbye=Bye\nbye=Bye again\n",
                             "es" => "greet=Hola %{nombre}\n") { I18n.parity_issues }
    assert_equal ["en:bye: duplicated", "es:bye: missing",
                  "greet: placeholders differ (en=[\"name\"] es=[\"nombre\"])"],
                 issues.sort, "a key starting with __ belongs to one language and is not missing from the other"
  end

  test "reports plural forms a language's rule misses or does not have, and a key written both ways" do
    files = { "en" => "item.one=%{n} item\nitem.other=%{n} items\nseen=Seen\nseen.one=Seen once\n",
              "pl" => "item.one=%{n} rzecz\nitem.other=%{n} rzeczy\nseen=Widziane\n" }
    issues = with_lang_files(files) { I18n.parity_issues }
    assert_equal ["en:seen: written both plain and by plural forms", "pl:item.few: plural form missing",
                  "pl:item.many: plural form missing", "pl:item.other: not a plural form of pl"], issues.sort
  end

  test "checks nothing until a second language sits beside one, even the lone file's own faults" do
    faulty = "seen=Seen\nseen.one=Seen once\nseen.other=Seen often\nbye=Bye\nbye=Bye again\n"
    assert_equal [], with_lang_files("en" => faulty) { I18n.parity_issues }, "alone, it is checked against nothing"
    paired = with_lang_files("en" => faulty, "es" => "seen=Visto\nbye=Hasta luego\n") { I18n.parity_issues }
    assert_equal ["en:bye: duplicated", "en:seen: written both plain and by plural forms"], paired.sort,
                 "the same file beside a second language"
  end

  test "reports nothing for planted files in parity" do
    issues = with_lang_files("en" => "item.one=%{n} item\nitem.other=%{n} items\ngreet=Hi %{a} %{b}\n",
                             "pl" => "item.one=%{n} a\nitem.few=%{n} b\nitem.many=%{n} c\ngreet=Hej %{b} %{a}\n") do
      I18n.parity_issues
    end
    assert_equal [], issues, "placeholders in another order and each language's own plural forms are parity"
  end

  private

  # The block's value with the mod's lang folder holding only files ({ code => text }), read from a throwaway
  # working directory as the game reads accessibility/lang from its own; the shipped tables come back after.
  def with_lang_files(files)
    langs = I18n.instance_variable_get(:@langs)
    cache = I18n.instance_variable_get(:@cache)
    Dir.mktmpdir("pa-lang") do |dir|
      folder = File.join(dir, PokeAccess::Paths::LANG)
      FileUtils.mkdir_p(folder)
      files.each { |code, text| File.binwrite(File.join(folder, "#{code}.txt"), text) }
      I18n.instance_variable_set(:@langs, nil)
      I18n.instance_variable_set(:@cache, {})
      Dir.chdir(dir) { yield }
    end
  ensure
    I18n.instance_variable_set(:@langs, langs)
    I18n.instance_variable_set(:@cache, cache)
  end
end
