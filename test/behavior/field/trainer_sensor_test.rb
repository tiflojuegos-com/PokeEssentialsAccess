# Pokemon Z's Trainer Sensor (games/pokemon_z/trainer_sensor.rb): the dark bars coming in are said once, queued;
# their staying and their leaving are silent, and bars the game fills clear (its switch 411) are not seen, so not said.

# The sensor as the game keeps it: show and hide slide the bars in and out, triggered? says whether they are in, and
# update runs each frame. The profile binds its hook to update once the module exists, so its file is evaluated
# again here, over it.
module TrainerSensor
  @triggered = false
  def self.show; @triggered = true; end
  def self.hide; @triggered = false; end
  def self.triggered?; @triggered; end
  def self.update; @frames = (@frames || 0) + 1; end
end

trainer_sensor_path = File.join(Harness::ROOT, "games", "pokemon_z", "trainer_sensor.rb")
begin
  verbose = $VERBOSE
  $VERBOSE = nil
  eval(Harness.source(trainer_sensor_path), TOPLEVEL_BINDING, trainer_sensor_path)
ensure
  $VERBOSE = verbose
end

class TrainerSensorTest < PokeAccessTest
  # Whether the bars count as in when the profile loads, which each test starts from and leaves behind.
  LOADED_SHOWN = PokeAccess::ZTrainerBars.instance_variable_get(:@shown)

  test "the bars coming in are said once, queued" do
    sensing do
      TrainerSensor.show
      TrainerSensor.update
      assert_equal [[near, false]], SpeakCapture.log
    end
  end

  test "the bars staying in say nothing more" do
    sensing do
      TrainerSensor.show
      TrainerSensor.update
      SpeakCapture.clear
      2.times { TrainerSensor.update }
      assert_nothing_spoken
    end
  end

  test "with no trainer in range nothing is said" do
    sensing do
      2.times { TrainerSensor.update }
      assert_nothing_spoken
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

  test "bars filled clear are not said, any alpha above none is" do
    { 0 => [], 1 => [[near, false]], 255 => [[near, false]] }.each do |alpha, want|
      SpeakCapture.clear
      sensing(alpha) do
        TrainerSensor.show
        TrainerSensor.update
      end
      assert_equal want, SpeakCapture.log, "alpha #{alpha}"
    end
  end

  test "a sensor with no bar to look at is said all the same" do
    sensing(nil) do
      TrainerSensor.show
      TrainerSensor.update
      assert_equal [[near, false]], SpeakCapture.log
    end
  end

  test "a sensor that cannot tell whether it is triggered is taken as out of range" do
    sensing do
      TrainerSensor.show
      TrainerSensor.singleton_class.send(:alias_method, :sensor_test_triggered, :triggered?)
      TrainerSensor.define_singleton_method(:triggered?) { raise "sensor down" }
      begin
        TrainerSensor.update
      ensure
        TrainerSensor.singleton_class.send(:alias_method, :triggered?, :sensor_test_triggered)
        TrainerSensor.singleton_class.send(:remove_method, :sensor_test_triggered)
      end
      assert_nothing_spoken
    end
  end

  private

  def near; PokeAccess::I18n.t(:trainer_near); end

  # Runs the block with the bars out, counted out as the profile loads them, and the top bar's pixel at alpha (nil:
  # no bar at all); the sensor is left out and empty after.
  def sensing(alpha = 255)
    PokeAccess::ZTrainerBars.instance_variable_set(:@shown, LOADED_SHOWN)
    TrainerSensor.hide
    TrainerSensor.instance_variable_set(:@top, alpha.nil? ? nil : bar(alpha))
    yield
  ensure
    TrainerSensor.hide
    TrainerSensor.instance_variable_set(:@top, nil)
    PokeAccess::ZTrainerBars.instance_variable_set(:@shown, LOADED_SHOWN)
  end

  # A bar sprite whose bitmap answers every pixel with the given alpha.
  def bar(alpha)
    pixel = Struct.new(:alpha).new(alpha)
    bitmap = Object.new
    bitmap.define_singleton_method(:get_pixel) { |_x, _y| pixel }
    Struct.new(:bitmap).new(bitmap)
  end
end
