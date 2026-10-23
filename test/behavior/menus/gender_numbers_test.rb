# Which gender a new-game portrait's picture name gives (Appearance.gender_for_picture): a word in the name, or its
# number as the game declares it, opalo's profile (games/opalo/picture_cues.rb) numbering them the other way round.
class GenderNumbersTest < PokeAccessTest
  PROFILE = File.join(Harness::ROOT, "games", "opalo", "picture_cues.rb")

  test "reads a portrait's gender from a word in its name, and none from a name without one" do
    { "introGirl" => :ap_girl, "introBoy" => :ap_boy, "RetratoMujer" => :ap_girl, "RetratoHombre" => :ap_boy,
      "chica_sel" => :ap_girl, "chico_sel" => :ap_boy }.each do |name, gender|
      assert_equal gender, gender_for(name), "for #{name}"
    end
    assert_nil gender_for("introEbano1"), "a name with a number but no gender word"
  end

  test "numbers the boy first when no game declares its portraits" do
    numbers = PokeAccess::Config.gender_numbers
    PokeAccess::Config.gender_numbers = {}
    { "pantallaGenero1" => :ap_boy, "pantallaGenero2" => :ap_girl, "gender2" => :ap_girl, "sexo 01" => :ap_boy }
      .each { |name, gender| assert_equal gender, gender_for(name), "for #{name}" }
  ensure
    PokeAccess::Config.gender_numbers = numbers
  end

  test "follows opalo's profile, which numbers the girl first as its selector shows, the neutral 0 neither" do
    with_opalo_profile do
      assert_equal [:ap_girl, :ap_boy], [gender_for("pantallaGenero1"), gender_for("pantallaGenero2")]
      assert_nil gender_for("pantallaGenero0"), "the neutral opening portrait"
    end
  end

  private

  def gender_for(name)
    PokeAccess::Appearance.gender_for_picture(name)
  end

  # Runs the block with opalo's profile file evaluated as the loader does, then takes back what it registers: the
  # gender numbering, the picture texts and observers, its profile name and its cache reset.
  def with_opalo_profile
    cues = PokeAccess::PictureCues
    numbers = PokeAccess::Config.gender_numbers
    texts = cues::TEXTS.dup
    handlers = cues::HANDLERS.length
    profiles = PokeAccess::Game.profiles.dup
    profile_name = PokeAccess::Game.instance_variable_get(:@profile_name)
    resets = PokeAccess::Caches.instance_variable_get(:@resets).dup
    eval(Harness.source(PROFILE), TOPLEVEL_BINDING, PROFILE)
    yield
  ensure
    PokeAccess::Config.gender_numbers = numbers
    cues::TEXTS.replace(texts)
    cues::HANDLERS.slice!(handlers..-1)
    PokeAccess::Game.profiles.replace(profiles)
    PokeAccess::Game.instance_variable_set(:@profile_name, profile_name)
    PokeAccess::Caches.instance_variable_get(:@resets).replace(resets)
  end
end
