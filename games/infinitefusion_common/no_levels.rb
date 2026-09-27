# Infinite Fusion's "no levels" mode (SWITCH_NO_LEVELS_MODE): the databox draws no level for anyone, so the HP
# and info keys leave it out too.
PokeAccess::Game.define("infinitefusion_common") do
  override("PokeAccess::Battle", :shown_level) do |_mod, original, _args|
    sw = (::SWITCH_NO_LEVELS_MODE rescue nil)
    sw && ($game_switches[sw] rescue false) ? nil : original.call
  end
end
