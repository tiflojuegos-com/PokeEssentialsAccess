# World Frontier sells everything for Battle Points: no event opens a shop that takes money or hands out a badge, and its
# pause menu paints the points where the money would go (Pause Menu UI), so the trainer line says them as painted instead.
PokeAccess::Game.define("worldfrontier") do
  trainer_part(:pb) do |tr|
    n = (tr.battle_points rescue nil)
    n.nil? ? nil : _INTL("{1} PB", n)
  end
  trainer_order [:name, :pb, :pokedex, :playtime]
end
