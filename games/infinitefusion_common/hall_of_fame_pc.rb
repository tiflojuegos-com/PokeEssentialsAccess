module PokeAccess
  # The PC Hall of Fame of both games: past a record's last member the viewer turns to the record's entry page
  # (HallOfFame_Scene#writeWelcomePC), its title, date, mode and difficulty said as painted, cutting in as the member
  # panels do; Hoenn adds the rematch tier to the title.
  module IFHallOfFamePC
    # Notes the page on show, :entry or :member; turning from the entry page to a member frees core's member slot, so
    # the member the entry page followed is read again.
    def self.turn_to(scene, page)
      return unless PokeAccess::Cursor.changed?(scene, :if_hof_page, page)
      PokeAccess::Cursor.reset(scene, :hof_pk) if page == :member
    end
  end
end

PokeAccess::Game.define("infinitefusion_common") do
  around("HallOfFame_Scene", :writeWelcomePC) do |scene, nxt, _a|
    PokeAccess::IFHallOfFamePC.turn_to(scene, :entry)
    PokeAccess::PaintCapture.speak_around(:if_hof_entry, true) { nxt.call }
  end
  before("HallOfFame_Scene", :writePokemonData) do |scene, _a|
    PokeAccess::IFHallOfFamePC.turn_to(scene, :member)
  end
end
