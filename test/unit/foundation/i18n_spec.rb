# I18n.t reads the active language, falls back to the key name, interpolates %{var} placeholders; the languages are
# the lang/*.txt files. Spanish is checked only as present and different from English.
Suite.define("i18n: lookup, fallback, interpolation, available languages") do
  PokeAccess::Config.language = :en
  eq "english value from en.txt", PokeAccess::I18n.t(:cfg_saved), "Settings saved"
  eq "missing key falls back to the key name",
     PokeAccess::I18n.t(:clave_inexistente_xyz), "clave_inexistente_xyz"
  eq "interpolation fills placeholders",
     PokeAccess::I18n.t(:loc_count, :n => 3, :total => 9), "3 of 9"

  PokeAccess::Config.language = :es
  truthy "spanish entry exists and differs from english",
         PokeAccess::I18n.t(:cfg_saved) != "Settings saved" && !PokeAccess::I18n.t(:cfg_saved).empty?
  truthy "es and en are both available",
         PokeAccess::I18n.available_languages.include?(:es) &&
         PokeAccess::I18n.available_languages.include?(:en)
  PokeAccess::Config.language = :es
end

# Plural forms follow each language's CLDR rule: English, Spanish and German say the singular for 1 only;
# French and Brazilian Portuguese for 0 and 1; Polish has one, few (2-4 but not 12-14) and many.
Suite.define("i18n: the plural form of a count follows the language's rule") do
  i = PokeAccess::I18n
  eq "english: 1 is one", i.plural_form(:en, 1), "one"
  eq "english: 0 is other", i.plural_form(:en, 0), "other"
  eq "spanish: 2 is other", i.plural_form(:es, 2), "other"
  eq "german: 21 is other", i.plural_form(:de, 21), "other"
  eq "french: 0 is one", i.plural_form(:fr, 0), "one"
  eq "french: 2 is other", i.plural_form(:fr, 2), "other"
  eq "portuguese: 1 is one", i.plural_form(:pt, 1), "one"
  eq "polish: 1 is one", i.plural_form(:pl, 1), "one"
  eq "polish: 2, 3 and 4 are few", [2, 3, 4].map { |n| i.plural_form(:pl, n) }, %w[few few few]
  eq "polish: 5, 12, 13 and 14 are many", [5, 12, 13, 14].map { |n| i.plural_form(:pl, n) }, %w[many many many many]
  eq "polish: 22 and 104 are few, 21, 0 and 112 many", [22, 104, 21, 0, 112].map { |n| i.plural_form(:pl, n) },
     %w[few few many many many]
  eq "a missing count reads as 0", [i.plural_form(:en, nil), i.plural_form(:pl, nil)], %w[other many]
  eq "a decimal takes other in english, and counts by its whole part in french and portuguese",
     [i.plural_form(:en, 1.5), i.plural_form(:fr, 1.5), i.plural_form(:pt, 0.4), i.plural_form(:fr, 14.5)], %w[other one one other]
  eq "polish writes three forms", i.plural_forms(:pl), %w[one few many]
  eq "spanish writes two", i.plural_forms(:es), %w[one other]
end

Suite.define("i18n: t picks the plural form for :n, and falls back with the reference's own rule") do
  PokeAccess::Config.language = :en
  eq "english singular", PokeAccess::I18n.t(:tr_badges, :n => 1), "1 badge"
  eq "english plural", PokeAccess::I18n.t(:tr_badges, :n => 3), "3 badges"
  PokeAccess::Config.language = :pl
  eq "polish tile unit for 1, 3, 5 and 22", [1, 3, 5, 22].map { |n| PokeAccess::I18n.t(:tiles_unit, :n => n) },
     %w[pole pola pól pola]
  PokeAccess::Config.language = :fr
  eq "french says the singular for 0", PokeAccess::I18n.t(:tr_badges, :n => 0), "0 badge"
  PokeAccess::Config.language = :zz
  eq "a language without the key falls back to the english form", PokeAccess::I18n.t(:tr_badges, :n => 1), "1 badge"
  PokeAccess::Config.language = :es
end

Suite.define("i18n: parity checks plural forms against each language's rule") do
  i = PokeAccess::I18n
  en = { "a.one" => "%{n} x", "a.other" => "%{n} xs" }
  pl = { "a.one" => "%{n} y", "a.few" => "%{n} yy", "a.many" => "%{n} yyy" }
  eq "forms as each rule asks are in parity", i.parity_of(:en => en, :pl => pl), []
  eq "a plain entry in one language and forms in another are in parity",
     i.parity_of(:en => en, :es => { "a" => "%{n} z" }), []
  truthy "a form the rule asks for is missing",
         i.parity_of(:en => en, :pl => pl.reject { |k, _v| k == "a.many" }).include?("pl:a.many: plural form missing")
  truthy "a form the language does not have",
         i.parity_of(:en => en.merge("a.few" => "%{n} x"), :pl => pl).include?("en:a.few: not a plural form of en")
  truthy "written both plain and by forms",
         i.parity_of(:en => en.merge("a" => "%{n} x"), :pl => pl).include?("en:a: written both plain and by plural forms")
  truthy "forms with different placeholders",
         i.parity_of(:en => en.merge("a.other" => "%{m} xs"), :pl => pl).any? { |s| s.index("a: placeholders differ") == 0 }
  truthy "a key missing in a language", i.parity_of(:en => en, :es => {}).include?("es:a: missing")
end
