# Obsidia Slums 2F (map 91): fourteen jump tiles like 1F's, the only way from the entrances to the stairs up to 3F
# (11,15), the Moon Stone (17,19) and two hidden items. 1F's reader (RebornJumpTiles) answers the hops and its rule is
# said on arriving.
PokeAccess::Game.define("reborn") do
  jumps = PokeAccess::RebornJumpTiles
  terrain_exit(:maps => 91, :tiles => lambda { |x, y| jumps.from?(x, y) }) { |x, y, dir| jumps.hop(x, y, dir[2]) }
  mechanic(:state, 91) do
    auto
    arrival_hint :rba_os_jump_rule
  end
end
