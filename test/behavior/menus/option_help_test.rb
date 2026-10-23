# The options screen's per-option help (OptionHelp) on the gen-6 scene: @sprites["textbox"], a help box in some games
# and the dialogue frame sample in most, reaches the info key only once it has proved to be help.
class OptionHelpTest < PokeAccessTest
  # The scene's textbox, whose text the scene sets as the cursor moves.
  Box = Struct.new(:text)

  # The option window: the focused option and each option's value, kept on the window and indexed by option, as
  # these scenes keep them.
  class Options
    attr_accessor :index
    def initialize; @index = 0; @values = Hash.new(0); end
    def [](option); @values[option]; end
    def []=(option, value); @values[option] = value; end
  end

  FRAME = "Marco de dialogo 1."
  SPEED = "Velocidad del texto del juego."
  SOUND = "Activa o desactiva el sonido."

  test "the first text seen is not offered: one sample proves nothing" do
    scene = options_scene
    show(scene, SPEED, 0)
    assert_nil info
  end

  test "a text that stays the same from option to option is never offered" do
    scene = options_scene
    [0, 1, 2].each { |option| show(scene, FRAME, option) }
    assert_nil info
  end

  test "a text that changes with the focused option's value is not offered" do
    scene = options_scene
    show(scene, FRAME, 3, 0)
    show(scene, "Marco de dialogo 2.", 3, 1)
    assert_nil info
  end

  test "a new text at another option proves it is help and is offered" do
    scene = options_scene
    show(scene, SPEED, 0)
    show(scene, SOUND, 1)
    assert_equal SOUND, info
  end

  test "a new text at the same option and value is help, the first option's included" do
    [0, 2].each do |option|
      scene = options_scene
      show(scene, FRAME, option, 0)
      show(scene, "Ajusta el volumen de la musica del juego", option, 0)
      assert_equal "Ajusta el volumen de la musica del juego", info, "option #{option}"
    end
  end

  test "once proved, every text is offered, the frame sample and a value's own text included" do
    scene = options_scene
    show(scene, SPEED, 0)
    show(scene, SOUND, 1, 0)
    show(scene, FRAME, 2, 0)
    assert_equal FRAME, info, "the frame sample's text"
    show(scene, "Marco de dialogo 2.", 2, 1)
    assert_equal "Marco de dialogo 2.", info, "the text a value change brings"
  end

  test "a blank text is skipped: it is not offered and is no sample" do
    scene = options_scene
    show(scene, "  ", 0)
    show(scene, SPEED, 1)
    assert_nil info
  end

  test "a scene without a textbox offers nothing, frame after frame" do
    scene = PokemonOptionScene.new
    scene.sprites["option"] = Options.new
    PokeAccess::Info.set_info(nil, nil)
    [0, 1].each do |option|
      scene.sprites["option"].index = option
      scene.pbUpdate
    end
    assert_nil info
  end

  test "the opening and selection-change hooks this scene lacks are not taken for typos" do
    assert_equal [], PokeAccess::Hooks.missing.grep(/\APokemonOptionScene#/)
  end

  test "the help offered names the key the player bound in place of the one it paints" do
    was = [PokeAccess::Config.rebinds, PokeAccess::Config.key_hint_letters]
    PokeAccess::Config.rebinds = { :c => 0x4B }
    PokeAccess::Config.key_hint_letters = { "C" => :c }
    scene = options_scene
    show(scene, SPEED, 0)
    show(scene, "Pulsa C para restablecer los valores.", 1)
    assert_equal "Pulsa K para restablecer los valores.", info
  ensure
    PokeAccess::Config.rebinds, PokeAccess::Config.key_hint_letters = was
  end

  test "the scene's frame leaves the option window it drives free to speak" do
    scene = options_scene
    window = Window_DrawableCommand.new(["Velocidad", "Sonido"])
    scene.sprites["cmd"] = window
    def scene.refresh_option; @sprites["cmd"].update; end
    scene.pbUpdate
    SpeakCapture.clear
    window.index = 1
    scene.pbUpdate
    assert_equal [["Sonido", true]], SpeakCapture.log
  end

  private

  # A gen-6 options scene with a textbox and its option window, the info key emptied.
  def options_scene
    PokeAccess::Info.set_info(nil, nil)
    scene = PokemonOptionScene.new
    scene.sprites["textbox"] = Box.new("")
    scene.sprites["option"] = Options.new
    scene
  end

  # The scene's frame with the cursor on option, its value set when given, and text in the textbox.
  def show(scene, text, option, value = nil)
    scene.sprites["textbox"].text = text
    scene.sprites["option"].index = option
    scene.sprites["option"][option] = value unless value.nil?
    scene.pbUpdate
  end

  # What the info key says now.
  def info
    PokeAccess::Info.info_text
  end
end
