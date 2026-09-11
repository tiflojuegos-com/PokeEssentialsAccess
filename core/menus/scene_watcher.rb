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

    # The one-call form of wire for the common reader shape: hold the scene, poll it each frame, dedup by key
    # and speak on change. The block yields the held scene and returns [key, text]: nil or a non-pair skips
    # the frame, a nil key never speaks, and empty text un-burns the key and retries (Cursor.announce on a
    # generated holder, reset on open and close). text may be anything answering call, called only once the
    # key has changed. The FIRST read after opening is queued, since a screen often prints its own line from
    # inside the very method this polls. A raising block is swallowed per frame.
    # return the holder, for readers needing extra hooks over the same state
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
