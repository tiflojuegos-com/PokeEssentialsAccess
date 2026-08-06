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
    # opts go straight to the hook. A plugin reader passes :optional => true, because a third-party plugin
    # shipping under the same class name with a renamed loop is variance and not a typo -- the rule that
    # every plugin hook is optional applies here too, and it used to be missed because it is this helper
    # that registers the hook rather than the plugin file the checker reads.
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
    # key and speak on change. The block yields the held scene and returns [key, text]: a changed key
    # speaks the text (cleaned, interrupting); nil (or a non-pair) skips the frame; a nil key never speaks
    # (Cursor's contract); a real key with nil/empty text consumes the key silently. Dedup lives in a
    # Cursor slot on a generated holder, reset on open AND close so reopening on the same entry re-reads.
    # A raising block is swallowed per frame (a reader bug must not kill the input loop). Returns the
    # holder for readers that need extra hooks over the same state. Blocks use next, not return
    # (define_method under 1.8.7). Modules with a non-poll shape (own speak timing, an extra API like
    # ReminBag's watching?) keep using wire directly.
    #
    # text may instead be anything answering call, and then it is only called once the key has actually
    # changed. Cursors sit still: the player picks an entry and stays on it, so the key matches on the
    # other 39 frames of every second and the text built on them is thrown away unread. That is free for
    # "#{name}" and not at all free for a reader that asks the game a question to word itself.
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
          next unless PokeAccess::Cursor.changed?(self, slot, pair[0])
          t = pair[1]
          t = t.call if t.respond_to?(:call)
          next if t.nil? || t.to_s.empty?
          # The FIRST read after opening is queued, not interrupting. A screen often prints its own line as
          # it opens -- royal's random-mode selector displays "press X when you are done" from inside the
          # very method this polls -- and cutting that leaves the player without the one instruction the
          # screen gives. Every later read interrupts, which is what a moving cursor needs.
          PokeAccess.speak(PokeAccess.clean(t.to_s), !@opening)
          @opening = false
        rescue StandardError => e
          PokeAccess.log_once("scene_watcher_#{slot}", e)
        end
      end
      wire(cls, meth, holder, opts)
      holder
    end
  end
end
