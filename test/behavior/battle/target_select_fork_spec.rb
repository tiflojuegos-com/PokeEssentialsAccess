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

# Mirrors the gate in the fork branch of the hook.
def choosing_target?(args)
  args[0].is_a?(Integer) && (args[1] == 2 || args[0] < 0)
end

Suite.define("battle: pbSelectBattler only reads a target when the mode says it is choosing one") do
  truthy "moving the target cursor (mode 2) reads", choosing_target?([1, 2])
  falsy  "a battler's turn starting (default mode) does not", choosing_target?([1])
  truthy "deselecting on the way out passes, so re-entering reads again", choosing_target?([-1])
  falsy  "the all-targets mode, which passes the text array, is skipped", choosing_target?([["a", "b"], 2])
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
