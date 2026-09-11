# Royal's curry rhythm minigame (JuegoRitmo_Scene): notes travel toward a fixed selector and you press the
# matching arrow as each arrives. The reader announces the DIRECTION of the note coming next, once per note,
# never claiming a precision it cannot verify. pbUpdate IS the game (a loop that returns when the song ends)
# and calls Input.update every iteration, so SceneWatcher holds the scene and polls @notes. SongNote#note is
# a STRING ("up"/"down"/"left"/"right", "" for a rest). The skipping-rope minigame is deliberately not read:
# its @button array is never used by the game, which is only "press C to jump".
module PokeAccess
  module RoyalRhythm
    # The shared dir_* keys, not a royal-only copy: roy_up/down/left/right were byte-for-byte identical to
    # them in both languages, so the duplicate was four more strings to keep in sync for no gain.
    DIRS = { "up" => :dir_up, "down" => :dir_down, "left" => :dir_left, "right" => :dir_right }

    # Where notes are judged, by the game's own formula (the selector_x it passes to SongNote#check).
    def self.selector_x(scene)
      sprites = PokeAccess.ivar(scene, :@sprites)
      s = sprites.is_a?(Hash) ? sprites["selector"] : nil
      w = (s && s.bitmap) ? s.bitmap.width : 0
      (Graphics.width / 2) - (w / 2) + 7
    end

    # The note the player still has to hit: not yet hit, not yet past the selector, and an actual direction
    # (the songs interleave "" as rests). A missed note is only marked hit when some key is pressed, so
    # "first un-hit note" alone would stick forever on one the player let through in silence.
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
