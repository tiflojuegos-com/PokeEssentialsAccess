# Reborn's own screen reader ($tts over the shipped libTolk or nvdaControllerClient) talks for every Windows player:
# the relay (rv_common's OwnVoiceRV) mutes it while the mod speaks and says what it hands tts on the screens below,
# and anywhere the Blindstep coordinates and the lines map events say only through tts (the lit crystals, the ticket).
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
