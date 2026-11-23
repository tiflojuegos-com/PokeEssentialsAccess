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
  # The player can already use the fonts in the game's Fonts directory. The original installer checks for copies
  # in the Windows font directory, so leave it to run only if the player cannot see the requested families.
  if defined?(::FontInstaller::Names) && ::FontInstaller.respond_to?(:install)
    override("FontInstaller", :install) do |installer, original, _args|
      names = installer.const_get(:Names)
      original.call unless names.is_a?(Array) && !names.empty? && names.all? { |name| Font.exist?(name) }
    end
  end


  before("IntroEventScene", :openPic, :optional => true) do |s, _a|
    k = PokeAccess::InsurgenceIntro.card_key(s)
    PokeAccess.speak(PokeAccess::I18n.t(k), false) if k
  end
end
