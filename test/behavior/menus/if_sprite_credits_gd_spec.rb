# Infinite Fusion's sprite credit at the end of a fusion: drawSpriteCredits paints "Sprite by <artist>" (nothing for a
# generated sprite) as the congratulations show; the credit is said right after them. The game's function, reduced
# to its paint, is defined before the profile file binds to it.
def drawSpriteCredits(pif_sprite, _viewport)
  return if pif_sprite == :AUTOGEN
  pbDrawTextPositions(nil, [[_INTL("Sprite by {1}", pif_sprite.to_s), 256, 240, 2, nil, nil]])
end

Suite.define("infinite fusion: the fused sprite's artist is said after the congratulations") do
  load File.expand_path("../../../games/infinitefusion_common/sprite_credits.rb", File.dirname(__FILE__))
  SpeakCapture.clear
  drawSpriteCredits("Artista", nil)
  silent "painting the credit says nothing yet"
  PokeAccess.say_dialogue("Congratulations! Your Pokémon were fused into Pikachar!")
  eq "the congratulations, then the credit painted under the sprite", SpeakCapture.lines,
     ["Congratulations! Your Pokémon were fused into Pikachar!", "Sprite by Artista"]

  SpeakCapture.clear
  drawSpriteCredits(:AUTOGEN, nil)
  PokeAccess.say_dialogue("Congratulations! Your Pokémon were fused into Charmeleon!")
  eq "a generated sprite, credited to nobody, adds nothing", SpeakCapture.lines,
     ["Congratulations! Your Pokémon were fused into Charmeleon!"]
end
