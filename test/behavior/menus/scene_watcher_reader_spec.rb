# SceneWatcher.reader: the one-call form for held-scene pollers. The returned holder must speak the
# block's text when the key changes, stay silent on an unchanged key, consume a key with nil text
# silently, skip nil (not-readable-yet) frames without consuming, and reset its dedup on watch/unwatch
# so reopening on the same entry re-reads. The scene class here does not exist, so the wiring self-gates
# and the holder is driven directly, exactly as a game's blocking loop would.
Suite.define("scene_watcher: reader dedups by key, speaks on change, resets on rewatch") do
  holder = PokeAccess::SceneWatcher.reader("SwReaderNoSuchScene_pa", :main, :sw_spec) do |s|
    v = s.instance_variable_get(:@v)
    if v.nil?
      nil
    elsif v == :mute
      [v, nil]
    else
      [v, "item #{v}"]
    end
  end
  scene = World.stub_scene

  # With no scene held the block must not run AT ALL: a reader whose block assumes a scene would raise on
  # every idle frame otherwise, and the swallow would hide it. Silence alone did not prove that -- the
  # block returning nil is silent too -- so this counts the calls.
  calls = 0
  probe = PokeAccess::SceneWatcher.reader("SwProbeNoSuchScene_pa", :main, :sw_probe) { |_s| calls += 1; nil }
  probe.poll
  eq "with no scene held the block is never even called", calls, 0
  probe.watch(World.stub_scene)
  probe.poll
  eq "and it is called once a scene is held", calls, 1
  probe.unwatch

  holder.poll
  silent "no held scene, no speech"

  holder.watch(scene)
  holder.poll
  silent "a nil pair (nothing readable yet) stays silent"

  scene.instance_variable_set(:@v, 1)
  holder.poll
  spoke "the first poll speaks the focused item", /item 1/

  SpeakCapture.clear
  holder.poll
  silent "an unchanged key stays silent (dedup)"

  scene.instance_variable_set(:@v, 2)
  holder.poll
  spoke "a changed key speaks the new item", /item 2/

  SpeakCapture.clear
  scene.instance_variable_set(:@v, :mute)
  holder.poll
  silent "a key with nil text is consumed silently"

  scene.instance_variable_set(:@v, 2)
  holder.poll
  spoke "a change after a muted key speaks again", /item 2/

  SpeakCapture.clear
  holder.unwatch
  scene.instance_variable_set(:@v, 3)
  holder.poll
  silent "after unwatch nothing speaks"

  holder.watch(scene)
  scene.instance_variable_set(:@v, 2)
  holder.poll
  spoke "rewatching resets the dedup so the same LAST-CONSUMED key re-reads", /item 2/

  # unwatch resets the slot as well, and that half IS observable: poll on a re-held scene is not the only
  # way back in, because a reader can be driven while the holder is watching a DIFFERENT scene. Closing on
  # a key and reopening on the same one must read -- which is the whole point of resetting on both edges.
  holder.unwatch
  SpeakCapture.clear
  other = World.stub_scene
  other.instance_variable_set(:@v, 2)
  holder.watch(other)
  holder.poll
  spoke "and a different scene opening on that same key reads it too", /item 2/
  holder.unwatch
end
