# The modern battle's HP lines (gamedata pass): pbReduceHP and pbRecoverHP report each change; messages shown inside
# pbReduceHP are read, and a drop that ends with the bar refilled is not read as a loss.

def hp_hooks_scene
  scene = Battle::Scene.new
  scene.instance_variable_set(:@battle, Object.new)
  scene
end

Suite.define("battle hp: a plain hit says what was lost and what is left") do
  foe = Battle::Battler.new("Onix", 80, 100, 1)
  foe.pbReduceHP(30)
  eq "the loss is read once, against the bar it left", SpeakCapture.lines,
     [PokeAccess::BattleScene.hp_change_text(foe, 30, true)]
end

Suite.define("battle hp: messages shown while the HP drops are read") do
  scene = hp_hooks_scene
  boss = Battle::Battler.new("Jefe", 40, 100, 1)
  boss.on_reduce = lambda { |_b| scene.pbDisplayMessage("El escudo se resquebraja!") }
  boss.pbReduceHP(10)
  spoke "a message shown inside the HP drop reaches the player", /El escudo se resquebraja/
end

Suite.define("battle hp: a drop that ends with the bar refilled is not read as a loss") do
  boss = Battle::Battler.new("Jefe", 40, 100, 1)
  boss.on_reduce = lambda { |b| b.pbRecoverHP(b.totalhp) }
  boss.pbReduceHP(40)
  not_spoke "no loss is read against the refilled bar", /#{PokeAccess::I18n.t(:bt_lose)}/
  spoke "the refill itself is read", /#{PokeAccess::I18n.t(:bt_gain)}/
end
