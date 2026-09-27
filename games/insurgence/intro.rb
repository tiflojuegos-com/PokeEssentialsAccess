module PokeAccess
  # Insurgence's opening cards (IntroEventScene#openPic, 063_Scene_Intro.rb), intro0 and intro1 in Graphics/Titles,
  # whose text is only in the picture; each card's transcription is said, queued, as it fades in.
  module InsurgenceIntro
    CARDS = { "intro0" => :ins_intro0, "intro1" => :ins_intro1 }

    # The transcription key of the card openPic is about to show, or nil for a picture with none.
    def self.card_key(scene)
      pics = PokeAccess.ivar(scene, :@pics)
      i = PokeAccess.ivar(scene, :@index)
      return nil unless pics.is_a?(Array) && i
      CARDS[pics[i.to_i].to_s]
    end
  end
end

PokeAccess::Game.define("insurgence") do
  before("IntroEventScene", :openPic, :optional => true) do |s, _a|
    k = PokeAccess::InsurgenceIntro.card_key(s)
    PokeAccess.speak(PokeAccess::I18n.t(k), false) if k
  end
end
