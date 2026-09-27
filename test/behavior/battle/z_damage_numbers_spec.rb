# Pokemon Z's damage numbers (games/pokemon_z/damage_numbers.rb) through PokeBattle_Scene#pbShowDamageNumber.

# Z's battle scene as far as the reader goes. Other battle specs give that name to their own scenes inside their
# suites, so this one bears it only while the profile file is evaluated once more over it.
class ZDamageScene
  def pbShowDamageNumber(_pkmn, _oldhp, _effectiveness, _doublebattle, _total_damage)
    :shown
  end
end

unless Object.const_defined?(:PokeBattle_Scene)
  Object.const_set(:PokeBattle_Scene, ZDamageScene)
  begin
    load File.join(Harness::ROOT, "games", "pokemon_z", "damage_numbers.rb")
  ensure
    Object.send(:remove_const, :PokeBattle_Scene)
  end
end

# The number painted over a hit Pokemon is the move's whole damage, so it is said, queued after the hp line, where it
# is not the hp the bar loses (a knockout with damage to spare, Sturdy, Focus Sash); a heal paints the hp gained,
# already said, and the game's option can hide the numbers.
Suite.define("z damage numbers: the painted number is said where it is not the hp the bar loses") do
  t = PokeAccess::I18n
  scene = ZDamageScene.new
  old = $PokemonSystem
  begin
    $PokemonSystem = Struct.new(:numeritos).new(0)
    fainted = Struct.new(:hp).new(0)
    SpeakCapture.clear
    eq "the scene's own value is kept", scene.pbShowDamageNumber(fainted, 12, 0, false, 58), :shown
    eq "a knockout with damage to spare: the whole damage, queued after the hp line", SpeakCapture.log,
       [[t.t(:zdmg_number, :n => 58), false]]

    SpeakCapture.clear
    scene.pbShowDamageNumber(Struct.new(:hp).new(1), 40, 0, false, 90)
    eq "Sturdy leaving 1 hp: the damage it held off too", SpeakCapture.lines, [t.t(:zdmg_number, :n => 90)]

    SpeakCapture.clear
    scene.pbShowDamageNumber(Struct.new(:hp).new(20), 32, 0, false, 12)
    silent "a hit the hp covered: the same number the hp line says"
    scene.pbShowDamageNumber(Struct.new(:hp).new(40), 20, 0, false, 0)
    silent "a heal passes no damage: the hp it gained, already said"

    $PokemonSystem = Struct.new(:numeritos).new(1)
    scene.pbShowDamageNumber(fainted, 12, 0, false, 58)
    silent "with Mostrar daño off, no number is painted, so none is said"
  ensure
    $PokemonSystem = old
  end
end
