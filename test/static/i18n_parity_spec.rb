# i18n parity over the real lang/ files: every key present in all languages, no key duplicated within a
# file, and matching %{var} placeholders across languages -- any of those breaks a string in one language
# (the usual cause of an English line in a Spanish game). Unlike the runner's non-failing parity warning,
# this spec asserts the issue list is empty, so a release with a drifted string fails CI.
#
# The two guards before it exist because the empty list is ALSO what a check that read nothing returns, and
# this spec would pass in exactly that state: available_languages globs RELATIVE paths
# ("accessibility/lang/*.txt" and "lang/*.txt"), so run from anywhere but the repo root it finds no file,
# falls back to [:en], and parity_issues short-circuits on "return [] if langs.length < 2". Verified: from
# C:\ the suite reports one green assert having compared nothing. parity_issues also swallows any
# exception into [], so two tables that failed to load would look identical to two tables in perfect sync
# -- hence the size guard as well, the same shape as i18n_refs_spec's "lang/en.txt loaded".
Suite.define("i18n: lang/ files are in parity (keys, duplicates, placeholders)") do
  langs = (PokeAccess::I18n.available_languages rescue [])
  truthy "both language files are visible to the checker", langs.length >= 2
  langs.each { |c| truthy "lang/#{c}.txt loaded", (PokeAccess::I18n.table(c).length rescue 0) > 100 }

  issues = (PokeAccess::I18n.parity_issues rescue ["parity check raised"])
  eq "no parity issues across language files", issues, []
end
