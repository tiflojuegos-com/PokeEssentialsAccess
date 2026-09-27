# Soulstones' quick save (games/soulstones1/quicksave.rb): Q on the map saves with pbSave and starts a disk animation
# with no message; the save's result is said as the animation starts. The profile's module alone is loaded: its hooks
# belong to the Soulstones process.
unless defined?(PokeAccess::Soulstones1QuickSave)
  path = File.join(Harness::ROOT, "games", "soulstones1", "quicksave.rb")
  eval(File.read(path)[/^module PokeAccess\r?\n.*?^end\r?\n/m], TOPLEVEL_BINDING, path)
end

Suite.define("soulstones1 quick save: the save Q makes is said as its animation starts, and a failed one too") do
  qs = PokeAccess::Soulstones1QuickSave
  t = PokeAccess::I18n
  scene = World.stub_scene(:@mode => nil)
  SpeakCapture.clear
  qs.arm(scene)
  qs.check(scene)
  silent "a map update that saves nothing says nothing"

  qs.arm(scene)
  qs.saved(true)
  scene.instance_variable_set(:@mode, 0)
  qs.check(scene)
  eq "the update that saved and started the animation says so, interrupting", SpeakCapture.log,
     [[t.t(:ss1_quicksaved), true]]

  SpeakCapture.clear
  qs.arm(scene)
  scene.instance_variable_set(:@mode, 1)
  qs.check(scene)
  silent "the animation's later frames say nothing again"

  scene.instance_variable_set(:@mode, nil)
  qs.arm(scene)
  qs.saved(false)
  scene.instance_variable_set(:@mode, 0)
  qs.check(scene)
  eq "a save pbSave says failed is said as failed", SpeakCapture.last, t.t(:ss1_quicksave_failed)

  SpeakCapture.clear
  scene.instance_variable_set(:@mode, nil)
  qs.arm(scene)
  qs.saved(true)
  qs.check(scene)
  silent "a save from the pause menu, run inside the update with no animation, is not the quick save"
end
