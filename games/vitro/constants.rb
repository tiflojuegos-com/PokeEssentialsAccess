# Pokemon GS Vitro, on Essentials BES (v16.2, gen-6): the profile's name and its game-wide settings.
PokeAccess::Game.define("vitro") do
  # Its numbered buttons keep RPG Maker XP's letters (0197_PSystem_Controls): the bag's "[Z] Organizar Auto" and
  # "[A] Organizar" (0162_PScreen_Bag), the summary's "Presiona C" (0161_PScreen_Summary).
  key_hints PokeAccess::KeyHints::RGSS_LETTERS
  # A runs and sorts the bag by itself (0064_Scene_Map, 0351_Mixed runtoogle, 0162_PScreen_Bag); X picks a bag row up to move
  # it; L turns pages and, held, skips text (0059_Messages); R turns pages and opens the message log on the map (0350_Text Log).
  button_labels :a => :vitro_btn_a, :x => :vitro_btn_x, :l => :vitro_btn_l, :r => :vitro_btn_r
end
