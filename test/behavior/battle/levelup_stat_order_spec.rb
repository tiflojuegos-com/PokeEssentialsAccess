# pbLevelUp's old stats by era: the v16-17 games pass hp, atk, def, speed, spatk, spdef after the pokemon and
# battler, both Infinite Fusion (v18 hybrids) hp, atk, def, spatk, spdef, speed; same arity, so the era is passed in.
Suite.define("battle: level-up stats follow the argument order of the era, not a fixed guess") do
  mon = TestPoke.build(:totalhp => 100, :attack => 100, :defense => 100,
                       :spatk => 100, :spdef => 100, :speed => 100)
  old = [mon, nil, 100, 100, 100, 90, 80, 70]

  legacy = PokeAccess::Battle.levelup_from_args(old, false).to_s
  modern = PokeAccess::Battle.levelup_from_args(old, true).to_s

  truthy "both orders produce a line", legacy.length > 0 && modern.length > 0
  falsy "and they are NOT the same line, which is the whole point", legacy == modern
end

# Lowering the slot each era calls speed reads the same line in both; read with the other era's order, it does not.
Suite.define("battle: each era maps its own slot to the stat that grew") do
  mon = TestPoke.build(:totalhp => 100, :attack => 100, :defense => 100,
                       :spatk => 100, :spdef => 100, :speed => 100)
  base = [mon, nil, 100, 100, 100, 100, 100, 100]

  legacy_speed = base.dup; legacy_speed[5] = 90
  modern_speed = base.dup; modern_speed[7] = 90

  t  = PokeAccess::Battle.levelup_from_args(legacy_speed, false).to_s
  t2 = PokeAccess::Battle.levelup_from_args(modern_speed, true).to_s

  truthy "a stat that grew is actually spoken", t.length > 0
  eq "and the same growth reads identically once each era is read its own way", t, t2

  crossed =PokeAccess::Battle.levelup_from_args(modern_speed, false).to_s
  falsy "reading a v18 call with the v16-17 order does not say the same thing", crossed == t2
end
