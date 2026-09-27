# say_dialogue, which every message hook funnels through: a repeat within half a second is swallowed but still feeds
# the repeat key, and a line's paused twin (\x01/\x02 bytes) compares equal to it.

# Runs the block with the dialogue memory (repeat-key line, dedup text, its led form and stamp, the pending head)
# blanked, then restores it.
def with_clean_dialogue
  keys = [:@last_dialogue, :@last_say, :@last_say_t, :@last_led, :@head]
  prev = keys.map { |k| PokeAccess.instance_variable_get(k) }
  keys.each { |k| PokeAccess.instance_variable_set(k, nil) }
  yield
ensure
  keys.each_index { |i| PokeAccess.instance_variable_set(keys[i], prev[i]) }
end

# Backdates the stamp of the last spoken line to secs ago, standing in for time passing without sleeping.
def dialogue_rewind(secs)
  PokeAccess.instance_variable_set(:@last_say_t, PokeAccess.clock - secs)
end

Suite.define("dialogue: the same line twice in a row is voiced once, a different line always speaks") do
  with_clean_dialogue do
    PokeAccess.say_dialogue("Hola entrenador")
    PokeAccess.say_dialogue("Hola entrenador")
    spoke_once "the doubled line reaches the synthesizer once", /Hola entrenador/
    eq "nothing else was said either", SpeakCapture.lines.length, 1
    eq "dialogue is QUEUED, so consecutive lines never cut each other off", SpeakCapture.log[0][1], false

    SpeakCapture.clear
    PokeAccess.say_dialogue("Te dare un Pokemon")
    spoke_once "a DIFFERENT line is always spoken", /Te dare un Pokemon/

    SpeakCapture.clear
    PokeAccess.say_dialogue("Hola entrenador")
    spoke_once "and the first line speaks again once it is no longer the last one", /Hola entrenador/
  end
end

Suite.define("dialogue: the suppression window is half a second, measured from the last read") do
  with_clean_dialogue do
    PokeAccess.say_dialogue("Bienvenido a Pueblo Paleta")
    SpeakCapture.clear

    dialogue_rewind(0.4)
    PokeAccess.say_dialogue("Bienvenido a Pueblo Paleta")
    silent "0.4 s after the read the repeat is still swallowed"

    dialogue_rewind(0.6)
    PokeAccess.say_dialogue("Bienvenido a Pueblo Paleta")
    spoke_once "0.6 s after it, a deliberate re-read speaks again", /Pueblo Paleta/

    SpeakCapture.clear
    PokeAccess.say_dialogue("Bienvenido a Pueblo Paleta")
    silent "and that re-read restarted the window (the next copy is swallowed)"
  end
end

Suite.define("dialogue: a swallowed line is still what the repeat key replays") do
  with_clean_dialogue do
    PokeAccess.say_dialogue("Toma esta Poke Ball")
    eq "the spoken line is remembered", PokeAccess.last_dialogue, "Toma esta Poke Ball"

    PokeAccess.instance_variable_set(:@last_dialogue, "una linea vieja")
    SpeakCapture.clear
    PokeAccess.say_dialogue("Toma esta Poke Ball")
    silent "the copy inside the window says nothing"
    eq "but the repeat key was still moved onto it", PokeAccess.last_dialogue, "Toma esta Poke Ball"

    PokeAccess.say_dialogue("")
    eq "an empty message never clobbers the remembered line", PokeAccess.last_dialogue, "Toma esta Poke Ball"
    PokeAccess.say_dialogue(nil)
    eq "nor does a nil one", PokeAccess.last_dialogue, "Toma esta Poke Ball"
  end
end

Suite.define("dialogue: the paused twin of a line compares equal, so a layered hook speaks it once") do
  with_clean_dialogue do
    PokeAccess.say_dialogue("\x01Pikachu uso Impactrueno\x02")
    PokeAccess.say_dialogue("Pikachu uso Impactrueno")
    spoke_once "the \\1-paused form and the plain form are one line, voiced once", /Pikachu uso Impactrueno/
    eq "and what was spoken is the clean form, with no control bytes",
       SpeakCapture.lines, ["Pikachu uso Impactrueno"]

    SpeakCapture.clear
    PokeAccess.say_dialogue("\x01Charmander uso Ascuas\x02")
    spoke_once "a genuinely different paused line is not swallowed by it", /Charmander uso Ascuas/
  end
end

# A head promised for the next line (who a speech bubble points at) leads that line once, in the same utterance, and
# stays with it for the repeat key even when another hook's copy of the line comes through.
Suite.define("dialogue: a promised head leads the next line once and stays with it for the repeat key") do
  with_clean_dialogue do
    PokeAccess.before_next_line("Niño, 2 izquierda")
    PokeAccess.say_dialogue("")
    PokeAccess.say_dialogue("¡Uno!")
    eq "an empty message is no line: the head leads the next one, queued", SpeakCapture.log,
       [["Niño, 2 izquierda: ¡Uno!", false]]
    eq "the repeat key keeps the line as it was said", PokeAccess.last_dialogue, "Niño, 2 izquierda: ¡Uno!"
    PokeAccess.say_dialogue("¡Uno!")
    eq "another hook's copy is swallowed and leaves the repeat key led", PokeAccess.last_dialogue,
       "Niño, 2 izquierda: ¡Uno!"

    SpeakCapture.clear
    PokeAccess.say_dialogue("¡Dos!")
    eq "the line after it goes without the head", SpeakCapture.lines, ["¡Dos!"]

    PokeAccess.before_next_line("Niña, 1 arriba")
    PokeAccess.before_next_line(nil)
    SpeakCapture.clear
    PokeAccess.say_dialogue("¡Tres!")
    eq "a head dropped before its line leads nothing", SpeakCapture.lines, ["¡Tres!"]
  end
end

# End to end through gen-6's Kernel.pbMessageDisplay singleton, which the toolkit aliases at load: a re-shown line is
# read once and feeds the repeat key.
Suite.define("dialogue: the gen-6 Kernel message path reads once and feeds the repeat key") do
  with_clean_dialogue do
    truthy "the Kernel message path really is hooked", Kernel.respond_to?(:pbMessageDisplay__access_orig)

    Kernel.pbMessageDisplay(nil, "Este cartel dice algo")
    spoke_once "showing a message speaks it", /Este cartel dice algo/
    eq "queued, like every dialogue line", SpeakCapture.log[0][1], false

    Kernel.pbMessageDisplay(nil, "Este cartel dice algo")
    spoke_once "the engine re-showing the same message does not read it twice", /Este cartel dice algo/
    eq "the repeat key holds the line the engine showed", PokeAccess.last_dialogue, "Este cartel dice algo"

    SpeakCapture.clear
    Kernel.pbMessageDisplay(nil, "Aqui vive el Profesor")
    spoke_once "the next message is read normally", /Aqui vive el Profesor/
    eq "and it becomes the line the repeat key replays", PokeAccess.last_dialogue, "Aqui vive el Profesor"
  end
end

# The counters behind the diag's "dialogue:" line: which entry point got wrapped and how many lines came through.
Suite.define("dialogue: the diag counters name the wrapped entry point and count the lines seen") do
  with_clean_dialogue do
    truthy "the gen-6 harness defines the Kernel singleton, and that is what got wrapped",
           PokeAccess.dialogue_wraps.include?(:singleton)
    before = PokeAccess.dialogue_seen
    PokeAccess.say_dialogue("Una linea")
    PokeAccess.say_dialogue("Una linea")
    eq "every hand-over counts, the swallowed twin included", PokeAccess.dialogue_seen, before + 2
    eq "the diag reports both forms the game defines and the wrap", PokeAccess::Keys.dialogue_forms.include?(:singleton), true
  end
end
