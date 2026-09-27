# The region map's per-place detail (the fourth PBS field, which the bar paints beside the place) is stored for the
# info key and said after the place only where descriptions are said (full); a point with none, "" as the real scenes
# answer, clears it.
module PaMapRig
  class Scene
    attr_accessor :details
    def initialize; @details = {}; end
    def pbGetMapLocation(x, y); (@details[[x, y]] ? "Ciudad #{x}#{y}" : ""); end
    def pbGetMapDetails(x, y); @details[[x, y]] || ""; end
  end

  # A scene with no details method at all.
  class Bare
    def pbGetMapLocation(x, y); "Pueblo"; end
  end
end

Suite.define("region map: the place detail reaches the info key, and is said after the place only in full") do
  scene = PaMapRig::Scene.new
  scene.details[[3, 4]] = "Laboratorio Flare"
  level = PokeAccess::Config.verbosity
  begin
    PokeAccess::Config.verbosity = :medium
    PokeAccess::Info.set_info(:text, nil)
    SpeakCapture.clear
    PokeAccess::RegionMap.announce(scene, scene.pbGetMapLocation(3, 4), 3, 4)

    spoke "the place name is announced, as before", /Ciudad 34/
    eq "the detail is stored for the info key", PokeAccess::Info.info_text, "Laboratorio Flare"
    falsy "and below full it is NOT spoken with the name",
          SpeakCapture.log.any? { |line, _i| line =~ /Laboratorio/ }

    PokeAccess::Config.verbosity = :full
    PokeAccess::RegionMap.forget(scene)
    SpeakCapture.clear
    PokeAccess::RegionMap.announce(scene, scene.pbGetMapLocation(3, 4), 3, 4)
    eq "in full it follows the place, as the bar paints it beside", SpeakCapture.lines, ["Ciudad 34, Laboratorio Flare"]

    PokeAccess::RegionMap.announce(scene, scene.pbGetMapLocation(9, 9), 9, 9)
    eq "moving to a point with no description clears the stored one",
       PokeAccess::Info.info_text, nil

    scene2 = PaMapRig::Scene.new
    scene2.details[[1, 1]] = "Chateau Merlot"
    PokeAccess::RegionMap.announce(scene2, scene2.pbGetMapLocation(1, 1), 1, 1)
    eq "a described point stores again", PokeAccess::Info.info_text, "Chateau Merlot"
    PokeAccess::RegionMap.forget(scene2)
    eq "and closing the map forgets it", PokeAccess::Info.info_text, nil

    SpeakCapture.clear
    PokeAccess::RegionMap.announce(PaMapRig::Bare.new, "Pueblo", 2, 2)
    spoke "a map with no details method still announces the name", /Pueblo/
    eq "and stores no description", PokeAccess::Info.info_text, nil
  ensure
    PokeAccess::Config.verbosity = level
    PokeAccess::Info.set_info(:text, nil)
  end
end
