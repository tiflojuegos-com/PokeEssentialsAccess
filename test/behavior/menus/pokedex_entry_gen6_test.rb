# The gen-6 Pokedex entry scenes: the info page read as painted (withheld values as unknown, an owned species' mark
# and type icons in words), composed from its dummy pokemon when unpainted, with its page key when browsed; and the
# form page's form after the species and the page's name, kept for the info key, its chooser's cancel said.
class PokedexEntryGen6Test < PokeAccessTest
  Dummy = Struct.new(:species, :kind, :height, :weight, :dexEntry, :type1, :type2)

  # The reader's file, whose form page hooks a test binds to a stand-in scene.
  ENTRY = File.join(Harness::ROOT, "core", "menus", "pokedex_entry.rb")

  test "reads a species only seen as painted, its withheld values as unknown" do
    owning { page.pbChangeToDexEntry(25) }
    assert_equal [["007 Especie25, Pokémon #{unknown}, Alt., #{unknown}, Peso, #{unknown}", true]], SpeakCapture.log
  end

  test "reads an owned species with its owned mark after the header and its types after the category" do
    owning(25) { page.pbChangeToDexEntry(25) }
    assert_equal [["007 Especie25, #{caught}, Pokémon Ratón, #{type_13}, Alt., 0.4 m, Peso, 6.0 kg, " \
                   "Almacena electricidad.", true]], SpeakCapture.log
  end

  test "keeps the header and the owned mark at brief, adds the category and types at medium, the rest at full" do
    said = owning(25) do
      vb_levels do
        SpeakCapture.clear
        page.pbChangeToDexEntry(25)
        SpeakCapture.last
      end
    end
    assert_equal ["007 Especie25, #{caught}", "007 Especie25, #{caught}, Pokémon Ratón, #{type_13}",
                  "007 Especie25, #{caught}, Pokémon Ratón, #{type_13}, Alt., 0.4 m, Peso, 6.0 kg, " \
                  "Almacena electricidad."], said
  end

  test "reads a page with no dummy pokemon from the species it shows, an owned one's types from the dex data" do
    bare = PokemonPokedexScene.new
    owning { bare.pbChangeToDexEntry(25) }
    owning(25) { bare.pbChangeToDexEntry(25) }
    assert_equal [["025 Especie25, Pokémon #{unknown}, Alt., #{unknown}, Peso, #{unknown}", true],
                  ["025 Especie25, #{caught}, Pokémon msg25, #{type_13}, Alt., 0.7 m, Peso, 6.9 kg, msg25", true]],
                 SpeakCapture.log
  end

  test "composes an owned species' entry from its dummy pokemon when the page paints nothing" do
    owning(25) { PokeAccess::DexEntry.gen6_info(page, nil, 25) }
    assert_equal [["Especie25. #{t(:dex_category, :cat => 'Ratón')}. #{t(:dex_height, :h => '0,4', :n => 0.4)}. " \
                   "#{t(:dex_weight, :w => '6,0', :n => 6.0)}. Almacena electricidad.", true]], SpeakCapture.log
  end

  test "composes a dummy pokemon's missing height and weight as zero" do
    blank = Struct.new(:species, :kind).new(25, "Ratón")
    owning(25) { PokeAccess::DexEntry.gen6_info(page(blank), nil, 25) }
    assert_equal ["Especie25. #{t(:dex_category, :cat => 'Ratón')}. #{t(:dex_height, :h => '0,0', :n => 0.0)}. " \
                  "#{t(:dex_weight, :w => '0,0', :n => 0.0)}"], SpeakCapture.lines
  end

  test "composes a species only seen as its name and not caught, one owned with no dummy pokemon as its name" do
    bare = PokemonPokedexScene.new
    owning { PokeAccess::DexEntry.gen6_info(bare, nil, 25) }
    owning(25) { PokeAccess::DexEntry.gen6_info(bare, nil, 25) }
    assert_equal ["Especie25. #{t(:pdx_not_caught)}", "Especie25"], SpeakCapture.lines
  end

  test "says nothing for a page with neither a dummy pokemon nor a species" do
    owning(25) { PokeAccess::DexEntry.gen6_info(PokemonPokedexScene.new, [], nil) }
    assert_nothing_spoken
  end

  test "puts the type names right after a type label the page paints, both from medium" do
    rows = ["001  Uno", "Pokémon Semilla", "Tipo", "Alt.  0.7 m"]
    said = vb_levels { PokeAccess::DexEntry.painted_entry(rows, true, ["Planta", "Veneno"]) }
    assert_equal ["001 Uno, #{caught}", "001 Uno, #{caught}, Pokémon Semilla, Tipo, Planta Veneno",
                  "001 Uno, #{caught}, Pokémon Semilla, Tipo, Planta Veneno, Alt. 0.7 m"], said
  end

  test "takes the type label in each language the builds paint it in" do
    %w[Tipo Tipos Type TYPES Typ Typen].each do |label|
      rows = ["001  Uno", "Pokémon Semilla", label, "Alt.  0.7 m"]
      assert_equal "001 Uno, #{caught}, Pokémon Semilla, #{label}, Planta, Alt. 0.7 m",
                   PokeAccess::DexEntry.painted_entry(rows, true, ["Planta"]), "for #{label.inspect}"
    end
  end

  test "names the types after the category when no painted row is a type label alone" do
    entry = "Tipo de semilla que crece al sol."
    said = PokeAccess::DexEntry.painted_entry(["001  Uno", "Pokémon Semilla", entry], true, ["Planta"])
    assert_equal "001 Uno, #{caught}, Pokémon Semilla, #{t(:pdx_type, :t => 'Planta')}, #{entry}", said
  end

  test "says a run of question marks as unknown, its unit with it, and leaves a lone question mark" do
    { "????.? m" => unknown, "????.? kg" => unknown, "????.? lbs." => unknown,
      "Pokémon ?????" => "Pokémon #{unknown}", "No. ?" => "No. ?" }.each do |painted, said|
      assert_equal said, PokeAccess::DexEntry.unknown_marks(painted), "for #{painted.inspect}"
    end
  end

  test "says a withheld height in feet and inches as unknown, its inch mark with it" do
    rows = ["025  Especie25", "Pokémon ?????", "Alt.", "???'??\"", "Peso", "????.? lbs."]
    assert_equal "025 Especie25, Pokémon #{unknown}, Alt., #{unknown}, Peso, #{unknown}",
                 PokeAccess::DexEntry.painted_entry(rows, false, [])
  end

  test "reads an owned species' types on a page with no dummy pokemon as the form its Pokedex last showed" do
    shown = Object.new
    def shown.dex_shown_types(_species); ["Fuego", "Volador"]; end
    Harness.with_provider(shown) { owning(25) { PokemonPokedexScene.new.pbChangeToDexEntry(25) } }
    assert_equal [["025 Especie25, #{caught}, Pokémon msg25, #{t(:pdx_type, :t => 'Fuego Volador')}, Alt., 0.7 m, " \
                   "Peso, 6.9 kg, msg25", true]], SpeakCapture.log
  end

  test "says the form the form page shows after its species' name and the page's" do
    PokeAccess::DexEntry.gen6_form(form_page(1, 0))
    assert_equal [["#{forms_head}. #{t(:dex_form, :form => 'Hembra')}", true]], SpeakCapture.log
  end

  test "says the form alone on a form page that keeps no species" do
    PokeAccess::DexEntry.gen6_form(form_page(1, 1, nil))
    assert_equal [t(:dex_form, :form => "Hembra de Alola")], SpeakCapture.lines
  end

  test "says the species and the page's name for a gender and form the form page does not list" do
    PokeAccess::DexEntry.gen6_form(form_page(0, 1))
    assert_equal [[forms_head, true]], SpeakCapture.log
  end

  test "keeps the form page's line for the info key and Ctrl+T, not the info page's" do
    PokeAccess::Info.set_info(:text, "007 Especie25, capturado", "007 Especie25, capturado")
    PokeAccess::DexEntry.gen6_form(form_page(1, 0))
    line = "#{forms_head}. #{t(:dex_form, :form => 'Hembra')}"
    assert_equal [line, line], [PokeAccess::Info.info_text, PokeAccess::Info.row_text]
  end

  test "says a form named by marks alone by the mark's name, on the page and in its chooser" do
    { "?????" => t(:unown_question), "!!!!!" => t(:unown_exclaim) }.each do |painted, word|
      SpeakCapture.clear
      PokeAccess::DexEntry.gen6_form(World.stub_scene(:@species => 201, :@gender => 0, :@form => 26,
                                                      :@available => [[painted, 0, 26]]))
      row = choosing_form { PokeAccess::Menus.unknown_row(painted) }
      assert_equal [["#{t(:pdx_forms, :name => 'Especie201')}. #{t(:dex_form, :form => word)}", true], word],
                   [SpeakCapture.log[0], row], "for #{painted}"
    end
    assert_equal t(:pdx_unknown_short), PokeAccess::Menus.unknown_row("?????"), "outside the chooser"
  end

  test "says nothing on the form page while its form chooser is up" do
    page = form_page(1, 0)
    choosing_form(page) { PokeAccess::DexEntry.gen6_form(page) }
    assert_nothing_spoken
  end

  test "keeps the form page quiet while its chooser redraws it, then says the form picked as the page redraws" do
    rets = with_form_scene do |k|
      scene = k.new
      [scene.pbChooseForm, scene.pbRefresh]
    end
    assert_equal [[:chosen, :refreshed], [["#{forms_head}. #{t(:dex_form, :form => 'Hembra')}", true]]],
                 [rets, SpeakCapture.log]
  end

  test "says the form a chooser cancelled with B puts back, and nothing more for one picked" do
    said = [true, false].map do |cancel|
      SpeakCapture.clear
      with_form_scene(cancel) { |k| cancel ? pressing_b { k.new.pbChooseForm } : k.new.pbChooseForm }
      SpeakCapture.log.dup
    end
    assert_equal [[["#{forms_head}. #{t(:dex_form, :form => 'Macho')}", true]], []], said
  end

  test "browsing the entries, the info page adds its page key on arriving, not on a species change" do
    entry = "007 Especie25, #{caught}, Pokémon Ratón, #{type_13}, Alt., 0.4 m, Peso, 6.0 kg, Almacena electricidad."
    owning(25) do
      PokeAccess::DexEntry.browse do
        page.pbChangeToDexEntry(25)
        page.pbChangeToDexEntry(25)
        PokeAccess::DexEntry.gen6_area(World.stub_scene, ["Kanto"], 0)
        page.pbChangeToDexEntry(25)
      end
      page.pbChangeToDexEntry(25)
    end
    hinted = "#{entry} #{t(:pdx_info_hint)}"
    assert_equal [hinted, entry, "Kanto", hinted, entry], SpeakCapture.lines
  end

  test "browsing the entries, the info page's key is said from medium" do
    said = owning(25) do
      vb_levels do
        SpeakCapture.clear
        PokeAccess::DexEntry.browse { page.pbChangeToDexEntry(25) }
        SpeakCapture.last
      end
    end
    assert_equal ["007 Especie25, #{caught}", "007 Especie25, #{caught}, Pokémon Ratón, #{type_13}. #{t(:pdx_info_hint)}"],
                 said[0, 2]
  end

  private

  # Runs the block with a stand-in for the v16-v17 form page (its chooser redraws the page as it moves to the female
  # form, and back to the male one when cancelled) bound by the form page's two hooks, as boot binds them in a game
  # that has the scene; yields its class. The game's own class and hooks, if any, are put back afterwards.
  def with_form_scene(cancel = false)
    src = Harness.source(ENTRY)
    from = src.index(/^PokeAccess::Hooks\.after_hook\("PokedexFormScene"/)
    hooks = src[from..-1][/\A.*?(?=^PokeAccess::Hooks\.before_hook)/m]
    chains = PokeAccess::Hooks.instance_variable_get(:@chains)
    keys = %w[pbRefresh pbChooseForm].map { |m| "PokedexFormScene##{m}" }
    kept = keys.map { |key| [key, chains.delete(key)] }
    had = Object.const_defined?(:PokedexFormScene, false) ? Object.send(:remove_const, :PokedexFormScene) : nil
    Object.const_set(:PokedexFormScene, form_scene_class(cancel))
    eval(hooks, TOPLEVEL_BINDING, "pokedex_entry.rb form page hooks", src[0, from].count("\n") + 1)
    yield PokedexFormScene
  ensure
    if kept
      Object.send(:remove_const, :PokedexFormScene) if Object.const_defined?(:PokedexFormScene, false)
      Object.const_set(:PokedexFormScene, had) if had
      kept.each { |key, chain| chain ? chains[key] = chain : chains.delete(key) }
    end
  end

  # The v16-v17 form page on species 25, showing its male form, whose chooser moves to the female one and redraws
  # the page on the way; cancelled, it puts the male one back and redraws the page again, as B does.
  def form_scene_class(cancel)
    Class.new do
      define_method(:cancel?) { cancel }

      def initialize
        @species = 25
        @gender = 0
        @form = 0
        @available = [["Macho", 0, 0], ["Hembra", 1, 0]]
      end

      def pbRefresh; :refreshed; end

      def pbChooseForm
        @gender = 1
        pbRefresh
        if cancel?
          @gender = 0
          pbRefresh
        end
        :chosen
      end
    end
  end

  # The form page's name for species 25, which heads what the page says.
  def forms_head
    t(:pdx_forms, :name => "Especie25")
  end

  # Runs the block with B just triggered, as a chooser's cancel leaves it; the stub's answer is put back afterwards.
  def pressing_b
    orig = Input.method(:trigger?)
    Input.define_singleton_method(:trigger?) { |*a| a[0] == Input::B }
    yield
  ensure
    Input.define_singleton_method(:trigger?, orig) if orig
  end

  # The form page on species (nil: none kept) showing the given gender and form, of the three it lists: a male, a
  # female and an Alolan female.
  def form_page(gender, form, species = 25)
    World.stub_scene(:@species => species, :@gender => gender, :@form => form,
                     :@available => [["Macho", 0, 0], ["Hembra", 1, 0], ["Hembra de Alola", 1, 1]])
  end

  # Runs the block inside the form chooser of scene, as the page's pbChooseForm hook runs it.
  def choosing_form(scene = nil, &block)
    PokeAccess::DexEntry.choose_form(scene, &block)
  end

  # The entry page, its header numbered 7 and its dummy pokemon a Pikachu (species 25, of type 13 alone).
  def page(dummy = Dummy.new(25, "Ratón", 4, 60, "Almacena electricidad.", 13, 13))
    scene = PokemonPokedexScene.new
    scene.dummypokemon = dummy
    scene.instance_variable_set(:@shown_number, 7)
    scene
  end

  # The block's value with the player owning the given species, $Trainer put back afterwards.
  def owning(*species)
    had = $Trainer
    owned = []
    species.each { |sp| owned[sp] = true }
    $Trainer = had.dup
    $Trainer.define_singleton_method(:owned) { owned }
    yield
  ensure
    $Trainer = had
  end

  def unknown
    t(:pdx_unknown_short)
  end

  def caught
    t(:dex_caught)
  end

  # The type line of species 25, whose dex data gives it type 13 alone ("Tipo13" in the stubs' type names).
  def type_13
    t(:pdx_type, :t => "Tipo13")
  end

  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end
end
