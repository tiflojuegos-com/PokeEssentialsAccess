# Pokemon Z's sheet items (games/pokemon_z/picture_cues.rb): the controls guide and the two Nuzlocke diplomas, used
# from the bag, say their sheet as the running build paints it, on every use; the intro's controls picture, the same.

# Pokemon Z's bag dispatch: 1 for the three sheet items, whose handler shows the sheet and waits for Accept, and 0 for
# an item with no handler; it notes what had been said when it ran. It bears the game's name ItemHandlers only while a
# test runs, as other tests give that name to stand-ins of their own.
module ZSheetHandlers
  class << self
    # The lines said before the game's handler ran, on the last use.
    attr_accessor :heard
  end

  def self.triggerUseFromBag(item)
    self.heard = SpeakCapture.lines.dup
    [568, 944, 945].include?(item) ? 1 : 0
  end
end

class ZItemSheetsTest < PokeAccessTest
  PROFILE = File.join(Harness::ROOT, "games", "pokemon_z", "picture_cues.rb")
  ITEMS = { :CONTROLES => 568, :DIPLOMANUZ1 => 944, :DIPLOMANUZ2 => 945 }.freeze
  CONTROLS = "Controles. Flechas: Movimiento. X: Interactuar / Menú. C: Interactuar / Correr. Z: Atrás. Q: Turbo."
  NUZLOCKE = "Este diploma certifica que has completado un nuzlocke de Pokémon Z. ¡Enhorabuena! EricLostie. " \
             "El diseño gráfico es mi pasión..."
  HEROIC = "Este diploma certifica que has completado un nuzlocke de Pokémon Z en dificultad heroica. ¡Enhorabuena! " \
           "EricLostie. El diseño gráfico es mi pasión..."
  CONTROLS_EN = "Controls. Arrows: Movement. X: Interact / Menu. C: Interact / Run. Z: Back. Alt: Turbo."
  CONTROLS_FR = "Note du traducteur : Jouez à la manette, c'est bien mieux ! Contrôles. Flèches : Se déplacer. " \
                "X : Interagir / Courir. C : Interagir / Menu. Z : Retour. Alt : Accélérer le jeu."
  NUZLOCKE_FR = "Félicitations pour avoir fini Pokémon Z en Nuzlock ! graphic design is my passion. EricLostie."
  HEROIC_FR = "Félicitations pour avoir fini Pokémon Z en Nuzlock héroïque ! graphic design is my passion. EricLostie."

  test "each sheet item used from the bag says its sheet, cutting in" do
    with_sheets do
      { 568 => CONTROLS, 944 => NUZLOCKE, 945 => HEROIC }.each do |item, sheet|
        SpeakCapture.clear
        ItemHandlers.triggerUseFromBag(item)
        assert_equal [[sheet, true]], SpeakCapture.log, "item #{item}"
      end
    end
  end

  test "says the sheet as it comes up, before the game waits for Accept" do
    with_sheets { ItemHandlers.triggerUseFromBag(568) }
    assert_equal [CONTROLS], ZSheetHandlers.heard
  end

  test "used again, says the sheet again" do
    with_sheets { 2.times { ItemHandlers.triggerUseFromBag(944) } }
    assert_equal [[NUZLOCKE, true], [NUZLOCKE, true]], SpeakCapture.log
  end

  test "the game's handler still answers what it answered" do
    with_sheets do
      { 568 => 1, 945 => 1, 1 => 0 }.each do |item, answer|
        assert_equal answer, ItemHandlers.triggerUseFromBag(item), "item #{item}"
      end
    end
  end

  test "any other item passes in silence" do
    with_sheets do
      [PBItems::POTION, 946, nil].each do |item|
        ItemHandlers.triggerUseFromBag(item)
        assert_nothing_spoken item.inspect
      end
    end
  end

  test "in a build lacking some sheet items, those it has still say their sheet" do
    with_sheets(:DIPLOMANUZ2 => 945) do
      ItemHandlers.triggerUseFromBag(568)
      assert_nothing_spoken "the controls guide is no item of that build"
      ItemHandlers.triggerUseFromBag(945)
      assert_equal [[HEROIC, true]], SpeakCapture.log
    end
  end

  test "each language build says the sheets as it paints them" do
    {
      "English" => [CONTROLS_EN, NUZLOCKE, HEROIC],
      "Français" => [CONTROLS_FR, NUZLOCKE_FR, HEROIC_FR]
    }.each do |language, sheets|
      in_build(language) { with_sheets { ITEMS.each_value { |item| ItemHandlers.triggerUseFromBag(item) } } }
      assert_equal sheets, SpeakCapture.lines, "the #{language} build (the English one paints the diplomas in Spanish)"
    end
  end

  test "the intro's first picture says the controls sheet" do
    PokeAccess::PictureCues.reset_last
    Game_Picture.new.show("helpbg")
    assert_equal [[CONTROLS, true]], SpeakCapture.log
  ensure
    PokeAccess::PictureCues.reset_last
  end

  private

  # Runs the block with the bag's dispatch standing in for the game's ItemHandlers, the given sheet items in the item
  # table and the profile's hooks registered over them; the hooks and the stand-ins are taken back after.
  def with_sheets(items = ITEMS)
    added = items.keys.reject { |k| PBItems.const_defined?(k, false) }
    added.each { |k| PBItems.const_set(k, items[k]) }
    had = Object.const_defined?(:ItemHandlers, false) ? Object.send(:remove_const, :ItemHandlers) : nil
    Object.const_set(:ItemHandlers, ZSheetHandlers)
    sizes = registry_sizes
    register_profile(sizes)
    SpeakCapture.clear
    yield
  ensure
    trim_registries(sizes) if sizes
    Object.send(:remove_const, :ItemHandlers) if Object.const_defined?(:ItemHandlers, false)
    Object.const_set(:ItemHandlers, had) if had
    (added || []).each { |k| PBItems.send(:remove_const, k) if PBItems.const_defined?(k, false) }
    PokeAccess::PictureCues.reset_last
  end

  # Registers the profile's hooks over the stand-in: the first time by evaluating the profile once more, so its hook
  # binds to the stand-in; later by adding back what that evaluation registered, as coverage counts a file's lines
  # from its last evaluation alone.
  def register_profile(sizes)
    if self.class.registered
      add_back(self.class.registered)
    else
      quietly { eval(Harness.source(PROFILE), TOPLEVEL_BINDING, PROFILE) }
      self.class.registered = gained_since(sizes)
    end
  end

  # The registries a profile's evaluation adds to, each a table of lists: function hook bodies, picture observers and
  # middlewares.
  def registries
    [PokeAccess::Hooks.fn_bodies, { :observers => PokeAccess::PictureCues::HANDLERS },
     PokeAccess::Hooks.instance_variable_get(:@chains)]
  end

  # The length of each list in the registries.
  def registry_sizes
    registries.map { |table| Hash[table.map { |key, list| [key, list.length] }] }
  end

  # Cuts each list in the registries back to the length registry_sizes took.
  def trim_registries(sizes)
    registries.zip(sizes).each { |table, was| table.each { |key, list| list.slice!((was[key] || 0)..-1) } }
  end

  # What each list in the registries gained since registry_sizes took sizes, the lists that gained nothing left out.
  def gained_since(sizes)
    registries.zip(sizes).map do |table, was|
      Hash[table.map { |key, list| [key, list[(was[key] || 0)..-1]] }.reject { |_key, more| more.empty? }]
    end
  end

  # Adds back to the registries what gained_since found.
  def add_back(gained)
    registries.zip(gained).each { |table, more| more.each { |key, list| table[key].concat(list) } }
  end

  # Runs the block with Ruby's warnings off, as the profile's second evaluation sets its constants again.
  def quietly
    verbose = $VERBOSE
    $VERBOSE = nil
    yield
  ensure
    $VERBOSE = verbose
  end

  # Runs the block in a build whose LANGUAGES table declares the one language name with its message file shipped, as
  # Pokemon Z's English and French builds do; the table put back after.
  def in_build(name)
    had = Object.const_defined?(:LANGUAGES, false) ? Object.send(:remove_const, :LANGUAGES) : nil
    Object.const_set(:LANGUAGES, [[name, "lang.dat"]])
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "Data"))
      File.write(File.join(dir, "Data", "lang.dat"), "x")
      Dir.chdir(dir) { yield }
    end
  ensure
    Object.send(:remove_const, :LANGUAGES) if Object.const_defined?(:LANGUAGES, false)
    Object.const_set(:LANGUAGES, had) if had
  end

  class << self
    # What the profile's one evaluation registered over the stand-in, kept for the tests after it (register_profile).
    attr_accessor :registered
  end
end
