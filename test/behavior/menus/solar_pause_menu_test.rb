class SolarPauseMenuTest < PokeAccessTest
  class Scene
    attr_accessor :entries, :index, :hidden, :close
    def initialize
      @entries, @index, @hidden, @close = [:BAG, :TRAINER, :SAVE, :OPTIONS], 0, false, false
    end
  end

  module Names
    LABELS = { :BAG => "Bag", :TRAINER => "\\pn", :SAVE => "Save", :OPTIONS => "Options" }
    def self.getName(key); LABELS[key]; end
  end

  path = File.join(Harness::ROOT, "games", "solar_light_lunar_dark", "pause_menu.rb")
  profiles = PokeAccess::Game.profiles.dup
  begin
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
  ensure
    PokeAccess::Game.profiles.replace(profiles)
  end

  def with_menu
    previous = Object.const_defined?(:MenuHandlers) ? Object.send(:remove_const, :MenuHandlers) : nil
    trainer = $Trainer
    Object.const_set(:MenuHandlers, Names)
    $Trainer = Struct.new(:name).new("Alex")
    scene = Scene.new
    PokeAccess::Config.verbosity = :full
    yield scene
  ensure
    PokeAccess::SolarPauseMenu.close(scene) if scene
    Object.send(:remove_const, :MenuHandlers)
    Object.const_set(:MenuHandlers, previous) if previous
    $Trainer = trainer
  end

  test "opening reads the first available entry and its position, queued" do
    with_menu do |scene|
      PokeAccess::SolarPauseMenu.open(scene)
      assert_includes SpeakCapture.lines.first, "Bag"
      assert_match(/1.*4/, SpeakCapture.lines.first)
      assert_equal false, SpeakCapture.log.first[1]
    end
  end

  test "moving to Save interrupts once and repeated polls stay silent" do
    with_menu do |scene|
      PokeAccess::SolarPauseMenu.open(scene)
      SpeakCapture.clear
      scene.index = 2
      3.times { PokeAccess::SolarPauseMenu.poll(scene) }
      assert_equal 1, SpeakCapture.lines.length
      assert_includes SpeakCapture.lines.first, "Save"
      assert_match(/3.*4/, SpeakCapture.lines.first)
      assert_equal true, SpeakCapture.log.first[1]
    end
  end

  test "the trainer label uses the player name without mutating the game's label" do
    with_menu do |scene|
      scene.index = 1
      PokeAccess::SolarPauseMenu.open(scene)
      assert_includes SpeakCapture.lines.first, "Alex"
      assert_equal "\\pn", Names::LABELS[:TRAINER]
    end
  end

  test "hidden and closing menus do not speak" do
    with_menu do |scene|
      PokeAccess::SolarPauseMenu.open(scene)
      SpeakCapture.clear
      scene.index = 2
      scene.hidden = true
      PokeAccess::SolarPauseMenu.poll(scene)
      scene.hidden, scene.close = false, true
      PokeAccess::SolarPauseMenu.poll(scene)
      assert_nothing_spoken
    end
  end

  test "a wrapped or uninitialized selection does not read an invalid entry" do
    with_menu do |scene|
      scene.index = -1
      PokeAccess::SolarPauseMenu.open(scene)
      scene.index = scene.entries.length
      PokeAccess::SolarPauseMenu.poll(scene)
      scene.entries = nil
      PokeAccess::SolarPauseMenu.poll(scene)
      assert_nothing_spoken
    end
  end

  test "returning from a submenu repeats its entry and a closed menu stays silent" do
    with_menu do |scene|
      PokeAccess::SolarPauseMenu.open(scene)
      SpeakCapture.clear
      PokeAccess::SolarPauseMenu.returned
      assert_includes SpeakCapture.lines.first, "Bag"
      PokeAccess::SolarPauseMenu.close(scene)
      SpeakCapture.clear
      PokeAccess::SolarPauseMenu.returned
      assert_nothing_spoken
    end
  end
end
