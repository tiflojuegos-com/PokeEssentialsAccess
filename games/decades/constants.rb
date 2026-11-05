# Pokémon Decades' game-wide settings. Its field moves ask for what the stock ones do, with shorter messages. Waterfall only
# goes up from the party's menu, as at the fall the action button does nothing, and Headbutt only works with that button
# (0244_Overworld_FieldMoves.rb). Its battle scene reads T itself to open the Type Match-up chart on the battlers
# (pbFrameUpdate, 0187_Battle_Scene.rb); T is the mod's info key, so the game's ships on Alt + T. It reads Ctrl, the mod's
# modifier, for the DexNav's search of a registered species, a sure catch (pbCaptureCalc) and skipping a challenge battle as
# won (pbOrganizedBattleEx), so those ship on Tab, a key to hold as easily.
PokeAccess::Game.define("decades") do
  remap_extra(:decades_type_chart, :T, :decades_key_t)
  remap_extra(:decades_ctrl, 0x11, :decades_key_ctrl, :button => :CTRL)
  key_defaults(:decades_type_chart => "Alt+T", :decades_ctrl => "Tab")
end
