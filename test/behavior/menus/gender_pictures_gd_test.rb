# Anil's intro pictures (games/anil/event_menus.rb), gamedata pass: the character slider's three portraits, the
# appearance question's picture of three looks and the mode menu's focused "...Sel" pictures, each said as it is shown.
class GenderPicturesGdTest < PokeAccessTest
  test "says each portrait of the character slider as it is shown" do
    { "introGirl" => PokeAccess::I18n.t(:ap_girl), "introBoy" => PokeAccess::I18n.t(:ap_boy),
      "introYellow" => "Yellow" }.each do |name, said|
      assert_equal [[said, true]], shown(name), "for #{name}"
    end
  end

  test "describes the appearance question's three portraits by position" do
    { "introGirlRaza" => :anil_looks_girl, "introBoyRaza" => :anil_looks_boy }.each do |name, key|
      assert_equal [[PokeAccess::I18n.t(key), true]], shown(name, 0), "for #{name}"
    end
  end

  test "names the mode each focused picture of the mode menu shows" do
    { "MenuClasSel" => :ev_mode_classic, "MenuCompSel" => :ev_mode_complete,
      "MenuRandSel" => :ev_mode_radical }.each do |name, key|
      assert_equal [[PokeAccess::I18n.t(key), true]], shown(name), "for #{name}"
    end
  end

  test "says nothing for an unfocused mode's plain picture or a picture it does not know" do
    ["MenuComp", "oakIntro2"].each { |name| assert_equal [], shown(name), "for #{name}" }
  end

  test "says a portrait shown twice running once" do
    PokeAccess::PictureCues.reset_last
    pic = Game_Picture.new(5)
    2.times { pic.show("introGirl", 0, 0, 0, 100, 100, 255, 0) }
    assert_equal [PokeAccess::I18n.t(:ap_girl)], SpeakCapture.lines
  end

  test "says a portrait again once its picture was erased in between" do
    PokeAccess::PictureCues.reset_last
    pic = Game_Picture.new(5)
    pic.show("introGirl", 0, 0, 0, 100, 100, 255, 0)
    pic.erase
    pic.show("introGirl", 0, 0, 0, 100, 100, 255, 0)
    assert_equal [PokeAccess::I18n.t(:ap_girl)] * 2, SpeakCapture.lines
  end

  private

  # What showing the named picture says, as [text, interrupt] pairs, the last picture said forgotten first.
  # param opacity 0 for a picture the event fades in afterwards
  def shown(name, opacity = 255)
    SpeakCapture.clear
    PokeAccess::PictureCues.reset_last
    Game_Picture.new(4).show(name, 0, 0, 0, 100, 100, opacity, 0)
    SpeakCapture.log.dup
  end
end
