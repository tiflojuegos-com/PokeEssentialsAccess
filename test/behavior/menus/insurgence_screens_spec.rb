# Insurgence's own screens (games/insurgence): the Pokedex forms page, redrawn every frame. The profile's modules alone
# are loaded: their hooks belong to the Insurgence process (insurgence_profile_spec).
module InsurgenceScreensSpec
  # Evaluates the module block of one of the profile's files, as the harness loads every file.
  def self.load_module(file)
    path = File.join(Harness::ROOT, "games", "insurgence", file)
    eval(File.read(path)[/^module PokeAccess\r?\n.*?^end\r?\n/m], TOPLEVEL_BINDING, path)
  end
end

InsurgenceScreensSpec.load_module("dex_forms.rb") unless defined?(PokeAccess::InsurgenceDexForms)

Suite.define("insurgence dex forms: said when the form on show changes, not on every repaint") do
  f = PokeAccess::InsurgenceDexForms
  scene = World.stub_scene(:@species => 25, :@gender => 0, :@form => 0,
                           :@available => [["Macho", 0, 0], ["Hembra", 1, 0]])
  f.update(scene)
  f.update(scene)
  eq "the page once, species and form", SpeakCapture.lines, ["Especie25. #{PokeAccess::I18n.t(:dex_form, :form => 'Macho')}"]
  SpeakCapture.clear
  scene.instance_variable_set(:@gender, 1)
  f.update(scene)
  eq "a new form on show is said", SpeakCapture.lines, ["Especie25. #{PokeAccess::I18n.t(:dex_form, :form => 'Hembra')}"]
  SpeakCapture.clear
  PokeAccess::DexEntry.choosing_form!(true)
  begin
    scene.instance_variable_set(:@gender, 0)
    f.update(scene)
    silent "while the chooser is up its previews stay quiet (the chooser's window is read)"
  ensure
    PokeAccess::DexEntry.choosing_form!(false)
  end
  PokeAccess::Cursor.reset(scene, :ins_dex_form)
  f.update(scene)
  eq "closing the chooser says the page again", SpeakCapture.lines, ["Especie25. #{PokeAccess::I18n.t(:dex_form, :form => 'Macho')}"]
end
