# Rejuvenation's own screen reader (TextToSpeech.rb: Tolk, NVDA, Orca and macOS classes behind a global tts with a
# lowercase: keyword) sleeps for most players, since the game ships neither libTolk nor the NVDA client, and wakes
# wherever one is copied in. The engine's relay (rv_common's OwnVoiceRV) keeps it muted while the mod speaks and says
# what it hands tts on the Rejuvenation screens the mod has no reader for: the controls list, the Rift Dex and its
# battle pages, the text and battle logs and the Advanced Dex.
PokeAccess::OwnVoiceRV.install([["DefaultControlsScene", :pbRender], ["Scene_RiftDex_Info", :main],
                                ["Scene_BossDex_Battle", :pbStartScene], ["TextLogScene", :initialize],
                                ["AdvancedPokedex", :pbStartScreen]])
