# Infinite Fusion's sprite credit (games/infinitefusion_common/sprite_credits.rb): the artist drawSpriteCredits paints
# under a fused sprite is said right after the congratulations shown with it; a generated sprite credits nobody.

# The game's credit, reduced to its paint: "Sprite by <artist>", nothing for a generated sprite.
def drawSpriteCredits(pif_sprite, _viewport)
  return if pif_sprite == :AUTOGEN
  pbDrawTextPositions(nil, [[_INTL("Sprite by {1}", pif_sprite.to_s), 256, 240, 2, nil, nil]])
end

class IfSpriteCreditsGdTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "infinitefusion_common", "sprite_credits.rb")

  # Evaluates the profile file once, as boot does, its hook bound to the stand-in above.
  def self.load_profile
    profiles = PokeAccess::Game.profiles.dup
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
  ensure
    PokeAccess::Game.profiles.replace(profiles)
  end
  load_profile

  # Drops any line promised around the next dialogue line, so each test starts with none.
  def setup
    super
    PokeAccess.take_head
    PokeAccess.take_tail
  end

  # Drops a credit a test left promised.
  def teardown
    PokeAccess.take_tail
    super
  end

  test "the artist is said right after the congratulations, not as the credit is painted" do
    drawSpriteCredits("Artista", nil)
    assert_nothing_spoken "painting the credit says nothing yet"
    PokeAccess.say_dialogue("Congratulations! Your Pokémon were fused into Pikachar!")
    assert_equal [["Congratulations! Your Pokémon were fused into Pikachar!", false], ["Sprite by Artista", false]],
                 SpeakCapture.log
  end

  test "a generated sprite, credited to nobody, adds nothing to the congratulations" do
    drawSpriteCredits(:AUTOGEN, nil)
    PokeAccess.say_dialogue("Congratulations! Your Pokémon were fused into Charmeleon!")
    assert_equal [["Congratulations! Your Pokémon were fused into Charmeleon!", false]], SpeakCapture.log
  end
end
