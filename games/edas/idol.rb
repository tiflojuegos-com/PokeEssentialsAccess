# Edas' rhythm game (Idol in 0218_Pesca, one of its endings): a hundred random arrows slide toward a selector, each to be
# pressed as it comes within reach, with nothing written. What it is and how it goes as it opens, then the guide's flat
# chime toward each arrow, shortly before it comes within reach, once per note in the song's order.
module PokeAccess
  module EdasIdol
    # The notes' arrows, by the names the song gives them: the direction the chime sounds toward and the word.
    NOTES = { "up" => [8, :dir_up], "down" => [2, :dir_down], "left" => [4, :dir_left], "right" => [6, :dir_right] }
    # Seconds before a note comes within reach of the selector that its arrow sounds.
    CUE_LEAD = 0.2

    @game = nil

    def self.hold(scene); @game = scene; end
    def self.release; @game = nil; end

    # What the game opens with, queued.
    def self.title
      PokeAccess::Verbosity.with_hint(PokeAccess::I18n.t(:edas_idol_title), PokeAccess::I18n.t(:edas_idol_hint))
    end

    # Each frame of the game: the arrow of each note due, once per note, in the song's order.
    def self.poll
      s = @game
      return unless s
      notes = PokeAccess.ivar(s, :@notes)
      sel = PokeAccess.sprite(s, "selector")
      return unless notes.is_a?(Array) && sel
      sx = Graphics.width / 2 - sel.bitmap.width / 2
      done = s.instance_variable_get(:@access_idol_note) || -1
      notes.each_with_index do |n, i|
        next if i <= done
        arrow = NOTES[n.note.to_s]
        next unless arrow && !n.hit && due?(n, sx)
        s.instance_variable_set(:@access_idol_note, i)
        cue(arrow)
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Whether a note's arrow is due: nearer the selector than its reach plus the steps it takes in CUE_LEAD seconds
    # (its step_distance a frame), and not past its reach yet.
    def self.due?(note, sx)
      lead = CUE_LEAD * Graphics.frame_rate * note.step_distance.to_f
      off = note.x - sx
      off < note.range + lead && off > -note.range
    end

    # A note's arrow as the guide's flat chime toward it, at the minigames' volume; the word, cutting in, with those
    # sounds off.
    def self.cue(arrow)
      vol = PokeAccess::Sound::Mixer.volume(:minigame)
      return PokeAccess.speak(PokeAccess::I18n.t(arrow[1]), true) unless vol && vol > 0
      PokeAccess::Sound.flat(PokeAccess::Sound::Catalog.entry(:guide), arrow[0], vol)
    end
  end
end

PokeAccess::Game.define("edas") do
  read_on_open("Idol", :pbStartScene) { |_scene| PokeAccess::EdasIdol.title }
  around("Idol", :pbUpdate) do |scene, nxt, _a|
    PokeAccess::EdasIdol.hold(scene)
    begin
      nxt.call
    ensure
      PokeAccess::EdasIdol.release
    end
  end
  poll_each_frame { PokeAccess::EdasIdol.poll }
end
