module PokeAccess
  # For screens that run their own blocking input loop: holds the scene for the loop method's duration (an around
  # hook) and polls the reader each frame.
  module SceneWatcher
    # Wires a scene's blocking-loop method to a reader answering watch(scene), unwatch and poll; binds nothing where
    # the class is absent.
    # param opts passed to the hook (a plugin reader passes :optional => true)
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

    # wire for the common shape: the block gets the held scene and returns [key, text] (text may be callable), spoken
    # via Cursor.announce when key changes; a non-pair skips the frame. The first read after opening is queued.
    # param opts :queued => true to queue every read (a reader adding to another's line); the rest go to wire
    # return the holder, for readers needing extra hooks over the same state
    def self.reader(cls, meth, slot, opts = {}, &blk)
      queued = opts[:queued]
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
          spoken = PokeAccess::Cursor.announce(self, slot, pair[0], !@opening && !queued) do
            t = pair[1]
            t.respond_to?(:call) ? t.call : t
          end
          @opening = false if spoken
        rescue StandardError => e
          PokeAccess.log_once("scene_watcher_#{slot}", e)
        end
      end
      wire(cls, meth, holder, opts.reject { |k, _v| k == :queued })
      holder
    end
  end
end
