# Anil's new-game character slider, one picture swapped between three portraits: each is said once; the picture of
# the appearance question describes its three portraits by position, and the mode menu names the mode each "...Sel"
# picture focuses. Gamedata pass (anil profile); the generic Appearance reader stays shut in this game, so nothing
# answers twice.
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
  eq "an unrelated picture says nothing", show.call("oakIntro2"), []

  falsy "the appearance gate is shut in this game, so nothing answers twice",
        PokeAccess::Appearance.selecting?

  SpeakCapture.clear
  pic.show("introGirl", 0, 0, 0, 100, 100, 255, 0)
  pic.show("introGirl", 0, 0, 0, 100, 100, 255, 0)
  eq "the same portrait shown twice running speaks once", SpeakCapture.lines.map { |l| l.to_s }, [girl]
end

# "¿Puedes dar más detalles de tu aspecto?" over Left, Middle and Right: the event shows the picture of three
# portraits transparent and fades it in (Map001, event 2).
Suite.define("anil intro: the appearance question's picture describes its three portraits by position") do
  t = PokeAccess::I18n
  pic = Game_Picture.new(4)
  show = lambda do |name|
    SpeakCapture.clear
    PokeAccess::PictureCues.reset_last
    pic.show(name, 0, 0, 0, 100, 100, 0, 0)
    SpeakCapture.lines.map { |l| l.to_s }
  end
  eq "the girls' three looks", show.call("introGirlRaza"), [t.t(:anil_looks_girl)]
  eq "the boys' three looks", show.call("introBoyRaza"), [t.t(:anil_looks_boy)]
end

# The "Modo Juego" map the intro ends on (Map104) draws the mode menu as pictures, the focused mode in its "...Sel"
# picture and the others plain.
Suite.define("anil intro: the mode menu says the mode each focused picture shows") do
  t = PokeAccess::I18n
  pic = Game_Picture.new(3)
  show = lambda do |name|
    SpeakCapture.clear
    PokeAccess::PictureCues.reset_last
    pic.show(name, 0, 16, 10, 100, 100, 255, 0)
    SpeakCapture.lines.map { |l| l.to_s }
  end
  eq "the classic mode", show.call("MenuClasSel"), [t.t(:ev_mode_classic)]
  eq "the complete mode", show.call("MenuCompSel"), [t.t(:ev_mode_complete)]
  eq "the radical mode", show.call("MenuRandSel"), [t.t(:ev_mode_radical)]
  eq "an unfocused mode's plain picture says nothing", show.call("MenuComp"), []
end
