# Royal's rhythm minigame (JuegoRitmo_Scene): the direction of the next note, once per note, polled while pbUpdate
# (the whole song) runs. SongNote#note is a string: "up", "down", "left", "right", or "" for a rest.
module PokeAccess
  module RoyalRhythm
    # The arrow buttons' names (btn_*), bare words, unlike dir_*, which carry a preposition in some languages.
    DIRS = { "up" => :btn_up, "down" => :btn_down, "left" => :btn_left, "right" => :btn_right }

    # Where notes are judged, by the game's own formula (the selector_x it passes to SongNote#check).
    def self.selector_x(scene)
      sprites = PokeAccess.ivar(scene, :@sprites)
      s = sprites.is_a?(Hash) ? sprites["selector"] : nil
      w = (s && s.bitmap) ? s.bitmap.width : 0
      (Graphics.width / 2) - (w / 2) + 7
    end

    # The next note to hit: unhit, not past the selector (a missed note stays unhit until a key press), not a rest.
    def self.pending(scene)
      notes = PokeAccess.ivar(scene, :@notes)
      return nil unless notes.is_a?(Array)
      sel = selector_x(scene)
      notes.each do |n|
        next if (n.hit rescue true)
        x = (n.x rescue nil)
        next if x.nil? || x < sel
        return n if DIRS.has_key?((n.note rescue nil))
      end
      nil
    end
  end

  RoyalRhythmReader = SceneWatcher.reader("JuegoRitmo_Scene", :pbUpdate, :roy_note) do |s|
    n = PokeAccess::RoyalRhythm.pending(s)
    n ? [(n.id rescue nil), PokeAccess::I18n.t(PokeAccess::RoyalRhythm::DIRS[n.note])] : nil
  end
end
