# SceneWatcher.wire is the plumbing under every reader for a screen that runs its OWN blocking input loop
# (a fangame bag, a card screen): it holds the live scene for the duration of that loop method and runs the
# reader's per-frame poll, because the normal cursor hooks never fire while the game is inside its own loop.
# The existing reader spec drives the returned holder by hand against a class that does not exist, so the
# around-hook -- the whole point of wire -- was never executed. This suite wires a REAL class with a real
# loop method and checks the three things a player depends on:
#   (a) while the loop runs, the reader holds THAT scene (otherwise poll has nothing to read and the screen
#       is silent);
#   (b) when the loop returns, the scene is released (a held dead scene makes the next screen read the old
#       one, or read nothing because the poll keeps answering from the corpse);
#   (c) CRITICAL: if the game's loop RAISES -- a fangame screen crashing on a missing sprite is routine --
#       the release still happens, because wire's unwatch lives in an ensure. Without it the mod would poll
#       a dead scene for the rest of the session, and every later screen would be read wrong or not at all.
# The exception must also still reach the game (wire wraps, it does not swallow): a screen that silently
# stops failing would hide the fangame's own bug.
Suite.define("scene_watcher: wire holds the scene for the loop, releases it, and releases it on a crash too") do
  reader = Object.new
  class << reader
    attr_reader :scene, :log, :polled

    # Records what wire did to us, so the spec can assert the watch/unwatch pairing and not just the end state.
    def reset!; @scene = nil; @log = []; @polled = []; end

    def watch(s); @scene = s; @log.push(:watch); end

    def unwatch; @scene = nil; @log.push(:unwatch); end

    def poll; @polled.push(@scene); end
  end
  reader.reset!

  seen = []
  klass = Class.new do
    # A game's blocking loop: it ticks the frame pollers (as the engine's Input.update does) and finishes.
    define_method(:main) do
      PokeAccess::Keys.run_frame_pollers
      seen.push(reader.scene)
      :loop_done
    end

    # The same loop, but the screen blows up mid-frame -- the case the ensure exists for.
    define_method(:crash) do
      seen.push(reader.scene)
      raise "fangame screen blew up"
    end
  end
  Object.const_set(:SwWireLoopScene_pa, klass) unless Object.const_defined?(:SwWireLoopScene_pa)
  PokeAccess::SceneWatcher.wire("SwWireLoopScene_pa", :main, reader)
  PokeAccess::SceneWatcher.wire("SwWireLoopScene_pa", :crash, reader)
  scene = SwWireLoopScene_pa.new
  other = SwWireLoopScene_pa.new

  begin
    eq "before any loop the reader holds nothing", reader.scene, nil
    PokeAccess::Keys.run_frame_pollers
    eq "a frame poll outside the loop sees no scene", reader.polled.last, nil

    reader.reset!
    seen.clear
    result = scene.main
    eq "the game's loop still returns its own value", result, :loop_done
    truthy "while the loop ran the reader held THAT scene", seen.last.equal?(scene)
    truthy "and the per-frame poll saw it", reader.polled.last.equal?(scene)
    eq "watch and unwatch fired once each, in that order", reader.log, [:watch, :unwatch]
    eq "the scene is released when the loop returns", reader.scene, nil

    reader.reset!
    other.main
    truthy "a second screen is held in its turn, not the first", seen.last.equal?(other)
    eq "and it is released too", reader.scene, nil

    reader.reset!
    seen.clear
    outcome = (begin; scene.crash; :no_raise; rescue StandardError => e; e.message; end)
    eq "the game's own exception still reaches the game (wire wraps, never swallows)",
       outcome, "fangame screen blew up"
    truthy "the doomed loop really did run with the scene held", seen.last.equal?(scene)
    eq "the scene is released ANYWAY: unwatch is in an ensure", reader.scene, nil
    eq "watch and unwatch stay paired across the crash", reader.log, [:watch, :unwatch]

    reader.reset!
    seen.clear
    eq "a normal loop after the crash still works", scene.main, :loop_done
    truthy "and still holds the scene", seen.last.equal?(scene)
    eq "and still releases it", reader.scene, nil
  ensure
    reader.unwatch
    reader.reset!
  end
end
