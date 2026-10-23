# Speech and languages

This page explains how a line reaches the player and in which language: the speech output, the screen reader
bridge, braille, interrupting and queueing, the choice of the mod's language and the game's own text in fangames
shipped as one build per language. The format of the files in `lang/` is in the
[language files reference](../reference/lang-files.md), and [Add spoken text](../guides/add-spoken-text.md) adds a
line.

## The speech output

Every line the mod says goes through the speech output, `PokeAccess.speak(text, interrupt, category)` in
`core/speech/speech.rb`. `speak` collapses the line's whitespace and drops an empty line. It numbers the line
(`PokeAccess.spoken_seq`), wraps it in a `Speech::Message` with its text, category, interrupt flag and number, and
hands that message to every observer. Then `PokeAccess.voice_out` passes the text to the screen reader bridge.

Observers register with `Speech.observe`. The message history (`core/speech/history.rb`) and the session recorder
(`core/util/recorder.rb`) see every line this way ([Readers](readers.md), [Diagnostics](diagnostics.md)). An
observer that raises is logged once and skipped. An exception inside `speak` goes to the marker file, so a
[reader](../reference/glossary.md) that speaks never stops the game.

`voice_out` is the only place where spoken text leaves the mod. The [suite](../reference/glossary.md) replaces it
(`test/support/speak_capture.rb`) and records each line with its interrupt flag, so a test asserts the exact text and
flag the screen reader would receive.

## Game text and control codes

Text taken from the game carries the codes of its message system: `\PN` for the player's name, `\V[n]` for a game
variable, `\C[n]` for a colour, name-box codes such as `\xn[...]`, markup tags and character entities.
`PokeAccess.clean` (`core/speech/text.rb`) makes such text speakable. It substitutes the player's name, the money and
the variables, puts a name box's speaker before the line as `name: `, reads `<br>` as a space, decodes the entities
and removes every other code. `PokeAccess.speak_clean` cleans and speaks in one call.

A name box that shows only question marks, as a hidden speaker's does, is said as the word for an unknown speaker
(`msg_speaker_unknown`), since screen readers drop question marks. A [profile](../reference/glossary.md) whose game
rewrites the name on its way to the box registers the rewrite with `PokeAccess.register_name_filter`.

The suite fails a run in which a line reaches `speak` with a code still in it: a backslash code, a markup tag, a bare
`|` or a control byte (`test/run.rb`). Game text goes through `clean` before it is spoken or placed into one of the
mod's sentences.

## Speech categories

Each line has a speech category, one of `Speech::CATEGORIES`: `:dialogue`, `:battle`, `:menu`, `:nav`, `:info` or
`:system`. The message history files lines by category, and the player browses all of them or one category at a time
([Message history](readers.md#message-history)). The history's own readouts take `Speech::REVIEW` instead, which
keeps them out of the history.

A line takes the category its `speak` call names. Without one, it takes the category of the innermost `Speech.as`
block running. Without either, it takes the one `Speech.deduce` reads from the moment: `:battle` during a fight,
`:dialogue` while a message is shown, `:menu` off the map or in its pause menu, and `:nav` otherwise.

`Speech.as` blocks give whole areas their category. The map frame ([Loading](loading.md#map-frame)) runs its `:world`,
`:control` and `:nav` stages inside `Speech.as(:nav)` (`core/input/frame.rb`). The info, HP and field keys speak
inside `Speech.as(:info)`, the coordinates and marker keys inside `Speech.as(:nav)`, and the Ctrl+Alt gestures inside
`Speech.as(:system)` (`core/input/input.rb`). The configuration menu runs inside `Speech.as(:system)` too.

## Interrupting and queueing

The `interrupt` flag decides what happens to speech already playing, and it defaults to true. A line with `interrupt`
true cuts that speech off and is heard at once. A line with `interrupt` false is queued and heard when the screen
reader has finished what came before. The flag reaches the screen reader unchanged, as the second argument of
`PeaSpeak`.

Readers choose the flag by what caused the line. A line that answers the player's own action interrupts, and a line
the game produces by itself is queued:

- A cursor move interrupts. `Cursor.announce` speaks with `interrupt` true unless the reader passes false.
- Every dialogue line is queued (`PokeAccess.say_dialogue` in `core/dialogue/dialogue.rb`), so a message never cuts
  off the one before it. With the `dialogue_pages` setting on, the mod reads a message page by page, and each page
  interrupts the previous one (`core/dialogue/pages.rb`).
- A screen's opening summary is queued behind whatever opened it (`Hooks.read_on_open`). The `first_interrupt`
  argument of `Cursor.announce` lets the first row of a new cursor wait behind it too, as in
  `plugins/rse_starters.rb`.
- A line promised for after the next dialogue line, such as a hatchling's shiny sparkle, is queued after that line
  (`PokeAccess.after_next_line`).
- A command window row that changes while the cursor stays still interrupts only when nothing was said since its
  last read, and otherwise waits behind what was said (`Menus.read_interrupts?`,
  [Interrupting and queueing](readers.md#interrupting-and-queueing)).

`PokeAccess.stop_speech` silences the screen reader without saying anything new; the credits reader calls it when the
roll ends or is skipped (`core/menus/credits.rb`). Pausing and resuming speech work only on some backends. The
[reading APIs reference](../reference/reading-apis.md#screen-reader-bridge) lists these calls and their return values.

## The screen reader bridge

The mod speaks through prism, a library that drives screen readers and speech engines. The bridge asks prism for its
best backend (`prism_registry_create_best` in `bridge/prism_pea.c`), and prism decides the order in which its backends
are tried.

The game's Ruby calls native code through `Win32API`, which passes only integers and strings. A small C bridge,
`prism_pea.dll` (`bridge/prism_pea.c`), wraps prism's handle-based interface in plain functions of that shape, such
as `PeaInitialize`, `PeaSpeak` and `PeaBraille`. The prism handles stay inside the DLL, since a pointer handed back
to Ruby would be truncated in a 64-bit game.

Both DLLs, `prism.dll` and `prism_pea.dll`, ship in a 32-bit and a 64-bit build, in `assets/x86/` and
`assets/x64/`. The launcher installs the pair
that matches the game into the game's `accessibility/lib` folder (`Paths::LIB`). `core/speech/backend.rb` adds that
folder to the DLL search path and binds each function. A function that does not bind leaves its constant nil, and
the calls that use it do nothing. `bridge/build_prism_pea.ps1` builds the bridge for both architectures from a prism
checkout.

### Starting and recovering

The bridge starts on first use: `PokeAccess.init_speech!` calls `PeaInitialize` once. A failure is logged once as
`prism_init` and kept, and the mod says nothing until the player turns it off and on again with Ctrl+Alt+F8, which
calls `PokeAccess.retry_init!` ([Keys](../reference/keys.md)). Inside the bridge, a `PeaSpeak` that fails acquires
the best backend again and retries the line once.

The bridge is never shut down. `PeaShutdown` stays unbound, because the mod has no point where it stops and a call
could cut off a line being read. The game's exit releases the backend.

When `backend.rb` loads, it writes `prism=true` or `prism=false` to the marker file, telling whether the bridge
bound. The diagnostic dump's `voice:` line shows whether the bridge is up, the backend's name
(`PokeAccess.speech_backend`, such as `NVDA`) and whether it is speaking ([Diagnostics](diagnostics.md)).

## Braille

The bridge sends spoken lines through prism's speech call, and the mod writes to the braille display only through
`PokeAccess.braille`. `braille` sends text to the display without speaking it. `PokeAccess.braille_codepoints` sends
Unicode code points, such as the braille patterns from U+2800, encoded as UTF-8 by `codepoints_to_utf8`, which works
in Ruby 1.8.7 and skips code points above U+FFFF. Both return false when there is no bridge or no display.

Pokémon Z shows its Regi inscriptions as pictures of braille. Its profile sends the inscription of the running build
to the display and to the clipboard, and says whether it was copied (`games/pokemon_z/picture_cues.rb`).

## The mod's language

The mod's own text comes from one file per language in `lang/`, listed in the
[language files reference](../reference/lang-files.md). `I18n.t(key, vars)` (`core/foundation/i18n.rb`) looks a key
up in the active language and fills the text's `%{name}` placeholders from `vars`. English is the reference language
(`I18n::REFERENCE`). A key missing from the active language is said in English, and a key missing from English is
said as its own name.

The `language` setting holds a language code, or `:auto` by default ([Settings](../reference/settings.md)).
`I18n.lang` returns the code chosen. For `:auto` it returns the first language with a file among these:

1. The system's language (`SystemLang.code`): mkxp-z's `System.user_language`, else the Windows interface language,
   else the POSIX locale variables.
2. Its shipped neighbour, for a system language the mod does not ship: Catalan, Basque, Galician and Asturian give
   Spanish (`SystemLang::NEIGHBOURS`).
3. The language of the running game build (`GameLang.code`, under
   [Game text in several builds](#game-text-in-several-builds)).
4. English, or Spanish where English has no file.

The system's language is asked once per session. The game's language is read live, and the automatic verdict is kept
per value of `$PokemonSystem.language`, so switching the game's language moves the automatic choice with it.
Restoring the default settings keeps the language the player chose (`Config.restore_defaults`). The diagnostic
dump's `config:` line shows the setting, the language it resolved to, the game's language and the system's.

`I18n.available_languages` lists every `.txt` file in the language folder, so a new language file appears in the
setting and in the automatic choice. A language whose plural rule differs from English's needs the
rule declared in `I18n::PLURAL_RULES`, and implemented in `I18n.plural_form` when no shipped language shares it. The
automatic choice recognises a Windows interface language only through `SystemLang::LANGIDS`.

### Plural forms

A key whose words change with a number is written once per plural form, such as `rec_stopped.one` and
`rec_stopped.other`, and the code passes the number as `:n`. `I18n.plural_form` picks the form by the language's
CLDR rule. Each language decides alone whether a key needs forms. Polish writes `rec_stopped` as a label followed by
the number, which reads the same for any count, while English writes a singular and a plural:

```
# lang/en.txt
rec_stopped.one=Recording stopped, %{n} event saved.
rec_stopped.other=Recording stopped, %{n} events saved.
# lang/pl.txt
rec_stopped=Nagrywanie zatrzymane, zapisane zdarzenia: %{n}.
```

The forms and rules of each language are in the [language files reference](../reference/lang-files.md#plural-forms).

## Game text in several builds

The mod speaks in two languages that need not match. Its own text is in the mod's language, and the game's text is in
the language of the build that runs. Some fangames ship a separate build for each language. Pokémon Z ships Spanish,
English and French builds (`games/pokemon_z/picture_cues.rb`).

A reader therefore takes the game's words from the game and never writes them into `lang/`. It reads the
[painted text](../reference/glossary.md), a window's text, the names in the game's data, or the result of the game's
own `_INTL` translation call, which answers in the build's language (`games/realidea/pause_overlay.rb`). A word
copied from one build into `lang/` would be wrong in the others. `lang/` holds only what the mod adds, such as
positions, states, hints and its own menus.

`GameLang.code` (`core/foundation/game_lang.rb`) gives the running build's language. It reads the game's `LANGUAGES`
table (`Settings::LANGUAGES` in later Essentials versions) at the index `$PokemonSystem.language`, and maps the
language's name to a code through `GameLang::NAMES`. An entry counts only when its message file ships in the game's
`Data` folder, because forks keep template rows that name files they never ship. A build that declares no language,
or whose entry has no message file, gives nil.

A screen that shows its text only in a picture leaves nothing to read. Its profile transcribes the picture from each
build, keyed by build language, and the mod says the transcription of the running build, whatever the mod's language.
`picture_texts_multibuild` declares such pictures (`core/foundation/game.rb`), and `GameLang.pick` chooses the entry
for any other text. A build without its own transcription takes the one in the pictures' own language: Z's English
build paints its alchemy pages in Spanish, so those pages have no English entry.

```ruby
# games/pokemon_z/picture_cues.rb
picture_texts_multibuild(:es,
  "helpbg" => {
    :es => "Controles. Flechas: Movimiento. X: Interactuar / Menú. C: Interactuar / Correr. Z: Atrás. Q: Turbo.",
    :en => "Controls. Arrows: Movement. X: Interact / Menu. C: Interact / Run. Z: Back. Alt: Turbo."
  })
```

In the suite, `SpeechHelpers#with_intl` makes the game's `_INTL` answer from a table, as a translated build does
(`test/support/speak_capture.rb`).
