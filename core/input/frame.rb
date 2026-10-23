module PokeAccess
  # The two beats the mod runs on. The pulse runs every frame in any scene or modal loop (Input.update): keyboard
  # picture, remap, global keys, pollers and the control check. The map frame runs once per Game_Player#update (one
  # frame_hook): the stages :world, :control, :nav and :sound, each one's steps by order number, not load order.
  module Frame
    STAGES = [:world, :control, :nav, :sound]

    # Pulses in a row with no map frame before the map counts as stalled: a screen running its own loop over it. A
    # message closing leaves two in a normal game; six keep a margin, about a tenth of a second. A transition does
    # not count, since Graphics.transition never calls Input.update.
    STALL_PULSES = 6

    @steps = {}
    @pollers = []
    @serial = 0
    @pulses = 0
    @depth = 0
    @registered = 0
    @idle = 0

    # Registers a map-frame step in a stage at an order number (lower runs first; equal numbers keep registration
    # order); registering a name again replaces its step, which then counts as registered last.
    def self.step(stage, order, name, &blk)
      @registered += 1
      list = (@steps[stage] || []).reject { |s| s[2] == name }
      list.push([order, @registered, name, blk])
      @steps[stage] = list.sort_by { |s| [s[0], s[1]] }
      name
    end

    # The step names of a stage, in the order they run.
    def self.steps_of(stage); (@steps[stage] || []).map { |s| s[2] }; end

    # Registers a block for every pulse, after the global keys (Game.define's poll_each_frame).
    def self.each_pulse(&blk); @pollers.push(blk) if blk; end

    # Counts the map frames: what per-frame memos key on.
    def self.serial; @serial; end

    # Counts the pulses: a modal loop run from inside a map frame's step pulses while that frame still runs.
    def self.pulses; @pulses; end

    # True while a map frame runs: the span per-frame memos (Control's) hold for.
    def self.running?; @depth > 0; end

    # True once the pulses run on with no map frame: a screen loops over the map without a flag or a scene change.
    def self.stalled?; @idle >= STALL_PULSES; end

    # One map frame: the world, control and navigation stages while the mod listens on the map, filed under
    # navigation, then the sound stage, which also silences what must stop.
    def self.run
      @serial += 1
      @idle = 0
      @depth += 1
      PokeAccess::World::Epoch.dirty!
      if PokeAccess::Locator.polling?
        PokeAccess::Speech.as(:nav) { [:world, :control, :nav].each { |stage| run_stage(stage) } }
      end
      run_stage(:sound)
    ensure
      @depth -= 1
    end

    # Runs one stage's steps in order, each guarded so a failing one cannot stop the rest, measured as frame_<stage>.
    def self.run_stage(stage)
      PokeAccess::Perf.measure(:"frame_#{stage}") do
        (@steps[stage] || []).each do |s|
          begin
            s[3].call
          rescue StandardError => e
            PokeAccess.log_once("frame_#{s[2]}", e)
          end
        end
      end
    end

    # One pulse: the keyboard's picture first, so every reader this frame compares against the same keys.
    def self.pulse
      @idle += 1
      @pulses += 1
      PokeAccess::World::Epoch.dirty!
      PokeAccess::Keyboard.snapshot
      [[:remap, lambda { PokeAccess::Remap.update }],
       [:global_poll, lambda { PokeAccess::Keys.global_poll }],
       [:pollers, lambda { run_pollers }],
       [:control, lambda { PokeAccess::Control.pulse }]].each do |name, job|
        begin
          job.call
        rescue StandardError => e
          PokeAccess.log_once("pulse_#{name}", e)
        end
      end
    end

    # Runs every registered poller, each guarded so one failure cannot stop the others.
    def self.run_pollers
      @pollers.each_with_index do |cb, i|
        begin
          cb.call
        rescue StandardError => e
          PokeAccess.log_once("frame_poller_#{i}", e)
        end
      end
    end

    step(:world, 10, :map_change) { PokeAccess::Locator.announce_map_change }
    step(:world, 20, :teleport)   { PokeAccess::Locator.announce_internal_teleport }
    step(:world, 25, :forced_move) { PokeAccess::ForcedMove.tick }
    step(:world, 30, :event_end)  { PokeAccess::Locator.refresh_on_event_end }
    step(:world, 40, :battle_end) { PokeAccess::Battle.clear_battle }
    step(:world, 50, :info)       { PokeAccess::Locator.refresh_info }
    step(:control, 10, :control)  { PokeAccess::Control.evaluate }
    step(:nav, 10, :listener)     { PokeAccess::Sound.follow_player if PokeAccess::Control.free? }
    step(:nav, 20, :feedback)     { PokeAccess::Sound::Feedback.tick }
    step(:nav, 22, :held_carry)   { PokeAccess::HeldCarry.tick if PokeAccess::Control.free? }
    step(:nav, 25, :surfaces)     { PokeAccess::Surfaces.tick }
    step(:nav, 30, :guide)        { PokeAccess::Guide.tick }
    step(:nav, 50, :puzzles)      { PokeAccess::Puzzles.tick }
    step(:nav, 60, :keys)         { PokeAccess::Locator.poll_keys }
    step(:nav, 70, :regions)      { PokeAccess::Routes::Regions.tick if PokeAccess::Control.free? }
    step(:nav, 75, :hpa)          { PokeAccess::Pathfinder.hpa_tick if PokeAccess::Control.free? }
    step(:sound, 10, :soundscape) { PokeAccess::Sound::Scheduler.tick }
  end
end

# The map frame: one hook for the whole table. A frame_hook, not an after_hook: gen 6 runs a whole wild battle inside
# Game_Player#update, and a guarded hook would mute every battle reader for the fight.
PokeAccess::Hooks.frame_hook("Game_Player", :update) { |_p, _a| PokeAccess::Frame.run }

# The pulse, after Input.update in every scene and inside every modal loop, measured as :input_frame.
begin
  class << Input
    unless method_defined?(:update__access_orig)
      PokeAccess::Hooks.keep_bound(self, :update) do |_again|
        alias_method :update__access_orig, :update
        def update(*a)
          r = update__access_orig(*a)
          begin
            PokeAccess::Perf.measure(:input_frame) { PokeAccess::Frame.pulse }
          rescue StandardError => e
            PokeAccess.log_once("input_frame", e)
          end
          r
        end
      end
    end
  end
rescue StandardError => e
  PokeAccess.write_marker("hook_input: #{e.message}\n")
end
