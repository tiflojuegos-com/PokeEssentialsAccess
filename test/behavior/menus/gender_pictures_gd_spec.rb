# Anil's new-game character slider, which is nothing but one picture swapped between three portraits: no
# window, no text, and pbChangePlayer only on confirm, so the picture name is the only thing there is to
# read while choosing. Runs in the gamedata pass, which loads the anil profile.
#
# The generic reader cannot cover this: Appearance.on_picture is gated on $PokemonGlobal.playerID, a global
# this game does not keep, so it stays quiet here -- which the last assertion pins, because if that gate
# ever opens the two readers would both answer and the portrait would be spoken twice.
Suite.define("anil intro: the three portraits of the character slider each speak once") do
  girl = PokeAccess::I18n.t(:ap_girl)
  boy = PokeAccess::I18n.t(:ap_boy)
  pic = Game_Picture.new(5)
  show = lambda do |name|
    SpeakCapture.clear
    PokeAccess::PictureCues.reset_last
    pic.show(name, 0, 0, 0, 100, 100, 255, 0)
    SpeakCapture.lines.map { |l| l.to_s }
  end

  eq "the girl portrait says her word", show.call("introGirl"), [girl]
  eq "the boy portrait says his", show.call("introBoy"), [boy]
  eq "and the third says the name the game gives that character", show.call("introYellow"), ["Yellow"]
  eq "a portrait of the appearance question is not part of the slider", show.call("introGirlRaza"), []
  eq "and neither is an unrelated picture", show.call("oakIntro2"), []

  falsy "the appearance gate is shut in this game, so nothing answers twice",
        PokeAccess::Appearance.selecting?

  SpeakCapture.clear
  pic.show("introGirl", 0, 0, 0, 100, 100, 255, 0)
  pic.show("introGirl", 0, 0, 0, 100, 100, 255, 0)
  eq "the same portrait shown twice running speaks once", SpeakCapture.lines.map { |l| l.to_s }, [girl]
end
