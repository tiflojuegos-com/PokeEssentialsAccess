# Shared cases of turbo_test and turbo_gd_test: on the free map a change of the speed index or the frame rate is said
# (only the multiplier when both move); the first frame, a change off the map, in battle or in a quiet routine is not.
# Its reset and stages serve the other turbo tests too.
module TurboCases
  # The poller's memory as the mod boots, taken as this file loads, before any test runs.
  BOOT = PokeAccess::Turbo.instance_variables.map { |k| [k, PokeAccess::Turbo.instance_variable_get(k)] }

  # Puts the poller's memory back as the mod boots it.
  def self.reset
    BOOT.each { |k, v| PokeAccess::Turbo.instance_variable_set(k, v) }
  end

  # Sets the game's speed table, SPEEDUP_STAGES, to list, or removes it for nil, as the stubs keep none.
  def self.stages(list)
    Object.send(:remove_const, :SPEEDUP_STAGES) if Object.const_defined?(:SPEEDUP_STAGES, false)
    Object.const_set(:SPEEDUP_STAGES, list) unless list.nil?
  end

  # Defines the shared cases, and the helpers they use, on base: the test class of one engine pass.
  def self.define(base)
    base.class_eval do
      test "takes note of the speed on its first frame on the map without a word" do
        on_the_map([1, 2, 3], 1) do
          assert_equal [], frame
        end
      end

      test "says the multiplier the game's stage table gives the new index" do
        on_the_map([1, 3], 0) do
          frame
          assert_equal [[speed_text(3), true]], frame(1), "Relict's table: index 1 is x3"
          assert_equal [[speed_text(1), true]], frame(0), "and index 0 is x1"
        end
      end

      test "reads a fractional stage with the language's decimal comma" do
        on_the_map([1, 2, 2.5], 0) do
          frame
          assert_equal [[speed_text("2,5"), true]], frame(2), "Anil's table: index 2 is x2,5"
        end
      end

      test "reads Royal's table, kept under TurboConfig, and a whole stage written as a decimal without one" do
        royal = Module.new
        royal.const_set(:SPEED_STAGES, [1.0, 1.75, 2.5])
        with_const(:TurboConfig, royal) do
          on_the_map(nil, 0) do
            frame
            assert_equal [[speed_text("1,75"), true]], frame(1), "index 1 is x1,75"
            assert_equal [[speed_text(1), true]], frame(0), "index 0, 1.0, is x1"
          end
        end
      end

      test "counts the index from one where the game keeps no table" do
        on_the_map(nil, 1) do
          frame
          assert_equal [[speed_text(1), true]], frame(0), "index 0 is x1"
          assert_equal [[speed_text(3), true]], frame(2), "index 2 is x3"
        end
      end

      test "counts from one an index past the end of the game's table" do
        on_the_map([1, 3], 0) do
          frame
          assert_equal [[speed_text(3), true]], frame(2)
        end
      end

      test "says Better Fast Forward's index as the multiplier it already is" do
        with_const(:SPEED_SETTING_FILE, "Save Files/GameSpeedSetting.dat") do
          on_the_map(nil, 1) do
            frame
            [2, 3, 1].each do |index|
              assert_equal [[speed_text(index), true]], frame(index), "index #{index} is x#{index}"
            end
          end
        end
      end

      test "says nothing when the speed index is cleared, and says the next press" do
        on_the_map([1, 2, 3], 1) do
          frame
          assert_equal [], frame(nil), "no index, no multiplier to say"
          assert_equal [[speed_text(1), true]], frame(0), "the next press"
        end
      end

      test "says nothing on a frame where neither the speed nor the rate moved" do
        on_the_map([1, 2, 3], 0) do
          frame
          assert_equal [], frame(0)
        end
      end

      test "says neither move of a routine run quietly, then or after" do
        on_the_map([1, 2, 3], 1) do
          frame
          SpeakCapture.clear
          PokeAccess::Turbo.quietly do
            $GameSpeed = 0
            PokeAccess::Turbo.tick
            $GameSpeed = 2
            PokeAccess::Turbo.tick
          end
          assert_equal [], SpeakCapture.log, "inside the routine"
          assert_equal [], frame, "and on the frame after it"
        end
      end

      test "says the first press after a quiet routine" do
        on_the_map([1, 2, 3], 1) do
          frame
          PokeAccess::Turbo.quietly { $GameSpeed = 2 }
          assert_equal [[speed_text(1), true]], frame(0)
        end
      end

      test "takes the speed a failed quiet routine left without a word" do
        on_the_map([1, 2, 3], 1) do
          frame
          assert_raises(RuntimeError) do
            PokeAccess::Turbo.quietly do
              $GameSpeed = 2
              raise "the routine failed"
            end
          end
          assert_equal [], frame, "the speed it left is not said late"
          assert_equal [[speed_text(2), true]], frame(1), "and the next press is"
        end
      end

      test "says nothing of a change made off the free map" do
        { "on another scene" => lambda { $scene = Object.new },
          "with no player yet" => lambda { $game_player = nil },
          "in a battle the engine flags" => lambda { $game_temp.in_battle = true },
          "in a battle the mod flags" => lambda { PokeAccess::Battle.battle_started } }.each do |where, leave|
          on_the_map([1, 2, 3], 0) do
            frame
            leave.call
            assert_equal [], frame(1), where
          end
        end
      end

      test "takes the speed as it is on coming back to the free map, then says the next press" do
        ways = { "from another scene" => [lambda { $scene = Object.new }, lambda { $scene = Scene_Map.new }],
                 "from a battle" => [lambda { $game_temp.in_battle = true }, lambda { $game_temp.in_battle = false }] }
        ways.each do |from, (leave, back)|
          on_the_map([1, 2, 3], 0) do
            frame
            leave.call
            frame(1)
            back.call
            assert_equal [], frame, "#{from}: the change made away is not said"
            assert_equal [[speed_text(3), true]], frame(2), "#{from}: the next press is"
          end
        end
      end

      test "says a speed press where the engine has no frame rate to read" do
        on_the_map([1, 2, 3], 0) do
          Graphics.define_singleton_method(:frame_rate) { raise NoMethodError, "frame_rate" }
          frame
          assert_equal [[speed_text(2), true]], frame(1)
        end
      end

      test "says a speed press where the engine's Game_Temp keeps no battle flag" do
        on_the_map([1, 2, 3], 0) do
          $game_temp = Object.new
          frame
          assert_equal [[speed_text(2), true]], frame(1)
        end
      end

      test "skips a speed index it cannot read, and still says the next press" do
        on_the_map([1, 2, 3], 0) do
          frame
          assert_equal [], frame(Object.new), "an index with no number in it"
          assert_equal [[speed_text(2), true]], frame(1), "the poller goes on"
        end
      end

      test "says fast when the frame rate rises above the one the map first showed" do
        on_the_map do |rate|
          frame
          rate[0] *= 3
          assert_equal [[PokeAccess::I18n.t(:turbo_on), true]], frame
        end
      end

      test "says normal when the frame rate comes back to the map's first one" do
        on_the_map do |rate|
          base = rate[0]
          frame
          rate[0] = base * 3
          frame
          rate[0] = base
          assert_equal [[PokeAccess::I18n.t(:turbo_off), true]], frame
        end
      end

      test "says nothing of a rate that drops below the map's first one and comes back" do
        on_the_map do |rate|
          base = rate[0]
          frame
          rate[0] = 24
          assert_equal [], frame, "a cutscene's slower rate is not fast"
          rate[0] = base
          assert_equal [], frame, "so coming back from it is not normal"
        end
      end

      test "says fast once, not again when the fast rate changes" do
        on_the_map do |rate|
          base = rate[0]
          frame
          rate[0] = base * 2
          assert_equal [[PokeAccess::I18n.t(:turbo_on), true]], frame
          rate[0] = base * 3
          assert_equal [], frame
        end
      end

      test "measures fast against the rate the map first showed, not one seen off it" do
        on_the_map do |rate|
          base = rate[0]
          $scene = Object.new
          rate[0] = base * 3
          frame
          $scene = Scene_Map.new
          rate[0] = base
          frame
          rate[0] = base * 3
          assert_equal [[PokeAccess::I18n.t(:turbo_on), true]], frame
        end
      end

      test "takes a rate set in battle silently, and says fast again after it" do
        on_the_map do |rate|
          base = rate[0]
          frame
          rate[0] = base * 3
          frame
          $game_temp.in_battle = true
          rate[0] = base
          assert_equal [], frame, "Armonia sets its battle rate with the map scene still up"
          $game_temp.in_battle = false
          assert_equal [], frame, "back from battle the rate is taken as it is"
          rate[0] = base * 3
          assert_equal [[PokeAccess::I18n.t(:turbo_on), true]], frame, "and the next rise is said"
        end
      end

      test "says only the multiplier when the speed and the rate move in one frame" do
        on_the_map([1, 2, 3], 0) do |rate|
          base = rate[0]
          frame
          rate[0] = base * 2
          assert_equal [[speed_text(2), true]], frame(1), "Z binds both to Alt"
          assert_equal [], frame, "and fast is not said a frame late"
        end
      end

      private

      # The speed line for multiplier n, as said in Spanish.
      def speed_text(n)
        PokeAccess::I18n.t(:turbo_speed, :n => n)
      end

      # Sets the speed index (unless :keep), runs one frame of the poller and returns what it said, as [text,
      # interrupt] pairs.
      def frame(speed = :keep)
        $GameSpeed = speed unless speed == :keep
        SpeakCapture.clear
        PokeAccess::Turbo.tick
        SpeakCapture.log.dup
      end

      # Runs the block on the free map with the poller's memory as at boot, the game's SPEEDUP_STAGES set to stages
      # (none for nil), the speed index at speed and Graphics.frame_rate answering rate[0], the engine's own rate at
      # first; the block gets rate. The scene, the player, Game_Temp and its battle flag, the mod's battle flag, the
      # speed, the rate and the poller's memory are put back, and the table removed.
      def on_the_map(stages = nil, speed = nil)
        saved = [$scene, $game_player, $GameSpeed, $game_temp, $game_temp.in_battle]
        real_rate = Graphics.method(:frame_rate)
        rate = [real_rate.call]
        Graphics.define_singleton_method(:frame_rate) { rate[0] }
        TurboCases.stages(stages)
        $scene = Scene_Map.new
        $GameSpeed = speed
        TurboCases.reset
        yield rate
      ensure
        Graphics.define_singleton_method(:frame_rate, real_rate)
        TurboCases.stages(nil)
        $scene, $game_player, $GameSpeed, $game_temp = saved[0], saved[1], saved[2], saved[3]
        $game_temp.in_battle = saved[4]
        PokeAccess::Battle.battle_ended
        TurboCases.reset
      end

      # Runs the block with the top-level constant name set to value (absent for nil), then puts back what was there.
      def with_const(name, value)
        had = Object.const_defined?(name, false)
        was = had ? Object.const_get(name) : nil
        Object.send(:remove_const, name) if had
        Object.const_set(name, value) unless value.nil?
        yield
      ensure
        Object.send(:remove_const, name) if Object.const_defined?(name, false)
        Object.const_set(name, was) if had
      end
    end
  end
end
