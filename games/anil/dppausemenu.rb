# The field menu in this build is the PauseMenuDP plugin (DP_PauseMenu), a Diamond/Pearl style icon menu
# read by the shared core reader (PokeAccess::DPMenu). Its trainer-card entry is labelled with the player's
# own name; naming it as well as speaking it is core's job now, so this profile is just the binding.
PokeAccess::Game.define("anil") do
  after("DP_PauseMenu", :update) { |menu, _r, _a| PokeAccess::DPMenu.read(menu) }
end
