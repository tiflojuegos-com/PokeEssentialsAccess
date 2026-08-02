# say_dialogue is the mod's anti-double-read for story text, and it had no assertions at all. Every message
# hook funnels through it, and several of them are LAYERED on the same line: a battle "paused message" fires
# its own before_hook AND the internal pbMessageDisplay the engine then calls, an event's pbMessage reaches
# both the Kernel singleton and (on modern engines) the bare Object function. Without the short suppression
# window the player hears every such line twice. The window must stay short, because re-talking to an NPC has
# to speak again; and a SUPPRESSED line must still be remembered, because the repeat key (shift+info) reads
# whatever was last shown -- if the swallowed copy skipped note_dialogue, the repeat key would replay a stale
# line. The dedup only works because clean() strips the \x01/\x02 pause bytes, so the paused twin of a line
# compares equal to the plain one (the double battle message that motivated the byte stripping).

# Runs the block with the dialogue memory blanked (the repeat-key line, the dedup text and its stamp) and
# restores whatever was there, so this file can neither inherit a remembered line nor leak one.
def with_clean_dialogue
  keys = [:@last_dialogue, :@last_say, :@last_say_t]
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

    # Point the repeat key somewhere else, then feed the SAME line again: it is swallowed, yet
    # note_dialogue runs before the dedup returns, so the repeat key must still end up on it. If the
    # suppression short-circuited first, the key would keep replaying the stale line below.
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

# End to end through the engine's own entry point: gen-6 defines Kernel.pbMessageDisplay as a singleton, and
# the toolkit aliases it at load. Driving THAT (rather than say_dialogue) proves the alias is in place and
# that the engine re-showing a line -- which is what actually happens when two layers hit the same message --
# does not double-read.
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
