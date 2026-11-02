# Pokemon Edas, on Essentials BES (v16.2, gen-6): the profile's name and its game-wide settings.
PokeAccess::Game.define("edas") do
  # Its Input (0174_PSystem_Controls[OR]) keeps RPG Maker XP's letters, as in the summary's "Pulsa C o Espacio".
  key_hints PokeAccess::KeyHints::RGSS_LETTERS
  # On the map L toggles the dark gem's Eye of Truth and E flies with the green gem (0058_Scene_Map); F opens the message
  # log (0219_Textlog). All three go through Input's own keys, which no key of the mod shares.
  button_labels :l => :edas_btn_l
  remap_extra(:gem_flight, 0x45, :edas_key_e, :button => :E)
  remap_extra(:text_log, 0x46, :rem_ext_key_f, :button => :F)
end
