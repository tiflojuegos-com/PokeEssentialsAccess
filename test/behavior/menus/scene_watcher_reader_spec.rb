# SceneWatcher.reader: its holder speaks on a key change, consumes a key with nil text silently, skips nil frames,
# and resets its dedup on watch and unwatch; the scene class is absent, so the holder is driven by hand.
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
  scene.instance_variable_set(:@v, :late)
  scene.instance_variable_set(:@late_text, nil)
  late = PokeAccess::SceneWatcher.reader("SwLateNoSuchScene_pa", :main, :sw_late) do |s|
    [s.instance_variable_get(:@v), s.instance_variable_get(:@late_text).to_s]
  end
  late.watch(scene)
  late.poll
  silent "an empty-text frame stays silent"
  scene.instance_variable_set(:@late_text, "late row")
  late.poll
  spoke "the SAME key speaks once its text arrives", /late row/
  late.unwatch

  SpeakCapture.clear
  holder.unwatch
  scene.instance_variable_set(:@v, 3)
  holder.poll
  silent "after unwatch nothing speaks"

  holder.watch(scene)
  scene.instance_variable_set(:@v, 2)
  holder.poll
  spoke "rewatching resets the dedup so the same LAST-CONSUMED key re-reads", /item 2/

  holder.unwatch
  SpeakCapture.clear
  other = World.stub_scene
  other.instance_variable_set(:@v, 2)
  holder.watch(other)
  holder.poll
  spoke "and a different scene opening on that same key reads it too", /item 2/
  holder.unwatch
end

# A reader's text may be a callable, built only on the frames that speak; a callable that raises is logged, not said.
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

  logged =lambda { |key| !!(PokeAccess.instance_variable_get(:@logged_once) || {})[key] }
  boom = PokeAccess::SceneWatcher.reader("SwLazyBoomNoSuchScene_pa", :main, :sw_lazy_boom) do |_s|
    [:k, lambda { raise "texto roto" }]
  end
  boom.watch(World.stub_scene)
  SpeakCapture.clear
  boom.poll
  silent "a raising callable does not speak and does not take the loop down"
  truthy "but it is recorded", logged.call("cursor_sw_lazy_boom")
  boom.unwatch
end

# A reader that adds to what another says on the same move (a reward's description under the list that names
# the reward) is always queued, its later reads too, so it never cuts the name.
Suite.define("scene_watcher: a queued reader never cuts what was said before it") do
  holder = PokeAccess::SceneWatcher.reader("SwQueuedNoSuchScene_pa", :main, :sw_queued, :queued => true) do |s|
    v = s.instance_variable_get(:@v)
    v ? [v, "desc #{v}"] : nil
  end
  scene = World.stub_scene(:@v => 1)
  holder.watch(scene)
  begin
    holder.poll
    scene.instance_variable_set(:@v, 2)
    SpeakCapture.clear
    holder.poll
    eq "a later read is queued as well", SpeakCapture.log, [["desc 2", false]]
  ensure
    holder.unwatch
  end
end
