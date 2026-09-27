# Reborn's own screen reader: Messages.rb builds $tts over libTolk or nvdaControllerClient, both shipped, so it talks
# for every Windows player through some 380 tts() calls. The engine's relay (rv_common's OwnVoiceRV) keeps it muted
# while the mod speaks and says what it hands tts on the Reborn screens the mod has no reader for: the nest page of a
# Pokedex entry (whose places the game says), the PULSE Dex and its battle pages, the keyboard and gamepad control lists
# and the online trade (the party under the selector and the offer). Said anywhere: the coordinates its Blindstep mode
# reads when D is held on the map, and what map events say only through tts: the crystals the Victory Road lasers light,
# and the intro's train ticket once it is filled in.
PokeAccess::OwnVoiceRV.install([["PokemonNestMapScene", :pbStartScene], ["Scene_PulseDex_Info", :main],
                                ["Scene_PulseDex_Battle", :pbStartScene], ["DefaultKeyboardControlsScene", :pbRender],
                                ["DefaultGamepadControlsScene", :pbRender], ["Scene_Trade", :main]],
                               [/\AX -?\d+, Y -?\d+, map \d+, /, /\A\d+ yellow crystals lit up, /,
                                /\A(?:Train|Seat|Destination|Adult): /])
PokeAccess::OwnVoiceRV.leave_nest_to_game

# The character pick of the intro, said by the game's rebornIntroTTS as the choice moves.
PokeAccess::Game.define("reborn") do
  kernel("rebornIntroTTS", :around) { |_args, nxt| PokeAccess::OwnVoiceRV.relayed { nxt.call } }
end
