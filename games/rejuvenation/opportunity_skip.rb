# The game's own puzzle skip: an object drawn as object_opportunityskip that offers to skip the room's puzzle once
# enough badges are won. Its events go by numbers, so the locator names it by its graphic.
PokeAccess::Game.define("rejuvenation") do
  event_name do |ev|
    (ev.character_name.to_s rescue "") == "object_opportunityskip" ? PokeAccess::I18n.t(:rjd_opportunity_skip) : nil
  end
end
