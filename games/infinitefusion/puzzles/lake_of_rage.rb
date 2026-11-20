# Lake of Rage (maps 638 thawed and 645 frozen): the glowing stones beside the lake swap one lake for the other. The four
# events around the stone of the frozen lake (9 to 12 of 645) thaw it; the four of the thawed one (6, 8, 10 and 16 of
# 638) freeze it, and while it is frozen the south exit is sealed.
PokeAccess::Game.define("infinitefusion") do
  mechanic(:state, 645) do
    auto
    name [9, 10, 11, 12], :ifp_lake_thaw_stone, :grouped => true
    arrival_hint :ifp_lake_frozen_rule
    hint :ifp_lake_frozen_hint
    active { true }
  end

  mechanic(:state, 638) do
    auto
    name [6, 8, 10, 16], :ifp_lake_freeze_stone, :grouped => true
  end
end
