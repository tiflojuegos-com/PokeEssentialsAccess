# Add spoken text

This guide adds a sentence in the mod's own words: a key in every file of `lang/`, the call that says it and the test
that checks it. Follow it when a [reader](../reference/glossary.md) or another part of the mod needs to say something
the game does not show as text.

## Starting point

A reader, or another part of the mod, has something to say that the game does not write, such as a position, a state
or a hint. The example adds `ss2_shield_broken`, which the Soulstones 2 profile says when a boss loses a shield
(`games/soulstones2/boss_shields.rb`).

## Steps

1. Check that the words are the mod's own. When the game shows them, as a window's text, a painted label or a name in
   its data, read them from the game instead: a fangame can ship one build per language, and words copied into
   `lang/` are wrong in the other builds. When the game shows them only in a picture, transcribe them per build in the
   profile with `picture_texts_multibuild`
   ([Game text in several builds](../architecture/speech-and-languages.md#game-text-in-several-builds)).

2. Search for a key that already says the sentence, and reuse it when its text fits in every language:
   `rg -n "=Shield broken" lang/en.txt`.

3. Choose a name for a new key: lowercase words joined by underscores, with the prefix of the profile or plugin reader
   the text belongs to, such as `ss2_` for Soulstones 2. Check that the name is free:
   `rg -n "^ss2_shield_broken[.=]" lang/`.

4. Add the key to `lang/en.txt`, under the `#` comment of its area, with a `%{name}` placeholder for each value the
   code inserts:

   ```
   # lang/en.txt
   # raids (soulstones 2)
   ss2_shield_broken=Shield broken, %{n} left
   ```

5. Write the text in the mod's voice:
   - Keep it impersonal. The mod is a program and never speaks in the first person: `loc_route_gave_up` says "the
     route could not be calculated from here".
   - Address the player as one person, in the form each file uses: tú in Spanish (`Pulsa`), du in German (`Drücke`),
     tu in French (`Appuie`), ty in Polish (`Naciśnij`) and você in Portuguese (`Pressione`). The parity check fails
     on a French text with `Appuyez`.
   - Use each language's official Pokémon terms, checked against the text the games paint.

6. Add the key to every other file in `lang/`, under the same comment and with the same placeholder names. Translate
   the text and keep the names: `%{n}` stays `%{n}` in every file.

7. Decide in each file whether the words change with the count. Where they do, write the forms of that language's
   rule and no others: `.one` and `.other`, or `.one`, `.few` and `.many` in Polish. Where the text reads the same for
   any count, as `Shield broken, %{n} left` does in English, keep the key plain. The rules are in the
   [language files reference](../reference/lang-files.md#plural-forms).

   ```
   # lang/es.txt
   ss2_shield_broken.one=Escudo roto, queda %{n}
   ss2_shield_broken.other=Escudo roto, quedan %{n}
   # lang/pl.txt
   ss2_shield_broken.one=Tarcza rozbita, została %{n}
   ss2_shield_broken.few=Tarcza rozbita, zostały %{n}
   ss2_shield_broken.many=Tarcza rozbita, zostało %{n}
   ```

8. Say the text from the code with `I18n.t` and `speak`:

   ```ruby
   # games/soulstones2/boss_shields.rb
   PokeAccess.speak(PokeAccess::I18n.t(:ss2_shield_broken, :n => [left, 0].max), false)
   ```

   - Name the key as a literal symbol inside the `t(` call. The references check reads that form, and a key built at
     run time escapes it.
   - Pass the count as `:n` whenever a file writes the key by forms. Write the hash in the Ruby 1.8.7 form,
     `:n => left`.
   - Pass game text through `PokeAccess.clean` before it fills a placeholder. The suite fails a line that reaches
     `speak` with a control code.
   - Pass `true` as the interrupt flag when the line answers the player's own key or cursor move, and `false` when it
     follows another line or a message of the game
     ([Interrupting and queueing](../architecture/speech-and-languages.md#interrupting-and-queueing)).

9. Delete from every file the keys that the change leaves unused. No check reports an unused key.

10. Test the line in the reader's test. The [suite](../reference/glossary.md) sets the mod's language to Spanish
    before each test (`test/support/reset.rb`). Build the expected text with `I18n.t` and compare it with
    `SpeakCapture.log`, which holds each line with its interrupt flag, or match the line with `assert_spoken`:

    ```ruby
    # test/behavior/battle/ss2_boss_shields_gd_test.rb
    def broken(left)
      PokeAccess::I18n.t(:ss2_shield_broken, :n => left)
    end

    assert_equal [[broken(0), false], [refill, false]], SpeakCapture.log
    ```

11. Run the two language checks, then the whole suite: `ruby test/run_all.rb static/i18n`, then
    `ruby test/run_all.rb` ([Tests](tests.md)).

## Result

The [parity check](../reference/glossary.md) and the references check pass, and the reader's test finds the line
with its interrupt flag. A failing check names the key with its language or with the file that uses it, such as
`pl:ss2_shield_broken.few: plural form missing` or `ss2_shield_broken (boss_shields.rb)`. The
[language files reference](../reference/lang-files.md#checks) lists every message.

A game reads its own copy of the files, in `accessibility/lang/`. Install the mod again to hear the new text in a game
([Install and release](install-and-release.md)), and start the game again if it was running.
