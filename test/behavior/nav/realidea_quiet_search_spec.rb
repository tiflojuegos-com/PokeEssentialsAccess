# Realidea's passability check plays a splash per puddle tile it is asked about: its sounds are held back while a
# route is searched. The profile is loaded here, once.
Suite.define("realidea: its passability sounds are kept quiet while a route is searched") do
  unless $realidea_quiet_loaded
    path = File.join(Harness::ROOT, "games", "realidea", "quiet_search.rb")
    eval(File.read(path), TOPLEVEL_BINDING, path)
    $realidea_quiet_loaded = true
  end
  $se_played = []
  PokeAccess::Pathfinder.with_level_kept { pbSEPlay("Awita") }
  eq "a sound asked for during a search is not played", $se_played, []
  pbSEPlay("Awita")
  eq "outside a search it is", $se_played, ["Awita"]
end
