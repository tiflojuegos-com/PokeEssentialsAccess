# Insurgence's Pokedex forms page, redrawn every frame: the page is said when the form on show changes, and never while
# the form chooser is up.

# The profile's module alone (games/insurgence/dex_forms.rb): its hooks belong to the Insurgence process
# (insurgence_profile_test).
path = File.join(Harness::ROOT, "games", "insurgence", "dex_forms.rb")
eval(Harness.source(path)[/^module PokeAccess\r?\n.*?^end\r?\n/m], TOPLEVEL_BINDING, path)

class InsurgenceScreensTest < PokeAccessTest
  test "says the page once, interrupting, however often it repaints" do
    scene = form_page
    SpeakCapture.clear
    3.times { forms.update(scene) }
    assert_equal [[form_line("Macho"), true]], SpeakCapture.log
  end

  test "says the page again when another form goes on show" do
    scene = form_page
    forms.update(scene)
    scene.instance_variable_set(:@gender, 1)
    SpeakCapture.clear
    forms.update(scene)
    assert_equal [[form_line("Hembra"), true]], SpeakCapture.log
  end

  test "keeps quiet about the forms it previews while the chooser is up" do
    scene = form_page
    forms.update(scene)
    scene.instance_variable_set(:@gender, 1)
    SpeakCapture.clear
    choosing(scene) { forms.update(scene) }
    assert_nothing_spoken
  end

  test "says the form kept on show again once the chooser's close resets the page" do
    scene = form_page
    forms.update(scene)
    choosing(scene) { forms.update(scene) }
    PokeAccess::Cursor.reset(scene, :ins_dex_form)
    SpeakCapture.clear
    forms.update(scene)
    assert_equal [[form_line("Macho"), true]], SpeakCapture.log
  end

  private

  def forms
    PokeAccess::InsurgenceDexForms
  end

  # Pikachu's forms page on its male form, with the female one available.
  def form_page
    World.stub_scene(:@species => 25, :@gender => 0, :@form => 0, :@available => [["Macho", 0, 0], ["Hembra", 1, 0]])
  end

  # The page as said: the species, then the form on show.
  def form_line(form)
    "#{PokeAccess::I18n.t(:pdx_forms, :name => 'Especie25')}. #{PokeAccess::I18n.t(:dex_form, :form => form)}"
  end

  # Runs the block inside the form chooser of scene, as the core's pbChooseForm hook runs it.
  def choosing(scene, &block)
    PokeAccess::DexEntry.choose_form(scene, &block)
  end
end
