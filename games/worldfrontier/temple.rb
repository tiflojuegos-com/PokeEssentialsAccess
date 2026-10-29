# World Frontier's Battle Temple (Templo Batalla): its dark floors paint a counter of the room's items in a corner
# (BattleTemple::RoomItemLabel), repainted only when it changes, as each item is found; said then, queued.
PokeAccess::Game.define("worldfrontier") do
  before("BattleTemple::RoomItemLabel", :paint) { |_label, args| PokeAccess.speak_clean(args[0].to_s, false) }
end
