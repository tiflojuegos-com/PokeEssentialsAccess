# Shared body of turbo_spec (gen-6 pass) and turbo_gd_spec (gamedata pass): the announcer is core and runs
# in every game, so both engine stubs drive the same cases. What is pinned: the first sight is silent, a
# speed index change on the map says the multiplier from the script's table (halves included), a frame-rate
# switch says fast or normal against the rate the map first showed, a move made off the map is neither
# announced nor announced late, and when both move in one frame only the multiplier is said.
module TurboCases
  # Runs the block with Graphics.frame_rate answering a settable value, restored afterwards.
  def self.with_rate
    orig = Graphics.method(:frame_rate)
    holder = [orig.call]
    Graphics.define_singleton_method(:frame_rate) { holder[0] }
    yield holder
  ensure
    Graphics.define_singleton_method(:frame_rate, orig)
  end

  def self.reset
    t = PokeAccess::Turbo
    [:@speed, :@rate, :@base_rate].each { |k| t.instance_variable_set(k, nil) }
    t.instance_variable_set(:@on_map, false)
    t.instance_variable_set(:@fast, false)
  end

  def self.stages(list)
    Object.send(:remove_const, :SPEEDUP_STAGES) if Object.const_defined?(:SPEEDUP_STAGES)
    Object.const_set(:SPEEDUP_STAGES, list) if list
  end

  def self.said
    SpeakCapture.lines.map { |l| l.to_s }
  end
end

def define_turbo_suites
  Suite.define("turbo: a speed index change on the map says the multiplier; first sight and off-map moves stay silent") do
    t = PokeAccess::Turbo
    old_scene = $scene
    $game_player ||= Object.new
    begin
      $scene = Scene_Map.new
      TurboCases.stages([1, 2, 3])
      $GameSpeed = 0
      TurboCases.reset
      SpeakCapture.clear
      t.tick
      eq "the first frame only takes note", TurboCases.said, []
      $GameSpeed = 1; t.tick
      eq "then a press says the new multiplier", TurboCases.said, [PokeAccess::I18n.t(:turbo_speed, :n => 2)]
      SpeakCapture.clear
      t.tick
      eq "a frame with no change says nothing", TurboCases.said, []
      $GameSpeed = 2; t.tick
      $GameSpeed = 0; t.tick
      eq "x3, then back to x1", TurboCases.said, [PokeAccess::I18n.t(:turbo_speed, :n => 3), PokeAccess::I18n.t(:turbo_speed, :n => 1)]

      TurboCases.stages([1, 1.5, 2.0])
      SpeakCapture.clear
      $GameSpeed = 1; t.tick
      $GameSpeed = 2; t.tick
      eq "Delta's table reads its halves, and a whole number without a decimal", TurboCases.said,
         [PokeAccess::I18n.t(:turbo_speed, :n => 1.5), PokeAccess::I18n.t(:turbo_speed, :n => 2)]

      TurboCases.stages(nil)
      SpeakCapture.clear
      $GameSpeed = 0; t.tick
      eq "without a table the index counts from one", TurboCases.said, [PokeAccess::I18n.t(:turbo_speed, :n => 1)]

      Object.const_set(:TurboConfig, Module.new) unless Object.const_defined?(:TurboConfig)
      TurboConfig.const_set(:SPEED_STAGES, [1.0, 1.5, 2.0])
      SpeakCapture.clear
      $GameSpeed = 1; t.tick
      $GameSpeed = 2; t.tick
      eq "Royal keeps its table under TurboConfig and says x1.5 then x2", TurboCases.said,
         [PokeAccess::I18n.t(:turbo_speed, :n => 1.5), PokeAccess::I18n.t(:turbo_speed, :n => 2)]
      Object.send(:remove_const, :TurboConfig)

      SpeakCapture.clear
      $scene = Object.new
      $GameSpeed = 1; t.tick
      eq "a move made off the map (Delta at battle start) is not announced", TurboCases.said, []
      $scene = Scene_Map.new
      t.tick
      eq "and coming back re-syncs without a word", TurboCases.said, []
      $GameSpeed = 2; t.tick
      eq "the next real press speaks again", TurboCases.said.length, 1

      SpeakCapture.clear
      $game_temp.in_battle = true
      $GameSpeed = 0; t.tick
      eq "a gen-6 battle keeps the map scene, so in_battle is what silences the auto change", TurboCases.said, []
      $game_temp.in_battle = false
      t.tick
      eq "and the return from battle re-syncs without a word", TurboCases.said, []
    ensure
      ($game_temp.in_battle = false rescue nil)
      Object.send(:remove_const, :TurboConfig) if Object.const_defined?(:TurboConfig)
      $scene = old_scene
      TurboCases.stages(nil)
      $GameSpeed = nil
      TurboCases.reset
    end
  end

  Suite.define("turbo: a frame-rate switch says fast or normal against the rate the map first showed") do
    t = PokeAccess::Turbo
    old_scene = $scene
    $game_player ||= Object.new
    begin
      $scene = Scene_Map.new
      $GameSpeed = nil
      TurboCases.stages(nil)
      TurboCases.with_rate do |rate|
        TurboCases.reset
        SpeakCapture.clear
        t.tick
        base = rate[0]
        rate[0] = base * 3; t.tick
        eq "three times the boot rate is fast", TurboCases.said, [PokeAccess::I18n.t(:turbo_on)]
        SpeakCapture.clear
        rate[0] = base; t.tick
        eq "and back is normal", TurboCases.said, [PokeAccess::I18n.t(:turbo_off)]
        SpeakCapture.clear
        t.tick
        eq "steady is silent", TurboCases.said, []
        rate[0] = 24; t.tick
        rate[0] = base; t.tick
        eq "a cutscene dropping below the base and coming back never flipped to fast, so says nothing", TurboCases.said, []
        rate[0] = base * 2; t.tick
        rate[0] = base * 3; t.tick
        eq "fast once, not again when the fast rate merely changes", TurboCases.said, [PokeAccess::I18n.t(:turbo_on)]
        SpeakCapture.clear
        $game_temp.in_battle = true
        rate[0] = base; t.tick
        eq "Armonia sets its battle rate with the map scene still up: in_battle silences it", TurboCases.said, []
        $game_temp.in_battle = false
        t.tick
        eq "back from battle the rate is taken as it is", TurboCases.said, []

        TurboCases.stages([1, 2, 3])
        TurboCases.reset
        $GameSpeed = 0; t.tick
        SpeakCapture.clear
        $GameSpeed = 1; rate[0] = base * 2; t.tick
        eq "when both move in one frame (Z binds both to Alt) only the multiplier is said", TurboCases.said,
           [PokeAccess::I18n.t(:turbo_speed, :n => 2)]
      end
    ensure
      ($game_temp.in_battle = false rescue nil)
      $scene = old_scene
      TurboCases.stages(nil)
      $GameSpeed = nil
      TurboCases.reset
    end
  end
end
