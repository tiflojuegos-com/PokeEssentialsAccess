# Pokemon Z's damage numbers (games/pokemon_z/damage_numbers.rb): the number painted over a hit Pokemon is said,
# queued after the hp line, only where it is not the hp the bar changes by, and never while the game hides it.

# Z's battle scene as far as the reader goes. Other battle tests give that name to their own scenes, so this one bears
# it only while the profile file is evaluated once more over it.
class ZDamageScene
  def pbShowDamageNumber(_pkmn, _oldhp, _effectiveness, _doublebattle, _total_damage)
    :shown
  end
end

class ZDamageNumbersTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "pokemon_z", "damage_numbers.rb")

  # Z's options as far as the reader goes: Mostrar daño, 0 while the numbers are shown.
  Options = Struct.new(:numeritos)

  # A battler as far as the reader goes.
  Battler = Struct.new(:hp)

  # A battler as the core's hp change reads it, with the battle it fights in.
  Foe = Struct.new(:name, :hp, :totalhp, :index, :battle)

  # A battle as far as its scene.
  Fight = Struct.new(:scene)

  # The profile's hook binds by class name, so its file is evaluated once more with the stand-in bearing that name.
  unless Object.const_defined?(:PokeBattle_Scene)
    Object.const_set(:PokeBattle_Scene, ZDamageScene)
    begin
      eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
    ensure
      Object.send(:remove_const, :PokeBattle_Scene)
    end
  end

  test "says the whole damage, queued, where the hit takes less than it from the bar" do
    { "a knockout with damage to spare" => [0, 12, 58],
      "Sturdy or a Focus Sash leaving 1 hp" => [1, 40, 90] }.each do |what, (hp, oldhp, total)|
      SpeakCapture.clear
      show(Battler.new(hp), oldhp, total)
      assert_equal [[number(total), false]], SpeakCapture.log, what
    end
  end

  test "says nothing where the number painted is the hp the bar changes by, which the hp line says" do
    { "a hit the hp covered" => [20, 32, 12],
      "a heal, which passes no damage" => [40, 20, 0],
      "a loss that passes no damage" => [28, 32, 0] }.each do |what, (hp, oldhp, total)|
      SpeakCapture.clear
      show(Battler.new(hp), oldhp, total)
      assert_nothing_spoken what
    end
  end

  test "says nothing while the game's Mostrar daño option hides the numbers" do
    show(Battler.new(0), 12, 58, Options.new(1))
    assert_nothing_spoken
  end

  test "says the number where the game's options do not hold the setting" do
    { "no options" => nil, "options without the setting" => Object.new,
      "the setting unset" => Options.new(nil) }.each do |what, options|
      SpeakCapture.clear
      show(Battler.new(0), 12, 58, options)
      assert_equal [number(58)], SpeakCapture.lines, what
    end
  end

  test "says any damage passed for a battler whose hp cannot be read" do
    { 58 => [number(58)], 1 => [number(1)], 0 => [] }.each do |total, said|
      SpeakCapture.clear
      show(Object.new, 12, total)
      assert_equal said, SpeakCapture.lines, "damage #{total}"
    end
  end

  test "leaves the scene its own answer" do
    assert_equal :shown, show(Battler.new(0), 12, 58)
  end

  test "a foe's hp change keeps its figure while Z's scene paints the numbers over it" do
    with_options(Options.new(0)) { PokeAccess::Battle.announce_hp_change(pidgey(ZDamageScene.new), 26) }
    said = PokeAccess::I18n.t(:bt_hp_change, :name => "Pidgey", :verb => PokeAccess::I18n.t(:bt_lose), :n => 7,
                              :rest => PokeAccess::I18n.t(:bt_hp_pct, :n => 40))
    assert_equal [said], SpeakCapture.lines
  end

  test "a foe's hp change is the share of its bar while the numbers are hidden, or on a scene without them" do
    cases = { "Mostrar daño off" => [Options.new(1), ZDamageScene.new], "no numbers" => [Options.new(0), Object.new] }
    cases.each do |what, (options, scene)|
      SpeakCapture.clear
      with_options(options) { PokeAccess::Battle.announce_hp_change(pidgey(scene), 26) }
      said = PokeAccess::I18n.t(:bt_hp_change_pct, :name => "Pidgey", :verb => PokeAccess::I18n.t(:bt_lose), :n => 15,
                                :rest => PokeAccess::I18n.t(:bt_hp_pct, :n => 40))
      assert_equal [said], SpeakCapture.lines, what
    end
  end

  test "a battle scene without damage numbers is not counted as a missing hook by the self-check" do
    missing = PokeAccess::Hooks.missing
    was = missing.dup
    missing.clear
    declare_hooks_over(Class.new)
    assert_equal [], missing
  ensure
    missing.replace(was) if was
  end

  private

  # The line said for a damage number.
  def number(n)
    PokeAccess::I18n.t(:zdmg_number, :n => n)
  end

  # Shows Z's damage number for a hit on pkmn from oldhp passing total damage (0 for none), with the game's options
  # set to options for the call (the numbers shown by default); answers the scene's own value.
  def show(pkmn, oldhp, total, options = Options.new(0))
    with_options(options) { ZDamageScene.new.pbShowDamageNumber(pkmn, oldhp, 0, false, total) }
  end

  # Runs the block with the game's options set to options, put back after; answers the block's value.
  def with_options(options)
    was = $PokemonSystem
    $PokemonSystem = options
    yield
  ensure
    $PokemonSystem = was
  end

  # A foe Pidgey at 19 of 47 hp, fighting in a battle whose scene is scene.
  def pidgey(scene)
    Foe.new("Pidgey", 19, 47, 1, Fight.new(scene))
  end

  # Evaluates the profile's hook declarations alone, with scene bearing the name of Z's battle scene meanwhile, under a
  # name of their own so that the profile file's coverage stays that of its whole evaluation.
  def declare_hooks_over(scene)
    hooks = Harness.source(PATH)[/^PokeAccess::Game\.define.*\z/m]
    had = Object.const_defined?(:PokeBattle_Scene) ? Object.send(:remove_const, :PokeBattle_Scene) : nil
    Object.const_set(:PokeBattle_Scene, scene)
    begin
      eval(hooks, TOPLEVEL_BINDING, "pokemon_z damage number hooks")
    ensure
      Object.send(:remove_const, :PokeBattle_Scene)
      Object.const_set(:PokeBattle_Scene, had) if had
    end
  end
end
