# games/insurgence/hm7.rb: the H-Mode7 switch reads false whatever the game stores, through a plain method (a hook
# would hand back the game's value inside another hooked method), and the other H-Mode7 settings keep theirs.
class Game_System
  attr_accessor :hm7, :hm7_zoom
end
INSURGENCE_HM7 = File.join(Harness::ROOT, "games", "insurgence", "hm7.rb")
eval(File.read(INSURGENCE_HM7), TOPLEVEL_BINDING, INSURGENCE_HM7)

Suite.define("insurgence: the H-Mode7 switch always reads false, the rest of Game_System is left alone") do
  sys = Game_System.new
  sys.hm7 = true
  eq "hm7 reads false once the game turns it on", sys.hm7, false
  eq "the value the game stored is kept", sys.instance_variable_get(:@hm7), true
  sys.hm7_zoom = 80
  eq "the other H-Mode7 settings are untouched", sys.hm7_zoom, 80
  falsy "it is a plain method, outside the hook chains",
        Game_System.method_defined?(:hm7__pa_orig_Game_System) ||
        Game_System.private_method_defined?(:hm7__pa_orig_Game_System)
end
