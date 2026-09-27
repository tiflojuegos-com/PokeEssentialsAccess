# Drimer's Trainer Sensor: the bars coming in is said once, their leaving is silent, and bars filled clear (Pokemon
# Z's switch 411) say nothing. The module is defined here as the game keeps it, and the profile file re-evaluated over it,
# since its wrap binds at load.
module TrainerSensor
  @triggered = false
  def self.show; @triggered = true; end
  def self.hide; @triggered = false; end
  def self.triggered?; @triggered; end
  def self.update; @frames = (@frames || 0) + 1; end
end

# Stand-ins for the top bar: a sprite whose bitmap answers one pixel with the given alpha.
module TrainerSensorSpec
  Pixel = Struct.new(:alpha)

  def self.bar(alpha)
    bmp = Object.new
    bmp.instance_variable_set(:@alpha, alpha)
    def bmp.get_pixel(_x, _y); TrainerSensorSpec::Pixel.new(@alpha); end
    Struct.new(:bitmap).new(bmp)
  end
end

begin
  verbose = $VERBOSE
  $VERBOSE = nil
  path = File.join(Harness::ROOT, "games", "pokemon_z", "trainer_sensor.rb")
  eval(File.read(path), TOPLEVEL_BINDING, path)
ensure
  $VERBOSE = verbose
end

Suite.define("trainer sensor: the bars coming in is said once; leaving, and clear bars, are silent") do
  near = PokeAccess::I18n.t(:trainer_near)
  begin
    PokeAccess::ZTrainerBars.instance_variable_set(:@shown, false)
    TrainerSensor.instance_variable_set(:@top, TrainerSensorSpec.bar(127))
    TrainerSensor.hide
    SpeakCapture.clear
    TrainerSensor.update
    silent "no trainer in range: nothing"

    TrainerSensor.show
    TrainerSensor.update
    eq "the bars come in: said once, queued", SpeakCapture.log, [[near, false]]
    TrainerSensor.update
    TrainerSensor.update
    eq "and not again while they stay", SpeakCapture.lines, [near]

    SpeakCapture.clear
    TrainerSensor.hide
    TrainerSensor.update
    silent "their leaving says nothing"
    TrainerSensor.show
    TrainerSensor.update
    eq "coming back into range says it again", SpeakCapture.lines, [near]

    TrainerSensor.hide
    TrainerSensor.update
    TrainerSensor.instance_variable_set(:@top, TrainerSensorSpec.bar(0))
    SpeakCapture.clear
    TrainerSensor.show
    TrainerSensor.update
    silent "bars filled clear are not seen, so not said"
  ensure
    TrainerSensor.hide
    PokeAccess::ZTrainerBars.instance_variable_set(:@shown, false)
  end
end
