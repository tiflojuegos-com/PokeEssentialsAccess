# Armonia's own scripts read through its profile: the follower Bezier's follow script puts behind the player, the
# pictures and the video with no text to capture, and the remap menu's names for the follower's keys. The follow and
# video functions are stand-ins shaped as 0189_follow.rb and 0202_video.rb; each file is evaluated whole in a sandbox
# that puts back what it registered for the rest of the run.
module ArmoniaProfileSpec
  # Evaluates one of this repo's Armonia profile files as the loader does and runs the block, then puts back the
  # profile list, the frame pollers and the bodies on the given functions.
  def self.sandboxed(file, functions)
    game = PokeAccess::Game
    profiles = game.profiles.dup
    pollers = PokeAccess::Keys.instance_variable_get(:@frame_pollers)
    poller_snap = pollers ? pollers.dup : nil
    bodies = PokeAccess::Hooks.fn_bodies
    saved = {}
    functions.each do |f|
      %w[before after around].each do |w|
        saved["#{f}|#{w}"] = bodies.delete("#{f}|#{w}")
      end
    end
    begin
      path = File.join(Harness::ROOT, "games", "armonia", file)
      eval(File.read(path), TOPLEVEL_BINDING, path)
      yield
    ensure
      game.profiles.replace(profiles)
      game.instance_variable_set(:@profile_name, nil)
      pollers.replace(poller_snap) if pollers && poller_snap
      saved.each { |k, v| v ? bodies[k] = v : bodies.delete(k) }
    end
  end

  # Runs the block with Input answering true for the given buttons only.
  def self.pressing(*keys)
    trig = Input.method(:trigger?)
    Input.define_singleton_method(:trigger?) { |k| keys.include?(k) }
    yield
  ensure
    Input.define_singleton_method(:trigger?, trig)
  end

  # Runs the block with a trainer whose party is the given Pokemon, the follower shown.
  def self.with_party(party)
    saved = $Trainer
    hidden = $Follow_Hidden
    tr = Object.new
    tr.define_singleton_method(:party) { party }
    $Trainer = tr
    $Follow_Hidden = false
    yield
  ensure
    $Trainer = saved
    $Follow_Hidden = hidden
  end
end

FOLLOW_KEY_TOGGLE = Input::L unless defined?(FOLLOW_KEY_TOGGLE)

# changeFollowingSprite as the follow script has it: with anim, A and D only queue the turn; without it, the party
# turns once and on past fainted members (FOLLOW_FAINTED_REPLACE), all the way round when every one is fainted.
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
def toggleFollowingPokemon(anim = true)
  return if $Trainer.party[0].hp <= 0
  $Follow_Hidden = !$Follow_Hidden
end unless Object.private_method_defined?(:toggleFollowingPokemon)

# playVideo: its frames, drawn with no sound.
def playVideo(name)
  PokeAccess.speak("frames #{name}", false)
end unless Object.private_method_defined?(:playVideo)

Suite.define("armonia: a turn of the party says who leads it now, interrupting when A or D asked for it") do
  t = PokeAccess::I18n
  a = Poke.build(:name => "Hojarí")
  b = Poke.build(:name => "Flamiwel")
  c = Poke.build(:name => "Princine", :hp => 0)
  ArmoniaProfileSpec.sandboxed("follower.rb", %w[changeFollowingSprite toggleFollowingPokemon]) do
    ArmoniaProfileSpec.with_party([a, b, c]) do
      SpeakCapture.clear
      changeFollowingSprite(1, true)
      silent "D only queues the turn"
      changeFollowingSprite(1, false)
      eq "the queued turn says the new lead, interrupting", SpeakCapture.log,
         [[t.t(:arm_follow_lead, :name => "Flamiwel"), true]]
      SpeakCapture.clear
      changeFollowingSprite(1, true)
      changeFollowingSprite(1, false)
      eq "past the fainted one, to the next healthy Pokemon", SpeakCapture.log,
         [[t.t(:arm_follow_lead, :name => "Hojarí"), true]]
      SpeakCapture.clear
      changeFollowingSprite(-1, true)
      changeFollowingSprite(-1, false)
      eq "A turns back the other way", SpeakCapture.lines, [t.t(:arm_follow_lead, :name => "Flamiwel")]
      SpeakCapture.clear
      changeFollowingSprite
      silent "a redraw with no turn says nothing"
    end
    ArmoniaProfileSpec.with_party([c, a]) do
      SpeakCapture.clear
      changeFollowingSprite(1)
      eq "a battle's end with the lead fainted: the healthy one it puts in front, queued", SpeakCapture.log,
         [[t.t(:arm_follow_lead, :name => "Hojarí"), false]]
    end
    ArmoniaProfileSpec.with_party([c, Poke.build(:name => "Bufflint", :hp => 0)]) do
      SpeakCapture.clear
      changeFollowingSprite(1)
      silent "all fainted, the turn goes all the way round and the lead is the same"
    end
  end
end

Suite.define("armonia: Q says whether the follower is now hidden or shown, and an event's toggle stays unsaid") do
  t = PokeAccess::I18n
  ArmoniaProfileSpec.sandboxed("follower.rb", %w[changeFollowingSprite toggleFollowingPokemon]) do
    ArmoniaProfileSpec.with_party([Poke.build(:name => "Hojarí")]) do
      SpeakCapture.clear
      ArmoniaProfileSpec.pressing(FOLLOW_KEY_TOGGLE) { toggleFollowingPokemon }
      eq "Q hides it", SpeakCapture.lines, [t.t(:arm_follow_hidden)]
      SpeakCapture.clear
      ArmoniaProfileSpec.pressing(FOLLOW_KEY_TOGGLE) { toggleFollowingPokemon }
      eq "and shows it again", SpeakCapture.lines, [t.t(:arm_follow_shown)]
      SpeakCapture.clear
      toggleFollowingPokemon
      silent "an event's pbToggleFollowingPokemon, with no key pressed, is not announced"
    end
    ArmoniaProfileSpec.with_party([Poke.build(:name => "Hojarí", :hp => 0)]) do
      SpeakCapture.clear
      ArmoniaProfileSpec.pressing(FOLLOW_KEY_TOGGLE) { toggleFollowingPokemon }
      silent "with the lead fainted the key does nothing, and nothing is said"
    end
  end
end

Suite.define("armonia: the two pictures before the title are said once, and the story's video where it starts and ends") do
  t = PokeAccess::I18n
  made = !Object.const_defined?(:Scene_Intro)
  Object.const_set(:Scene_Intro, Class.new) if made
  saved = $scene
  begin
    ArmoniaProfileSpec.sandboxed("cutscenes.rb", %w[playVideo]) do
      intro = Scene_Intro.new
      intro.instance_variable_set(:@pics, ["intro1", "intro2"])
      $scene = intro
      SpeakCapture.clear
      PokeAccess::Keys.run_frame_pollers
      PokeAccess::Keys.run_frame_pollers
      eq "the pictures' text, once, queued, in the order they show", SpeakCapture.log,
         [[t.t(:arm_intro_fans), false], [t.t(:arm_intro_studio), false]]
      titled = Scene_Intro.new
      titled.instance_variable_set(:@pics, ["intro1", "intro2"])
      titled.instance_variable_set(:@screen, Object.new)
      $scene = titled
      SpeakCapture.clear
      PokeAccess::Keys.run_frame_pollers
      silent "with the title up the pictures are gone, and nothing is said"
      SpeakCapture.clear
      playVideo("animbeta")
      eq "the video's start and end around its frames", SpeakCapture.lines,
         [t.t(:arm_video_start), "frames animbeta", t.t(:arm_video_end)]
    end
  ensure
    $scene = saved
    Object.send(:remove_const, :Scene_Intro) if made
  end
end

Suite.define("armonia: the remap menu names X, Z and L by what they also do on the map") do
  t = PokeAccess::I18n
  saved = PokeAccess::Config.rebind_labels.dup
  begin
    src = File.read(File.join(Harness::ROOT, "games", "armonia", "constants.rb"))
    PokeAccess::Game::Definition.new.instance_eval(src[/^\s*button_labels .*$/])
    eq "Z, the D key, turns to the next follower", PokeAccess::Remap.label(:z), t.t(:arm_btn_z)
    eq "L, the Q key, pages lists and hides or shows the follower", PokeAccess::Remap.label(:l), t.t(:arm_btn_l)
    eq "X, the A key, the previous follower, and the DexNav in the pause menu", PokeAccess::Remap.label(:x), t.t(:arm_btn_x)
    truthy "the paging half keeps the core's own name for L", t.t(:arm_btn_l).start_with?(t.t(:btn_l))
  ensure
    PokeAccess::Config.rebind_labels = saved
  end
end
