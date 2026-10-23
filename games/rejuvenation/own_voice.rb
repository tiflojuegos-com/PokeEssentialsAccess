# Rejuvenation's own screen reader (TextToSpeech.rb's global tts) talks only where libTolk or the NVDA client is copied
# in; the relay (rv_common's OwnVoiceRV) mutes it while the mod speaks and says what it hands tts on the screens below.
PokeAccess::OwnVoiceRV.install([["DefaultControlsScene", :pbRender], ["Scene_RiftDex_Info", :main],
                                ["Scene_BossDex_Battle", :pbStartScene], ["TextLogScene", :initialize],
                                ["AdvancedPokedex", :pbStartScreen], ["DefaultBallDisplay", :pbToggle],
                                ["DefaultBallDisplay", :pbChange, :moved], ["Scene_FieldNotes", :sortMenu]])
