# Per-option help in the Options screen. The reader binds to whatever method the fork fires on a
# selection change and stores the description for the info key -- it never speaks on its own.
#
# The regression this pins: the reader listed only pbChangeSelection and updateDescription, and NONE of the
# seven gen-6 games has either (their PokemonOptionScene exposes pbUpdate and writes the description inline
# from pbOptions). Being :optional, it bound to nothing and failed in silence, so the info key had no
# description to offer in the whole era. The stub deliberately mirrors the real scene: pbUpdate only.
Suite.define("options: the per-option description reaches the info key in the gen-6 scene shape") do
  scene = PokemonOptionScene.new
  scene.sprites["textbox"] = Object.new.tap do |o|
    def o.text; "Sube o baja el volumen de la musica."; end
  end

  PokeAccess::Info.set_info(:text, nil)
  SpeakCapture.clear
  scene.pbUpdate

  eq "the focused option's description is stored for the info key",
     PokeAccess::Info.info_text, "Sube o baja el volumen de la musica."
  eq "and storing it speaks nothing by itself", SpeakCapture.log.length, 0

  # An empty textbox must not wipe a description already stored: the scene blanks it between redraws.
  scene.sprites["textbox"] = Object.new.tap { |o| def o.text; "   "; end }
  scene.pbUpdate
  eq "a blank textbox leaves the last description in place",
     PokeAccess::Info.info_text, "Sube o baja el volumen de la musica."

  PokeAccess::Info.set_info(:text, nil)
end

# The regression the FIRST fix caused, found in play: with the help hooked on pbUpdate the descriptions
# arrived but the options themselves went mute. pbUpdate is the scene's per-frame loop and it DRIVES the
# reader that announces the focused option, so guarding it pins :pbUpdate on the reentrancy stack for the
# whole frame and that reader is dropped as nested_other?. Hooking a container without saying so silences
# everything it contains.
Suite.define("options: hooking the scene's per-frame loop does not silence the reader it drives") do
  # Hooks cannot be unregistered, so this stand-in for the game's own option reader has to be inert for
  # every scene but this suite's: without the marker it spoke inside any later suite that drove an option
  # scene, and the sibling suite above only passed because the glob happened to order them in its favour.
  PokeAccess::Hooks.after_hook("PokemonOptionScene", :refresh_option) do |s, _r, _a|
    next unless s.instance_variable_get(:@pa_spec_drives_reader)
    PokeAccess.speak("Volumen de la musica, 80", true)
  end

  scene = PokemonOptionScene.new
  scene.instance_variable_set(:@pa_spec_drives_reader, true)
  scene.sprites["textbox"] = Object.new.tap { |o| def o.text; "Sube o baja el volumen."; end }
  SpeakCapture.clear
  scene.pbUpdate

  spoke "the option the loop drives is still announced", /Volumen de la musica, 80/
  eq "and its description still reaches the info key",
     PokeAccess::Info.info_text, "Sube o baja el volumen."
  PokeAccess::Info.set_info(:text, nil)
end
