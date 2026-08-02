# v22 town map: the ONE v22 screen that had no coverage, because its reading used to live inside the hook
# body and a hook body cannot be reached from a spec (hooks bind at load, so a class defined later is never
# wired). With the reading in TownMapV22 it is testable, and what it pins is the behaviour a blind player
# depends on while sweeping the map with a held direction: the town is named when the cursor reaches it,
# NOT repeated frame after frame, and blank points between towns stay silent without eating the next name.
Suite.define("town map v22: names the focused location once, stays quiet on blanks") do
  vis = Object.new
  def vis.point; @point; end
  def vis.point=(p); @point = p; end
  # The screen's own accessor: a point with a name, or one without (the sea, a blank tile).
  def vis.get_point_data
    @point.nil? ? nil : { :real_name => @point }
  end

  vis.point = "Pueblo Paleta"
  SpeakCapture.clear
  PokeAccess::TownMapV22.announce(vis)
  spoke_once "the focused town is named on arrival", /Pueblo Paleta/

  SpeakCapture.clear
  PokeAccess::TownMapV22.announce(vis)
  silent "holding the direction on the same town does not repeat it"

  vis.point = nil
  SpeakCapture.clear
  PokeAccess::TownMapV22.announce(vis)
  silent "a blank point says nothing"
  falsy "and resolves to no name at all", PokeAccess::TownMapV22.name_at(vis)

  vis.point = "Ciudad Verde"
  SpeakCapture.clear
  PokeAccess::TownMapV22.announce(vis)
  spoke_once "the next town after the blank IS named", /Ciudad Verde/

  # The blank must not have consumed the dedup slot in a way that loses a RETURN to the first town.
  vis.point = nil
  PokeAccess::TownMapV22.announce(vis)
  vis.point = "Pueblo Paleta"
  SpeakCapture.clear
  PokeAccess::TownMapV22.announce(vis)
  spoke_once "coming back to the first town names it again", /Pueblo Paleta/

  other = Object.new
  def other.get_point_data; { :real_name => "Pueblo Paleta" }; end
  SpeakCapture.clear
  PokeAccess::TownMapV22.announce(other)
  spoke_once "a freshly opened map re-reads the same town (dedup is per screen)", /Pueblo Paleta/
end
