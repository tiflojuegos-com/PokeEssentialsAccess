module PokeAccess
  # Wiring helper for screens that run their own blocking input loop, so the normal cursor hooks never fire
  # mid-loop and the focused item must be polled each frame instead. It holds the active scene for the
  # duration of the loop method (via an around-hook) and runs the reader's per-frame poll, removing the
  # identical around+poll_each_frame boilerplate that each such reader would otherwise repeat.
  module SceneWatcher
    # Wires a loop method to a reader module. cls/meth: the scene class and its blocking-loop method;
    # reader: a module responding to watch(scene), unwatch and poll. The hook self-gates on the class
    # existing, so it no-ops in games without that scene.
    #
    # param opts goes straight to the hook; a plugin reader passes :optional => true, since a third-party
    #   plugin shipping under the same class name with a renamed loop is variance and not a typo
    def self.wire(cls, meth, reader, opts = {})
      PokeAccess::Game.define do
        around(cls, meth, opts) do |scene, call_next, _a|
          reader.watch(scene)
          begin
            call_next.call
          ensure
            reader.unwatch
          end
        end
        poll_each_frame { reader.poll }
      end
    end

    # The one-call form of wire for the COMMON reader shape: hold the scene, poll it each frame, dedup by
    # key and speak on change. The block yields the held scene and returns [key, text]: a changed key speaks
    # the text (cleaned, interrupting), nil or a non-pair skips the frame, a nil key never speaks (Cursor's
    # contract), and a real key with empty text un-burns the key and retries -- text that lands a frame
    # after the key still gets spoken, and a deliberately mute row stays silent by keeping its text blank.
    # Speaking and dedup are Cursor.announce on a generated holder, reset on open AND close so reopening on
    # the same entry re-reads. A raising block is swallowed per frame, since a reader bug must not kill the
    # input loop, and blocks use next rather than
    # return (define_method under 1.8.7). Returns the holder, for readers needing extra hooks over the same
    # state; one with its own speak timing or an extra API keeps using wire directly.
    #
    # text may instead be anything answering call, and is then called only once the key has changed: a
    # cursor sits still, so the key matches on the other 39 frames of every second and text built on them is
    # thrown away unread -- free for "#{name}", not for a reader that asks the game a question to word
    # itself. The FIRST read after opening is queued rather than interrupting, because a screen often prints
    # its own instruction line from inside the very method this polls.
    def self.reader(cls, meth, slot, opts = {}, &blk)
      holder = Object.new
      meta = class << holder; self; end
      meta.send(:define_method, :watch) do |scene|
        @scene = scene
        @opening = true
        PokeAccess::Cursor.reset(self, slot)
      end
      meta.send(:define_method, :unwatch) do
        @scene = nil
        PokeAccess::Cursor.reset(self, slot)
      end
      meta.send(:define_method, :poll) do
        s = @scene
        next unless s
        begin
          pair = blk.call(s)
          next unless pair.is_a?(Array)
          spoken = PokeAccess::Cursor.announce(self, slot, pair[0], !@opening) do
            t = pair[1]
            t.respond_to?(:call) ? t.call : t
          end
          @opening = false if spoken
        rescue StandardError => e
          PokeAccess.log_once("scene_watcher_#{slot}", e)
        end
      end
      wire(cls, meth, holder, opts)
      holder
    end
  end
end
