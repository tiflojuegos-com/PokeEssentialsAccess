# Language files

This page describes the files in `lang/` that hold the mod's own spoken text: their format, keys, placeholders,
plural forms and the checks the suite runs on them. How the mod chooses a language and falls back to English is
explained in [Speech and languages](../architecture/speech-and-languages.md).

## Files

| Code | File | `__language__` | Plural forms |
|---|---|---|---|
| `de` | `lang/de.txt` | Deutsch | `one`, `other` |
| `en` | `lang/en.txt` | English | `one`, `other` |
| `es` | `lang/es.txt` | Español | `one`, `other` |
| `fr` | `lang/fr.txt` | Français | `one`, `other` |
| `pl` | `lang/pl.txt` | Polski | `one`, `few`, `many` |
| `pt` | `lang/pt.txt` | Português | `one`, `other` |

- The file name without `.txt` is the language code the `language` setting stores. `pt` is Brazilian Portuguese.
- English is the reference language (`I18n::REFERENCE`). A key another file lacks is said from `lang/en.txt`.
- In a game, the files live in `accessibility/lang/` (`Paths::LANG`), where the launcher installs them. The mod reads
  that folder first and then `lang/` under the working directory, which is how the suite reads the source tree. A
  code found in both places is listed once.
- A file is read at its language's first lookup and kept in memory (`I18n.table`).

## Line format

- `key=text`: a data line. The key is what comes before the first `=`, without surrounding spaces. The text is the
  rest of the line after that `=`, spaces included, so `key= text` starts with a space. An `=` inside the text is part
  of it, as in the text of `ss2_two_voices`, which tells the player to set `TTS_ENABLED = false`.
- `# comment`: a line whose first character other than a space is `#`. The files group their keys under comments,
  such as `# battle` or `# raids (soulstones 2)`.
- Blank line: skipped.
- Any other line: a line without `=`, or with nothing before its `=`, is skipped without a report.

Each text takes one line. The files are UTF-8: a byte order mark before the first line is dropped, and invalid bytes
become `?` where the game's Ruby has `String#scrub`. A key written twice keeps its later text, and the parity check
reports it.

A text holds no control code. The suite fails when a line reaches `speak` with a backslash code, a markup tag such as
`<b>` or a `|` in it (`test/run.rb`).

```
# lang/en.txt
# raids (soulstones 2)
ss2_shield_broken=Shield broken, %{n} left
```

## Keys

- Characters: lowercase ASCII letters, digits and underscores. A plural form adds its suffix: `.one`, `.few`, `.many`
  or `.other`.
- Prefixes: the keys of a profile or a plugin reader start with a short prefix of their own, such as `ss2_`
  (Soulstones 2), `rea_` (Realidea) or `ura_` (Uranium).
- Metadata: a key that starts with two underscores belongs to its file alone and stays out of the parity check.

Some keys are read by name:

| Key | Read by | Text |
|---|---|---|
| `__language__` | `I18n.language_name` | The language's own name, said by the `language` setting |
| `decimal_sep` | `I18n.number` | The decimal separator: `.` in English, `,` in Spanish |
| `lang_auto` | `I18n.language_name` | The automatic choice's name, with `%{name}` for the language it resolves to |

## Lookup

`I18n.t(key, vars)` returns the first text found in this order:

1. The active language's plain entry for `key`.
2. The active language's plural form of `key` for `vars[:n]`.
3. The same two in English, the form chosen by English's rule.
4. The key's own name, as a string.

## Placeholders

- Syntax: `%{name}`, where the name is letters, digits and underscores.
- Values: `I18n.t(:key, :name => value)` puts `value.to_s` in each placeholder. A placeholder whose name the hash
  lacks becomes an empty string. Called without a hash, `t` returns the text with its placeholders as written.
- Names: the names the code passes, identical in every file and every plural form of a key, in any order. They are not
  translated: `load_save=%{name}'s save` in English is `load_save=Partida de %{name}` in Spanish.
- Numbers: a fraction becomes text with a dot. `I18n.number(x)` writes it with the language's `decimal_sep` instead.

## Plural forms

A key whose words change with a number is written once per form of its language: `key.one=` and `key.other=`, or in
Polish `key.one=`, `key.few=` and `key.many=`. The code passes the count as `:n`. The rules compare the count's
absolute value, and a missing `:n` counts as 0.

- `de`, `en`, `es`: `one` for 1, `other` for any other count and for any fraction.
- `fr`, `pt`: `one` for 0 and 1, `other` from 2. A fraction counts by its whole part, so 1.5 takes `one`.
- `pl`: `one` for 1; `few` when the last digit is 2, 3 or 4 and the last two digits are not 12, 13 or 14; `many` for
  the rest, 0 included.

The rules are declared in `I18n::PLURAL_RULES` and applied by `I18n.plural_form`. A language not declared there takes
the rule of `de`, `en` and `es`. A fraction takes `other` in Polish, a form Polish does not write, so the lookup falls
through to English; a Polish key written by forms takes whole counts only.

Each file decides alone how to write a key: plainly, when its words read the same for any count, or by forms. Within
one file a key is written one way only. When the active language lacks the key, English's text is chosen by
English's rule: with French active and the key only in English, a count of 0 takes the English `other` form.

```
# lang/en.txt
ss2_shield_broken=Shield broken, %{n} left
# lang/es.txt
ss2_shield_broken.one=Escudo roto, queda %{n}
ss2_shield_broken.other=Escudo roto, quedan %{n}
# lang/pl.txt
ss2_shield_broken.one=Tarcza rozbita, została %{n}
ss2_shield_broken.few=Tarcza rozbita, zostały %{n}
ss2_shield_broken.many=Tarcza rozbita, zostało %{n}
```

```ruby
# games/soulstones2/boss_shields.rb
PokeAccess.speak(PokeAccess::I18n.t(:ss2_shield_broken, :n => [left, 0].max), false)
```

## Checks

Two static tests check the files on every run of the suite, and `ruby test/run_all.rb static/i18n` runs them alone.
The boot does not check parity (`test/behavior/foundation/boot_loader_test.rb`).

### Parity check

`test/static/i18n_parity_test.rb` compares every file in the language folder through `I18n.parity_issues`. It
reports nothing while only one file exists. Keys that start with two underscores are skipped. Each issue is one line:

| Issue | Meaning |
|---|---|
| `<code>:<key>: missing` | Another file has the key and this one does not |
| `<code>:<key>: duplicated` | The file writes the key twice |
| `<key>: placeholders differ (...)` | The texts of the key, forms included, use different placeholder names |
| `<code>:<key>: written both plain and by plural forms` | The file writes the key both ways |
| `<code>:<key>.<form>: plural form missing` | The file writes the key by forms and lacks one its rule asks for |
| `<code>:<key>.<form>: not a plural form of <code>` | The file writes a form its rule does not have |

The same test fails when a French text contains `Appuyez`: the French file addresses the player as tu.

### References check

`test/static/i18n_refs_test.rb` checks that every key the code names exists in `lang/en.txt`; a key's plural forms
make its base key present. A missing key is reported as `<key> (<file>)`. The test reads the Ruby files of `core/`,
`games/` and `plugins/`, comments left out, for these references:

- `I18n.t(:key)` calls, and short `t(:key)` calls such as those of `ConfigMenu.t`.
- The symbols given to a row's `:label` and `:help`.
- The name and help of each `define_reading` declaration.
- The keys of a profile's `names(:table, ...)` calls.
- The keys of a constant table indexed inside a `t(` call, such as `I18n.t(CATEGORIES[c])` in
  `core/battle/move_info.rb`, read from the table's literal in the same file, and the fallback of such a call.
- The mod's own tables that reach `I18n.t`, such as the settings, their groups and units and the speech categories
  (`mod_tables` in the test).

A key built at run time, such as `:"chr_#{kind}"` in `games/infinitefusion_common/character_creator.rb`, escapes the
scan.
