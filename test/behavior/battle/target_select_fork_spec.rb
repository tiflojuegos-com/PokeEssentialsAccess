# Target selection in doubles, across forks. Stock gen-6 highlights through pbUpdateSelected(index) and the
# reader hangs off that. Both Infinite Fusion games dropped it: their pbChooseTarget calls
# pbSelectBattler(index, 2) instead -- and pbSelectBattler is ALSO what the command phase calls, with the
# default mode, when a battler's turn begins. Reading that second case would announce the player's own
# Pokemon every turn, so the mode argument is what tells them apart.
#
# announce_target itself is engine-agnostic and already covered elsewhere; what is asserted here is the
# discrimination the fork path depends on.

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

# The gate used to be COPIED into this spec and the copy is what got asserted -- so changing the real one
# (battle_g6.rb, inside a hook body on PokeBattle_Scene, a class the stubs do not have) broke nothing here.
# This drives the real thing instead: give the fork its class, replay the registration, and call the method.
Suite.define("battle: pbSelectBattler only reads a target when the mode says it is choosing one") do
  # No pbUpdateSelected on purpose: its absence is exactly what makes battle_g6 take the fork branch.
  scene_cls = Class.new do
    def pbSelectBattler(_index, _mode = 0); :selected; end
  end
  begin
    Object.const_set(:PokeBattle_Scene, scene_cls) unless Object.const_defined?(:PokeBattle_Scene)
    verbose = $VERBOSE
    begin
      # eval is the harness's own loader (test/support/harness.rb), over this repo's own file by absolute
      # path. A hook binds once at load, so a class created afterwards needs the registration replayed.
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
    silent "the all-targets mode, which passes the text array instead of an index, is skipped"
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

# The doubles gate had no coverage at all: every fixture here answered doublebattle true, so removing the
# guard changed nothing. In a single battle there is no target to choose and the cursor must stay silent.
Suite.define("battle: a single battle has no target cursor to read") do
  scene = target_scene(["Bulbasaur", "Charmander"])
  battle = scene.instance_variable_get(:@battle)
  def battle.doublebattle; false; end
  PokeAccess::Battle.announce_target(scene, -1)
  SpeakCapture.clear
  PokeAccess::Battle.announce_target(scene, 1)
  silent "nothing is announced when the battle is not a double"
end
