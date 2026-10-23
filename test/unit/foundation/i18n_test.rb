# I18n.t says a key in the active language, else English, else as its own name, filling placeholders and picking the
# language's plural form; parity_of reports how tables fall out of step; the languages are the lang/*.txt files.
class I18nTest < PokeAccessTest
  I18n = PokeAccess::I18n

  test "says a key in the active language" do
    with_entries(:es, "i18n_probe" => "hola") { assert_equal "hola", I18n.t(:i18n_probe) }
  end

  test "says a key the active language lacks in English" do
    with_entries(:en, "i18n_probe_en" => "english only") { assert_equal "english only", I18n.t(:i18n_probe_en) }
  end

  test "says every key in English for a language with no file of its own" do
    PokeAccess::Config.language = :zz
    with_entries(:en, "i18n_probe_en" => "english only") { assert_equal "english only", I18n.t(:i18n_probe_en) }
  ensure
    I18n.instance_variable_get(:@cache).delete(:zz)
  end

  test "says a key no language has as its own name" do
    assert_equal "i18n_no_such_key", I18n.t(:i18n_no_such_key)
  end

  test "fills each placeholder from its var, one with no var with nothing" do
    with_entries(:es, "i18n_count" => "%{n} de %{total}") do
      assert_equal "3 de 9", I18n.t(:i18n_count, :n => 3, :total => 9)
      assert_equal "3 de ", I18n.t(:i18n_count, :n => 3)
    end
  end

  test "leaves the placeholders as written when given no vars" do
    with_entries(:es, "i18n_count" => "%{n} de %{total}") { assert_equal "%{n} de %{total}", I18n.t(:i18n_count) }
  end

  test "picks the plural form the active language's rule gives for :n" do
    polish_forms = { "i18n_tile.one" => "%{n} pole", "i18n_tile.few" => "%{n} pola", "i18n_tile.many" => "%{n} pól" }
    french_forms = { "i18n_tile.one" => "%{n} case", "i18n_tile.other" => "%{n} cases" }
    said = { [:pl, 1] => "1 pole", [:pl, 3] => "3 pola", [:pl, 5] => "5 pól", [:pl, 22] => "22 pola",
             [:fr, 0] => "0 case", [:fr, 2] => "2 cases" }
    with_entries(:pl, polish_forms) do
      with_entries(:fr, french_forms) do
        said.each do |(code, n), want|
          PokeAccess::Config.language = code
          assert_equal want, I18n.t(:i18n_tile, :n => n), "#{code} #{n}"
        end
      end
    end
  end

  test "takes English's form by English's rule when the active language lacks the key" do
    PokeAccess::Config.language = :fr
    with_entries(:en, "i18n_cup.one" => "%{n} cup", "i18n_cup.other" => "%{n} cups") do
      assert_equal "0 cups", I18n.t(:i18n_cup, :n => 0), "French would say the singular for 0"
    end
  end

  test "says one for 1 alone in English, Spanish and German" do
    { [:en, 1] => "one", [:en, -1] => "one", [:en, 0] => "other", [:en, 2] => "other", [:es, 1] => "one",
      [:es, 2] => "other", [:de, 1] => "one", [:de, 21] => "other" }.each do |(code, n), want|
      assert_equal want, I18n.plural_form(code, n), "#{code} #{n}"
    end
  end

  test "says one for 0 and 1 in French and Portuguese, counting a decimal by its whole part" do
    { [:fr, 0] => "one", [:fr, 1] => "one", [:fr, 2] => "other", [:pt, 1] => "one", [:pt, 2] => "other",
      [:fr, 1.5] => "one", [:pt, 0.4] => "one", [:fr, 14.5] => "other" }.each do |(code, n), want|
      assert_equal want, I18n.plural_form(code, n), "#{code} #{n}"
    end
  end

  test "says one, few for 2 to 4 bar 12 to 14 in each hundred, and many for the rest in Polish" do
    { 1 => "one", 2 => "few", 3 => "few", 4 => "few", 5 => "many", 12 => "many", 13 => "many", 14 => "many",
      21 => "many", 22 => "few", 0 => "many", 104 => "few", 112 => "many", -3 => "few" }.each do |n, want|
      assert_equal want, I18n.plural_form(:pl, n), "pl #{n}"
    end
  end

  test "says other for a decimal where the language counts whole numbers, a whole one counting as its number" do
    { [:en, 1.5] => "other", [:es, 0.5] => "other", [:pl, 2.5] => "other", [:en, 1.0] => "one",
      [:pl, 3.0] => "few" }.each do |(code, n), want|
      assert_equal want, I18n.plural_form(code, n), "#{code} #{n}"
    end
  end

  test "counts a missing or unreadable count as 0" do
    counts = { [:en, nil] => "other", [:fr, nil] => "one", [:pl, nil] => "many", [:en, Object.new] => "other" }
    counts.each do |(code, n), want|
      assert_equal want, I18n.plural_form(code, n), "#{code} #{n.inspect}"
    end
  end

  test "writes three plural forms in Polish and two in the other languages" do
    forms = { :pl => %w[one few many], "pl" => %w[one few many], :es => %w[one other], :fr => %w[one other] }
    forms.each do |code, want|
      assert_equal want, I18n.plural_forms(code), code.inspect
    end
  end

  test "finds tables in step when each writes the forms its rule asks for" do
    assert_equal [], I18n.parity_of(:en => english, :pl => polish)
  end

  test "finds tables in step when one writes a key plainly and another by forms" do
    assert_equal [], I18n.parity_of(:en => english, :es => { "a" => "%{n} z" })
  end

  test "reports a plural form a language's rule asks for and its table lacks" do
    assert_equal ["pl:a.many: plural form missing"],
                 I18n.parity_of(:en => english, :pl => polish.reject { |k, _v| k == "a.many" })
  end

  test "reports a plural form the language does not have" do
    assert_equal ["en:a.few: not a plural form of en"],
                 I18n.parity_of(:en => english.merge("a.few" => "%{n} x"), :pl => polish)
  end

  test "reports a key written both plainly and by forms" do
    assert_equal ["en:a: written both plain and by plural forms"],
                 I18n.parity_of(:en => english.merge("a" => "%{n} x"), :pl => polish)
  end

  test "reports a key whose placeholders differ between its texts" do
    assert_equal ['a: placeholders differ (en=["m", "n"] pl=["n"])'],
                 I18n.parity_of(:en => english.merge("a.other" => "%{m} xs"), :pl => polish)
  end

  test "reports a key a language lacks" do
    assert_equal ["es:a: missing"], I18n.parity_of(:en => english, :es => {})
  end

  test "leaves out of parity the keys that start with two underscores" do
    assert_equal [], I18n.parity_of(:en => { "__language__" => "English" }, :es => {})
  end

  test "lists the languages of the installed folder, then the source tree's, each once" do
    files = ["accessibility/lang/es.txt", "accessibility/lang/xx.txt", "lang/es.txt", "lang/yy.txt"]
    assert_equal [:es, :xx, :yy], in_lang_folder(files) { I18n.available_languages }
  end

  test "falls back to English alone when it finds no language file" do
    assert_equal [:en], in_lang_folder([]) { I18n.available_languages }
  end

  test "offers the automatic choice first, then each language with a file" do
    assert_equal [:auto] + I18n.available_languages, I18n.language_choices
  end

  test "writes a fraction with the active language's decimal separator, a whole number as is" do
    with_entries(:es, "decimal_sep" => " coma ") do
      assert_equal ["2 coma 5", "3"], [I18n.number(2.5), I18n.number(3)]
    end
  end

  private

  # Runs the block with entries added to a language's table, the table put back as it was after.
  def with_entries(code, entries)
    table = I18n.table(code)
    saved = table.dup
    table.merge!(entries)
    yield
  ensure
    table.replace(saved) if table
  end

  # The block's value run from a fresh working folder holding these language files (paths relative to it), the
  # languages listed afresh there; the working folder and the list known before are put back after.
  def in_lang_folder(files)
    saved = I18n.instance_variable_get(:@langs)
    Dir.mktmpdir("i18n-langs") do |dir|
      files.each do |rel|
        FileUtils.mkdir_p(File.dirname(File.join(dir, rel)))
        File.write(File.join(dir, rel), "__language__=probe\n")
      end
      Dir.chdir(dir) do
        I18n.instance_variable_set(:@langs, nil)
        yield
      end
    end
  ensure
    I18n.instance_variable_set(:@langs, saved)
  end

  # An English table writing key "a" by its two forms.
  def english
    { "a.one" => "%{n} x", "a.other" => "%{n} xs" }
  end

  # A Polish table writing key "a" by its three forms.
  def polish
    { "a.one" => "%{n} y", "a.few" => "%{n} yy", "a.many" => "%{n} yyy" }
  end
end
