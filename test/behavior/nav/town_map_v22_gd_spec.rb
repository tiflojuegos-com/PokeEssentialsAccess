# v22 town map (TownMapV22): a town is named once when the cursor reaches it, a blank point is silent but takes the
# dedup key, so sweeping off a town and back names it again; the dedup is per screen.
Suite.define("town map v22: names the focused location once, stays quiet on blanks") do
  vis = Object.new
  def vis.point; @point; end
  def vis.point=(p); @point = p; end
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

  vis.point = "Pueblo Paleta"
  PokeAccess::TownMapV22.announce(vis)
  vis.point = nil
  PokeAccess::TownMapV22.announce(vis)
  vis.point = "Pueblo Paleta"
  SpeakCapture.clear
  PokeAccess::TownMapV22.announce(vis)
  spoke_once "sweeping off a town and back onto it names it again", /Pueblo Paleta/

  other = Object.new
  def other.get_point_data; { :real_name => "Pueblo Paleta" }; end
  SpeakCapture.clear
  PokeAccess::TownMapV22.announce(other)
  spoke_once "a freshly opened map re-reads the same town (dedup is per screen)", /Pueblo Paleta/
end
