# Scorpiopoli's gym, El Purgatorio: four cells around the hall (map 192) to clear against the game's timer, which parallel
# events of each room watch and which sends the player back to the gym's entrance once it runs out. The timer is on screen
# alone, so the info key says what is left in every room. Map 193: photos and posters with no sprite on the walls (events
# 3 to 14 and 26 to 29), the Houndoom's photo (event 24, a picture: a Houndoom in a canyon, which one of Rod Aruka's
# photos shows) and the chest (event 21) that asks whose Houndoom it is, a wrong answer sending the player out. Map 195: a
# path with no sprite through touch tiles (events 1 to 64 and 71 to 74) that put the player back at its start (25,50).
# Map 179: furniture with no sprite (events 3 to 32), the open safe (event 31) giving the fourth pass (switch 288).
module PokeAccess
  module XenoPurgatory
    HALL = 192
    HOUNDOOM = 193
    PATH = 195
    STUDY = 179
    ROOMS = [179, 192, 193, 194, 195]
    PHOTOS = (3..14).to_a
    POSTERS = (26..29).to_a
    HOUNDOOM_PHOTO = 24
    CHEST = 21
    PATH_TRAPS = (1..64).to_a + (71..74).to_a
    PATH_START = [25, 50]
    NOTES = [3, 4, 5, 6, 7, 8, 11, 20, 27]
    BOXES = [9, 14, 16, 17, 18, 19, 30, 32]
    FLASKS = [10, 28]
    PAINTING = 23
    BOOKS = [25, 26]
    BUTTONS = [21, 22]
    SAFE = 31

    # True while the game's timer runs.
    def self.timing?
      ($game_system.timer_working rescue false) ? true : false
    end

    # The time the game's timer has left, in minutes and seconds, or nil while it is stopped.
    def self.time_line
      return nil unless timing?
      secs = ($game_system.timer rescue 0).to_i / (Graphics.frame_rate rescue 40)
      [:xv_purgatory_time, { :min => secs / 60, :sec => secs % 60 }]
    end
  end
end

PokeAccess::Game.define("xenoverse") do
  hell = PokeAccess::XenoPurgatory
  hell::ROOMS.each do |map|
    mechanic(:state, map) do
      auto
      info { hell.time_line }
      active { hell.timing? }
      arrival_hint lambda { hell.timing? ? :xv_purgatory_rule : nil }, :once => true
      if map == hell::HOUNDOOM
        name hell::PHOTOS, :xv_purgatory_photo
        name hell::POSTERS, :xv_purgatory_poster
        name hell::HOUNDOOM_PHOTO, :xv_purgatory_houndoom_photo
        on_use hell::HOUNDOOM_PHOTO, lambda {
          [:xv_purgatory_houndoom_shows, { :pokemon => PokeAccess::Data.species_name(:HOUNDOOM) }]
        }
        name hell::CHEST, :xv_purgatory_chest
        right_choice hell::CHEST, :avoids => :transfer
      end
      if map == hell::PATH
        hide hell::PATH_TRAPS
        sent_back :xv_purgatory_path_back, :to => hell::PATH_START, :events => hell::PATH_TRAPS
      end
      if map == hell::STUDY
        name hell::NOTES, :xv_purgatory_note
        name hell::BOXES, :xv_purgatory_boxes
        name hell::FLASKS, :xv_purgatory_flasks
        name hell::PAINTING, :xv_purgatory_painting
        name hell::BOOKS, :xv_purgatory_books
        name hell::BUTTONS, :xv_purgatory_button
        name hell::SAFE, :xv_purgatory_safe
        hint :xv_purgatory_safe_hint
      end
    end
  end
end
