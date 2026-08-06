# The old-stat argument order of pbLevelUp. Two orders share one scene class: the seven v16-17 games pass
# hp, atk, def, SPEED, spatk, spdef, while both Infinite Fusion -- v18 hybrids that kept PokeBattle_Scene
# while moving to GameData internals -- pass hp, atk, def, spatk, spdef, SPEED. Eight arguments, same types,
# same arity: nothing in the call separates them, so the binding asks the era once and passes the answer in.
#
# This failure mode earns a test of its own because it is not silence. Read the wrong way round, the
# level-up panel announces three real numbers under three wrong stat names -- a player is told their speed
# rose when it was their special attack. Believable, and impossible to catch by ear.
#
# levelup_text names a stat only when the Pokemon's CURRENT value differs from the old one it was handed,
# so the mon below is built with known stats and each run lowers exactly one old value. Which stat gets
# named is then decided purely by the mapping under test.
Suite.define("battle: level-up stats follow the argument order of the era, not a fixed guess") do
  mon = TestPoke.build(:totalhp => 100, :attack => 100, :defense => 100,
                       :spatk => 100, :spdef => 100, :speed => 100)
  # [pokemon, battler, hp, atk, def, X, Y, Z] -- the last three are what the two eras disagree about.
  old = [mon, nil, 100, 100, 100, 90, 80, 70]

  legacy = PokeAccess::Battle.levelup_from_args(old, false).to_s
  modern = PokeAccess::Battle.levelup_from_args(old, true).to_s

  truthy "both orders produce a line", legacy.length > 0 && modern.length > 0
  falsy "and they are NOT the same line, which is the whole point", legacy == modern
end

# Read the other way round: give each era the slot IT calls speed and the sentence must come out identical.
# That equality is exactly what a wrong mapping breaks, and it pins the meaning rather than just asserting
# the two differ.
Suite.define("battle: each era maps its own slot to the stat that grew") do
  mon = TestPoke.build(:totalhp => 100, :attack => 100, :defense => 100,
                       :spatk => 100, :spdef => 100, :speed => 100)
  base = [mon, nil, 100, 100, 100, 100, 100, 100]

  legacy_speed = base.dup; legacy_speed[5] = 90   # v16-17 keeps speed at slot 5
  modern_speed = base.dup; modern_speed[7] = 90   # the v18 hybrids moved it to slot 7

  t  = PokeAccess::Battle.levelup_from_args(legacy_speed, false).to_s
  t2 = PokeAccess::Battle.levelup_from_args(modern_speed, true).to_s

  truthy "a stat that grew is actually spoken", t.length > 0
  eq "and the same growth reads identically once each era is read its own way", t, t2

  # The cross check: reading a v18 call with the older mapping moves the growth onto a different stat.
  crossed = PokeAccess::Battle.levelup_from_args(modern_speed, false).to_s
  falsy "reading a v18 call with the v16-17 order does not say the same thing", crossed == t2
end
