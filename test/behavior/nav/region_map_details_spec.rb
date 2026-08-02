# The region map's per-place description, offered on the info key.
#
# The map is the one screen where a blind player has no spatial reference at all, and several fangames put
# real information in the fourth PBS field of each point ("Pueblo Lienzo" -> "Laboratorio Flare"). It was
# never read. It is STORED rather than spoken: reading it on every cursor move would bury the names the
# player is scanning through.
#
# The scene stub answers exactly like the real ones do -- "" for a point with no description, which is the
# majority (routes, towers) -- because a reader that only works on the happy path would leave the info key
# answering with the previous town.
module PaMapRig
  class Scene
    attr_accessor :details
    def initialize; @details = {}; end
    def pbGetMapLocation(x, y); (@details[[x, y]] ? "Ciudad #{x}#{y}" : ""); end
    def pbGetMapDetails(x, y); @details[[x, y]] || ""; end
  end

  # A scene whose engine has no details method at all, to prove the reader degrades instead of raising.
  class Bare
    def pbGetMapLocation(x, y); "Pueblo"; end
  end
end

Suite.define("region map: the place description reaches the info key without being spoken") do
  scene = PaMapRig::Scene.new
  scene.details[[3, 4]] = "Laboratorio Flare"
  begin
    PokeAccess::Info.set_info(:text, nil)
    SpeakCapture.clear
    PokeAccess::RegionMap.announce(scene, scene.pbGetMapLocation(3, 4), 3, 4)

    spoke "the place name is announced, as before", /Ciudad 34/
    eq "the description is stored for the info key", PokeAccess::Info.info_text, "Laboratorio Flare"
    falsy "and it is NOT spoken with the name",
          SpeakCapture.log.any? { |line, _i| line =~ /Laboratorio/ }

    # Most points have none. The previous town's description must not answer for this one.
    PokeAccess::RegionMap.announce(scene, scene.pbGetMapLocation(9, 9), 9, 9)
    eq "moving to a point with no description clears the stored one",
       PokeAccess::Info.info_text, nil

    # Closing the map must not leave the last town answering the info key on the field.
    scene2 = PaMapRig::Scene.new
    scene2.details[[1, 1]] = "Chateau Merlot"
    PokeAccess::RegionMap.announce(scene2, scene2.pbGetMapLocation(1, 1), 1, 1)
    eq "a described point stores again", PokeAccess::Info.info_text, "Chateau Merlot"
    PokeAccess::RegionMap.forget(scene2)
    eq "and closing the map forgets it", PokeAccess::Info.info_text, nil

    # An engine without the details method at all: the name must still be announced.
    SpeakCapture.clear
    PokeAccess::RegionMap.announce(PaMapRig::Bare.new, "Pueblo", 2, 2)
    spoke "a map with no details method still announces the name", /Pueblo/
    eq "and stores no description", PokeAccess::Info.info_text, nil
  ensure
    PokeAccess::Info.set_info(:text, nil)
  end
end
