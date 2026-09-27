# Target selection in doubles by fork: stock gen-6 reads pbUpdateSelected(index); both Infinite Fusion call
# pbSelectBattler(index, 2), which with the default mode starts a turn instead, so the mode tells them apart.

# The subset of a scene announce_target reads: @battle, with doubles on and two named battlers.
def target_scene(names)
  battlers = names.map do |n|
    b = Object.new
    b.instance_variable_set(:@n, n)
    def b.name; @n; end
    def b.pokemon; true; end
    b
  end
  battle = Object.new
  battle.instance_variable_set(:@b, battlers)
  def battle.doublebattle; true; end
  def battle.battlers; @b; end
  scene = Object.new
  scene.instance_variable_set(:@battle, battle)
  scene
end

# The fork gate, driven for real over a PokeBattle_Scene with only pbSelectBattler (this repo's battle_g6 evaluated
# again over it); area mode passes the array of target texts instead of an index.
Suite.define("battle: pbSelectBattler only reads a target when the mode says it is choosing one") do
  scene_cls = Class.new do
    def pbSelectBattler(_index, _mode = 0); :selected; end
  end
  begin
    Object.const_set(:PokeBattle_Scene, scene_cls) unless Object.const_defined?(:PokeBattle_Scene)
    verbose = $VERBOSE
    begin
      $VERBOSE = nil
      path = File.join(Harness::ROOT, "core", "battle", "gen6", "battle_g6.rb")
      eval(File.read(path), TOPLEVEL_BINDING, path)
    ensure
      $VERBOSE = verbose
    end

    scene = target_scene(["Bulbasaur", "Charmander"])
    battle = scene.instance_variable_get(:@battle)
    hooked = PokeBattle_Scene.new
    hooked.instance_variable_set(:@battle, battle)

    eq "the hook leaves the plugin's return value alone", hooked.pbSelectBattler(1, 2), :selected
    SpeakCapture.clear
    hooked.pbSelectBattler(-1)
    hooked.pbSelectBattler(1, 2)
    spoke "moving the target cursor (mode 2) reads", /Charmander/

    SpeakCapture.clear
    hooked.pbSelectBattler(-1)
    hooked.pbSelectBattler(0)
    silent "a battler's turn starting (default mode) does not"

    SpeakCapture.clear
    hooked.pbSelectBattler(-1)
    hooked.pbSelectBattler(0, 2)
    spoke "deselecting on the way out lets re-entering read again", /Bulbasaur/

    SpeakCapture.clear
    hooked.pbSelectBattler(-1)
    hooked.pbSelectBattler(["a", "b"], 2)
    spoke "el modo de area nombra los dos objetivos encendidos", /Bulbasaur/
    spoke "y tambien el segundo", /Charmander/
  ensure
    Object.send(:remove_const, :PokeBattle_Scene) if Object.const_defined?(:PokeBattle_Scene)
    SpeakCapture.clear
  end
end

Suite.define("battle: the target under the cursor is announced once per change") do
  scene = target_scene(["Bulbasaur", "Charmander"])
  PokeAccess::Battle.announce_target(scene, -1)
  SpeakCapture.clear

  PokeAccess::Battle.announce_target(scene, 1)
  spoke_once "the focused battler is named", /Charmander/

  SpeakCapture.clear
  PokeAccess::Battle.announce_target(scene, 1)
  silent "holding on the same target does not repeat it"

  SpeakCapture.clear
  PokeAccess::Battle.announce_target(scene, 0)
  spoke "moving to the other target names it", /Bulbasaur/
end

# A single battle has no target to choose, so the cursor stays silent.
Suite.define("battle: a single battle has no target cursor to read") do
  scene = target_scene(["Bulbasaur", "Charmander"])
  battle = scene.instance_variable_get(:@battle)
  def battle.doublebattle; false; end
  PokeAccess::Battle.announce_target(scene, -1)
  SpeakCapture.clear
  PokeAccess::Battle.announce_target(scene, 1)
  silent "nothing is announced when the battle is not a double"
end
