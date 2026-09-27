# i18n parity over the real lang/ files: every key in all languages, none duplicated, matching %{var} placeholders.
# The guards first: an unreachable lang/ folder or a table that failed to load also yields an empty issue list.
Suite.define("i18n: lang/ files are in parity (keys, duplicates, placeholders)") do
  langs = (PokeAccess::I18n.available_languages rescue [])
  truthy "the language files are visible to the checker", langs.length >= 2
  langs.each { |c| truthy "lang/#{c}.txt loaded", (PokeAccess::I18n.table(c).length rescue 0) > 100 }

  issues = (PokeAccess::I18n.parity_issues rescue ["parity check raised"])
  eq "no parity issues across language files", issues, []
end
