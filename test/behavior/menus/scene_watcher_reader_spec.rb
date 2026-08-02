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

# A cursor sits still. The player picks an entry and stays on it, so on 39 frames out of 40 the key matches
# and whatever text the block built gets thrown away unread. Free for "item #{v}"; not free for the readers
# that ask the game a question to word themselves -- Awakening's outfit list calls into Fates_Utilities, the
# photo album stats a file for its date. Returning something callable defers that to the frames that speak.
Suite.define("scene watcher: text that costs something is only built when it will be heard") do
  builds = 0
  holder = PokeAccess::SceneWatcher.reader("SwLazyNoSuchScene_pa", :main, :sw_lazy) do |s|
    v = s.instance_variable_get(:@v)
    v.nil? ? nil : [v, lambda { builds += 1; "item #{v}" }]
  end
  scene = World.stub_scene
  holder.watch(scene)

  scene.instance_variable_set(:@v, 1)
  holder.poll
  spoke "a callable is called and its text spoken", /item 1/
  eq "and it ran exactly once", builds, 1

  SpeakCapture.clear
  5.times { holder.poll }
  silent "sitting on the same entry stays silent"
  eq "and never builds the text again", builds, 1

  scene.instance_variable_set(:@v, 2)
  holder.poll
  spoke "moving builds it once more", /item 2/
  eq "once, not twice", builds, 2
  holder.unwatch

  # A callable that blows up must behave like a block that blows up: no speech, no crash, one log line. By
  # then the key is already consumed, so without the marker it would be a reader that died quietly forever.
  logged = lambda { |key| !!(PokeAccess.instance_variable_get(:@logged_once) || {})[key] }
  boom = PokeAccess::SceneWatcher.reader("SwLazyBoomNoSuchScene_pa", :main, :sw_lazy_boom) do |_s|
    [:k, lambda { raise "texto roto" }]
  end
  boom.watch(World.stub_scene)
  SpeakCapture.clear
  boom.poll
  silent "a raising callable does not speak and does not take the loop down"
  truthy "but it is recorded", logged.call("scene_watcher_sw_lazy_boom")
  boom.unwatch
end
