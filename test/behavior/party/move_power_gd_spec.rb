# A move's power off its GameData under each era's name: display_damage (Soulstones 2, the figure its page paints)
# over base_damage (v19), display_power (v20+) over plain power.
Suite.define("summary: a move's power is found under each era's name for it") do
  sg = PokeAccess::SummaryGameData
  v19 = Object.new
  def v19.base_damage; 90; end
  eq "v19 keeps it as base_damage", sg.move_power(v19, nil, nil), 90
  ss2 = Object.new
  def ss2.display_damage(_pk, _mv); 120; end
  def ss2.base_damage; 90; end
  eq "Soulstones 2's display_damage is the figure its page paints", sg.move_power(ss2, nil, nil), 120
  modern = Object.new
  def modern.display_power(_pk, _mv); 70; end
  def modern.power; 60; end
  eq "v20+ says display_power first", sg.move_power(modern, nil, nil), 70
  plain = Object.new
  def plain.power; 40; end
  eq "and plain power where nothing else answers", sg.move_power(plain, nil, nil), 40
end
