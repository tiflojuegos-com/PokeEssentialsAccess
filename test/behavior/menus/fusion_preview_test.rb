# Infinite Fusion's fusion chooser (games/infinitefusion_common/fusion_preview.rb) over the gen-6 stubs: what counts as
# a fused species, a fusion named by its parents, and the option the cursor focuses said once per change.
fusion_preview = File.join(Harness::ROOT, "games", "infinitefusion_common", "fusion_preview.rb")
eval(Harness.source(fusion_preview), TOPLEVEL_BINDING, fusion_preview)

class FusionPreviewTest < PokeAccessTest
  Parent = Struct.new(:name)
  Fused = Struct.new(:name, :head_pokemon, :body_pokemon)
  # A Pokemon of the chooser's other screen, which holds the two to fuse rather than their fusions.
  Mon = Struct.new(:species_data)

  CHARITOISE = Fused.new("Charitoise", Parent.new("Charizard"), Parent.new("Blastoise"))
  BLASTIZARD = Fused.new("Blastizard", Parent.new("Blastoise"), Parent.new("Charizard"))

  test "takes a fused species' entry for a species, and nil or anything else for none" do
    { CHARITOISE => true, nil => false, Parent.new("Charizard") => false }.each do |entry, species|
      assert_equal species, PokeAccess::IFFusionPreview.species?(entry), "for #{entry.inspect}"
    end
  end

  test "names a fusion with the parents giving its head and its body" do
    assert_equal side_text("Charitoise", "Charizard", "Blastoise"), PokeAccess::IFFusionPreview.describe(CHARITOISE)
  end

  test "names a fusion by its parents when it has no name, and by its name alone without both parents" do
    { Fused.new(nil, Parent.new("Charizard"), Parent.new("Blastoise")) => side_text("Charizard Blastoise", "Charizard", "Blastoise"),
      Fused.new("Charitoise", Parent.new("Charizard"), nil) => "Charitoise" }.each do |fusion, said|
      assert_equal said, PokeAccess::IFFusionPreview.describe(fusion), "for #{fusion.inspect}"
    end
  end

  test "names nothing for no fusion or one with neither a name nor parents" do
    [nil, Fused.new(nil, nil, nil)].each { |fusion| assert_nil PokeAccess::IFFusionPreview.describe(fusion), "for #{fusion.inspect}" }
  end

  test "says the fusion the cursor opens on, interrupting, then nothing more while it stays" do
    scene = chooser(0)
    2.times { PokeAccess::IFFusionPreview.focus(scene) }
    assert_equal [[side_text("Charitoise", "Charizard", "Blastoise"), true]], SpeakCapture.log
  end

  test "says the right fusion when the cursor moves to it" do
    scene = chooser(0)
    PokeAccess::IFFusionPreview.focus(scene)
    scene.instance_variable_set(:@selected, 1)
    PokeAccess::IFFusionPreview.focus(scene)
    assert_equal side_text("Blastizard", "Blastoise", "Charizard"), SpeakCapture.last
  end

  test "says cancel when the cursor moves down to it" do
    scene = chooser(0)
    PokeAccess::IFFusionPreview.focus(scene)
    scene.instance_variable_set(:@selected, -1)
    PokeAccess::IFFusionPreview.focus(scene)
    assert_equal PokeAccess::I18n.t(:if_fusion_cancel), SpeakCapture.last
  end

  test "says an unknown fusion when the screen's two Pokemon make none it can look up" do
    data = Struct.new(:id_number)
    scene = World.stub_scene(:@poke1 => Mon.new(data.new(25)), :@poke2 => Mon.new(data.new(4)), :@selected => 0)
    PokeAccess::IFFusionPreview.focus(scene)
    assert_equal [[PokeAccess::I18n.t(:if_fusion_unknown), true]], SpeakCapture.log
  end

  test "says nothing on a screen with no cursor, or with no fusion and no Pokemon to fuse" do
    PokeAccess::IFFusionPreview.focus(chooser(nil))
    PokeAccess::IFFusionPreview.focus(World.stub_scene(:@selected => 0))
    assert_nothing_spoken
  end

  private

  # A fusion as said: its name, the parent giving the head and the one giving the body.
  def side_text(name, head, body)
    PokeAccess::I18n.t(:if_fusion_side, :name => name, :head => head, :body => body)
  end

  # The chooser with Charitoise on the left and Blastizard on the right, its cursor on selected.
  def chooser(selected)
    World.stub_scene(:@species_left => CHARITOISE, :@species_right => BLASTIZARD, :@selected => selected)
  end
end
