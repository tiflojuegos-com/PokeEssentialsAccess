# Realidea's passability check plays a splash for each puddle tile it is asked about, so no sound effect plays
# while the route finder searches.
PokeAccess::Hooks.wrap_kernel("pbSEPlay", "realidea_quiet_search", :around) do |_args, nxt|
  PokeAccess::Pathfinder.searching? ? nil : nxt.call
end
