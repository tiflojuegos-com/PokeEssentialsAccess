# The Trainer Sensor of Sky's base and World Frontier's edit (games/skyflyer_common/trainer_sensor.rb): the dark bars
# coming in are said once, queued, the first frame they can be seen; their staying and their leaving are silent.

# The sensor as the game keeps it: show and hide slide the bars in and out, triggered? says whether they are in, update
# runs each frame, and the top bar's first pixel holds the colour drawn. The reader binds its hook to update once the
# module exists, so its file is evaluated again here, over it.
module TrainerSensor
  Pixel = Struct.new(:alpha)

  # The top bar's bitmap down to its first pixel.
  class Bars
    attr_accessor :alpha
    def initialize(alpha); @alpha = alpha; end
    def get_pixel(_x, _y); Pixel.new(@alpha); end
  end

  Top = Struct.new(:bitmap)

  @triggered = false
  @top = Top.new(Bars.new(255))
  def self.show; @triggered = true; end
  def self.hide; @triggered = false; end
  def self.triggered?; @triggered; end
  def self.update; @frames = (@frames || 0) + 1; end
  def self.alpha=(value); @top.bitmap.alpha = value; end
end

sky_sensor_path = File.join(Harness::ROOT, "games", "skyflyer_common", "trainer_sensor.rb")
begin
  verbose = $VERBOSE
  $VERBOSE = nil
  eval(Harness.source(sky_sensor_path), TOPLEVEL_BINDING, sky_sensor_path)
ensure
  $VERBOSE = verbose
end

class SkyTrainerSensorGdTest < PokeAccessTest
  test "the bars coming in are said once, queued, and staying in says nothing more" do
    sensing do
      TrainerSensor.show
      3.times { TrainerSensor.update }
      assert_equal [[near, false]], SpeakCapture.log
    end
  end

  test "bars that fade in are said the first frame they can be seen" do
    sensing(0) do
      TrainerSensor.show
      TrainerSensor.update
      assert_nothing_spoken
      TrainerSensor.alpha = 40
      2.times { TrainerSensor.update }
      assert_equal [[near, false]], SpeakCapture.log
    end
  end

  test "the bars leaving are silent, and coming back in is said again" do
    sensing do
      TrainerSensor.show
      TrainerSensor.update
      TrainerSensor.hide
      TrainerSensor.update
      TrainerSensor.show
      TrainerSensor.update
      assert_equal [[near, false], [near, false]], SpeakCapture.log
    end
  end

  test "with no trainer in range nothing is said, the bars clear or not" do
    sensing do
      2.times { TrainerSensor.update }
      assert_nothing_spoken
    end
  end

  private

  def near
    PokeAccess::I18n.t(:trainer_near)
  end

  # Runs the block with the bars out and not said, the top bar's first pixel at alpha; both put back after.
  def sensing(alpha = 255)
    TrainerSensor.hide
    TrainerSensor.alpha = alpha
    PokeAccess::SkyTrainerBars.instance_variable_set(:@said, false)
    yield
  ensure
    TrainerSensor.hide
    TrainerSensor.alpha = 255
    PokeAccess::SkyTrainerBars.instance_variable_set(:@said, false)
  end
end
