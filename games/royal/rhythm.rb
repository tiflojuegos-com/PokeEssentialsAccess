# Royal's curry rhythm minigame (JuegoRitmo_Scene): notes travel right-to-left toward a fixed selector and
# you press the matching arrow as each one arrives. Rather than guess the hit geometry, the reader announces
# the DIRECTION of the note that is coming next, once per note. Combined with the game's own music the
# player can anticipate the beat, and it never claims a precision the reader cannot verify.
#
# Two things about this scene decide the whole shape of the reader:
#
#   * pbUpdate IS the game -- a `loop do` that only returns when the song ends -- so an after-hook on it
#     fires exactly once, on the way out. It calls Input.update every iteration, so SceneWatcher can hold
#     the scene and poll @notes each frame instead.
#   * SongNote#note is a STRING ("up"/"down"/"left"/"right", or "" for a rest beat), not an index. Treating
#     it as one made note.to_i == 0 for every note, so the reader said "arriba" for all of them.
#
# The skipping-rope minigame (JumpMinigame::Play) used to be read from here and is not any more: its
# @button array is filled with random directions by setButton but never read anywhere in the game, which is
# only "press C to jump". The reader was announcing, once per rope turn, a direction the player must not
# press. Timing that game by ear needs a cue designed against a live session, not a leftover ivar.
module PokeAccess
  module RoyalRhythm
    DIRS = { "up" => :roy_up, "down" => :roy_down, "left" => :roy_left, "right" => :roy_right }

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
