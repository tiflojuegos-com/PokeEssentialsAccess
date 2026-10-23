# Armonia's own scripts read through its profile (games/armonia): the follower Bezier's follow script puts behind the
# player, the pictures and the video with no text to capture, and the remap menu's names for the follower's keys.

# The follow script's key for hiding or showing the follower (Q).
FOLLOW_KEY_TOGGLE = Input::L unless defined?(FOLLOW_KEY_TOGGLE)

# changeFollowingSprite as the follow script has it: with anim, A and D only queue the turn; without it, the party
# turns once and on past fainted members, all the way round when every one is fainted.
def changeFollowingSprite(direction = 0, anim = false)
  return :queued if anim && (direction == 1 || direction == -1)
  party = $Trainer.party
  return :redrawn if direction == 0 || party.size < 2
  party.size.times do
    direction == 1 ? party.push(party.delete_at(0)) : party.insert(0, party.pop)
    break if party[0].hp > 0
  end
  :turned
end unless Object.private_method_defined?(:changeFollowingSprite)

# toggleFollowingPokemon: nothing while the lead is fainted, else the follower hidden or shown.
def toggleFollowingPokemon(_anim = true)
  return if $Trainer.party[0].hp <= 0
  $Follow_Hidden = !$Follow_Hidden
end unless Object.private_method_defined?(:toggleFollowingPokemon)

# playVideo: its frames, drawn with no sound.
def playVideo(name)
  PokeAccess.speak("frames #{name}", false)
end unless Object.private_method_defined?(:playVideo)

class ArmoniaProfileTest < PokeAccessTest
  # What evaluating an Armonia profile file registers (the bodies on the given functions, the frame pollers), evaluated
  # once as the loader does and taken back out at once, for a test to put in place (with_profile).
  def self.registrations(file, functions)
    keys = functions.map { |f| %w[before after around].map { |w| "#{f}|#{w}" } }.flatten
    bodies = PokeAccess::Hooks.fn_bodies
    saved = keys.map { |k| [k, bodies.delete(k)] }
    pollers = PokeAccess::Frame.instance_variable_get(:@pollers)
    snap = pollers.dup
    profiles = PokeAccess::Game.profiles.dup
    path = File.join(Harness::ROOT, "games", "armonia", file)
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    { :bodies => keys.map { |k| [k, bodies[k]] }.select { |_k, list| list }, :pollers => pollers[snap.length..-1] }
  ensure
    saved.each { |k, list| list ? bodies[k] = list : bodies.delete(k) }
    pollers.replace(snap)
    PokeAccess::Game.profiles.replace(profiles)
    PokeAccess::Game.instance_variable_set(:@profile_name, nil)
  end
  private_class_method :registrations

  FOLLOWER = registrations("follower.rb", %w[changeFollowingSprite toggleFollowingPokemon])
  CUTSCENES = registrations("cutscenes.rb", %w[playVideo])

  test "says nothing as D or A queues the party's turn" do
    turns = following(party_of("Hojarí", "Flamiwel", "Fruti")) do
      [changeFollowingSprite(1, true), changeFollowingSprite(-1, true)]
    end
    assert_equal [:queued, :queued], turns
    assert_nothing_spoken
  end

  test "says who leads after the turn D or A asked for, interrupting" do
    { 1 => "Flamiwel", -1 => "Fruti" }.each do |direction, lead|
      SpeakCapture.clear
      following(party_of("Hojarí", "Flamiwel", "Fruti")) do
        changeFollowingSprite(direction, true)
        changeFollowingSprite(direction, false)
      end
      assert_equal [[lead_line(lead), true]], SpeakCapture.log, "direction #{direction}"
    end
  end

  test "says the lead a turn nobody asked for puts in front, queued" do
    following(party_of("Princine:0", "Hojarí")) { changeFollowingSprite(1) }
    assert_equal [[lead_line("Hojarí"), false]], SpeakCapture.log
  end

  test "interrupts only for the one turn that was asked for" do
    following(party_of("Hojarí", "Flamiwel", "Fruti")) do
      changeFollowingSprite(1, true)
      changeFollowingSprite(1, false)
      changeFollowingSprite(1, false)
    end
    assert_equal [[lead_line("Flamiwel"), true], [lead_line("Fruti"), false]], SpeakCapture.log
  end

  test "says the healthy Pokemon a turn reaches past a fainted one" do
    following(party_of("Hojarí", "Flamiwel", "Princine:0")) do
      2.times do
        changeFollowingSprite(1, true)
        changeFollowingSprite(1, false)
      end
    end
    assert_equal [lead_line("Flamiwel"), lead_line("Hojarí")], SpeakCapture.lines
  end

  test "says nothing when the turn goes all the way round to the same lead" do
    following(party_of("Princine:0", "Bufflint:0")) { changeFollowingSprite(1) }
    assert_nothing_spoken
  end

  test "says nothing for a redraw with no turn" do
    ret = following(party_of("Hojarí", "Flamiwel")) { changeFollowingSprite }
    assert_equal :redrawn, ret
    assert_nothing_spoken
  end

  test "says nothing for a new lead with no name, or a blank one" do
    [nil, ""].each do |name|
      following([Poke.build(:name => "Hojarí"), Poke.build(:name => name)]) { changeFollowingSprite(1) }
    end
    assert_nothing_spoken
  end

  test "says the follower hidden when Q hides it, and shown when Q shows it again" do
    following(party_of("Hojarí")) { 2.times { pressing(FOLLOW_KEY_TOGGLE) { toggleFollowingPokemon } } }
    assert_equal [[t(:arm_follow_hidden), true], [t(:arm_follow_shown), true]], SpeakCapture.log
  end

  test "says nothing for a toggle no key asked for, as an event's" do
    hidden = following(party_of("Hojarí")) do
      toggleFollowingPokemon
      $Follow_Hidden
    end
    assert_equal true, hidden, "the toggle itself still runs"
    assert_nothing_spoken
  end

  test "says nothing when Q finds a fainted lead or an egg, as the toggle does nothing for them" do
    egg = Poke.build(:name => "Huevo")
    def egg.isEgg?; true; end
    [party_of("Hojarí:0"), [egg]].each do |party|
      following(party) { pressing(FOLLOW_KEY_TOGGLE) { toggleFollowingPokemon } }
    end
    assert_nothing_spoken
  end

  test "says the toggle for a lead on its last hit point" do
    following(party_of("Hojarí:1")) { pressing(FOLLOW_KEY_TOGGLE) { toggleFollowingPokemon } }
    assert_equal [t(:arm_follow_hidden)], SpeakCapture.lines
  end

  test "says nothing for a toggle where the follow script defines no toggle key" do
    key = Object.send(:remove_const, :FOLLOW_KEY_TOGGLE)
    following(party_of("Hojarí")) { pressing(key) { toggleFollowingPokemon } }
    assert_nothing_spoken
  ensure
    Object.const_set(:FOLLOW_KEY_TOGGLE, key)
  end

  test "says the two pictures before the title once, queued, in the order they show" do
    intro(["intro1", "intro2"]) { 2.times { PokeAccess::Frame.run_pollers } }
    assert_equal [[t(:arm_intro_fans), false], [t(:arm_intro_studio), false]], SpeakCapture.log
  end

  test "says nothing once the title is up over the pictures" do
    intro(["intro1", "intro2"], true) { PokeAccess::Frame.run_pollers }
    assert_nothing_spoken
  end

  test "passes over a picture it has no transcription for" do
    intro(["logo", "intro2"]) { PokeAccess::Frame.run_pollers }
    assert_equal [t(:arm_intro_studio)], SpeakCapture.lines
  end

  test "says no pictures while the scene is not the intro, whatever pictures it holds" do
    intro(["intro1", "intro2"]) do
      $scene = Scene_Map.new
      $scene.instance_variable_set(:@pics, ["intro1", "intro2"])
      PokeAccess::Frame.run_pollers
    end
    assert_nothing_spoken
  end

  test "says where the story's video starts and where it ends, around its frames, queued" do
    with_profile(CUTSCENES) { playVideo("animbeta") }
    assert_equal [[t(:arm_video_start), false], ["frames animbeta", false], [t(:arm_video_end), false]],
                 SpeakCapture.log
  end

  test "names X, Z and L in the remap menu by what they also do on the map" do
    button_labels
    assert_equal [t(:arm_btn_x), t(:arm_btn_z), t(:arm_btn_l)], [:x, :z, :l].map { |b| PokeAccess::Remap.label(b) }
  end

  test "keeps the core's own name for L in L's label" do
    assert_equal true, t(:arm_btn_l).start_with?(t(:btn_l))
  end

  private

  # The mod's line for key in the running language.
  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # The follow script's line for a new lead.
  def lead_line(name)
    t(:arm_follow_lead, :name => name)
  end

  # Pokemon named as given, "name:0" for a fainted one.
  def party_of(*names)
    names.map do |entry|
      name, hp = entry.split(":")
      Poke.build(:name => name, :hp => (hp || 40).to_i)
    end
  end

  # Runs the block with the follower's registrations in place and a trainer whose party is party, the follower
  # shown; answers the block's value.
  def following(party)
    trainer = Object.new
    trainer.define_singleton_method(:party) { party }
    saved = [$Trainer, $Follow_Hidden]
    $Trainer = trainer
    $Follow_Hidden = false
    with_profile(FOLLOWER) { yield }
  ensure
    $Trainer, $Follow_Hidden = saved
  end

  # Runs the block with an intro scene showing these pictures, the title up or not, as $scene and the cutscenes'
  # registrations in place.
  def intro(pictures, titled = false)
    made = !Object.const_defined?(:Scene_Intro)
    Object.const_set(:Scene_Intro, Class.new) if made
    saved = $scene
    $scene = Scene_Intro.new
    $scene.instance_variable_set(:@pics, pictures)
    $scene.instance_variable_set(:@screen, Object.new) if titled
    with_profile(CUTSCENES) { yield }
  ensure
    $scene = saved
    Object.send(:remove_const, :Scene_Intro) if made
  end

  # Runs the block with Input answering true for the given buttons only.
  def pressing(*keys)
    trig = Input.method(:trigger?)
    Input.define_singleton_method(:trigger?) { |k| keys.include?(k) }
    yield
  ensure
    Input.define_singleton_method(:trigger?, trig)
  end

  # Runs the block with a profile file's registrations in place, answering its value; then takes them back out and
  # forgets a turn the follower was left asked for.
  def with_profile(registrations)
    bodies = PokeAccess::Hooks.fn_bodies
    saved = registrations[:bodies].map { |k, _list| [k, bodies[k]] }
    registrations[:bodies].each { |k, list| bodies[k] = list }
    pollers = PokeAccess::Frame.instance_variable_get(:@pollers)
    snap = pollers.dup
    pollers.concat(registrations[:pollers])
    yield
  ensure
    saved.each { |k, list| list ? bodies[k] = list : bodies.delete(k) }
    pollers.replace(snap)
    PokeAccess::ArmoniaFollower.instance_variable_set(:@asked, false)
  end

  # Applies the button labels of Armonia's profile (games/armonia/constants.rb), alone of its declarations.
  def button_labels
    src = Harness.source(File.join(Harness::ROOT, "games", "armonia", "constants.rb"))
    PokeAccess::Game::Definition.new.instance_eval(src[/^\s*button_labels .*$/])
  end
end
