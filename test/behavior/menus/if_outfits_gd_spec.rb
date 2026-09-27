# Infinite Fusion's wardrobe: a hairstyle by its name and colour version, and what the player's preview alone shows
# after the menus' other choices (the hat toggled, a dye reset) and the hair shop's (hat shown, colour swapped). The
# game's functions and classes, reduced to what they change, are defined before the profile file binds to them.
def display_outfit_preview(_x = 320, _y = 0, _border = true)
  hide_outfit_preview if $if_spec_preview
  $if_spec_preview = true
end
def hide_outfit_preview; $if_spec_preview = nil; end
def shiftHairColor(incr); $Trainer.hair_color = $Trainer.hair_color.to_i + incr; end
def shiftClothesColor(incr); $Trainer.clothes_color = $Trainer.clothes_color.to_i + incr; end
def shiftHatColor(incr, _secondary = false); $Trainer.hat_color = $Trainer.hat_color.to_i + incr; end
def get_hair_by_id(id); id == "afro" ? Struct.new(:name).new("Afro") : nil; end
def get_hat_by_id(id); id == "cap" ? Struct.new(:name).new("Gorra") : nil; end

class OutfitSelector
  def changeToNextHairstyle(_incr, _all = false); $Trainer.hair_color = 0; $Trainer.hair = "2_afro"; end
  def changeToNextClothes(_incr, _all = false); end
  def changeToNextHat(_incr, _all = false); end
end

class HairMartAdapter
  def initialize(worn_hat = "cap"); @version = 1; @hat_visible = false; @worn_hat = worn_hat; end
  def toggleEvent(_item); @hat_visible = !@hat_visible; end
  def switchVersion(_item, delta = 1); @version += delta; end
end

module IFOutfitsSpec
  Dress = Struct.new(:clothes, :hat, :hair, :hair_color, :hat_color, :clothes_color)
end

Suite.define("infinite fusion: a hairstyle by name and version, and the preview's changes said") do
  t = PokeAccess::I18n
  old_trainer = $Trainer
  begin
    load File.expand_path("../../../games/infinitefusion_common/outfits.rb", File.dirname(__FILE__))
    $Trainer = IFOutfitsSpec::Dress.new("casual", "cap", "3_afro", 30, 0, 0)
    eq "a hair id with its version number reads the style's name and the version",
       PokeAccess::IFOutfits.item(:hair), "Afro, #{t.t(:if_hair_version, :n => 3)}"
    $Trainer.hair = "afro"
    eq "an id without its version reads the name alone", PokeAccess::IFOutfits.item(:hair), "Afro"

    $Trainer.hair = "3_afro"
    $if_spec_preview = nil
    SpeakCapture.clear
    display_outfit_preview
    silent "the menu's first preview only takes note"
    hat = $Trainer.hat
    $Trainer.hat = nil
    display_outfit_preview
    eq "Toggle hat: the hat comes off", SpeakCapture.lines, [t.t(:if_hat_off)]
    SpeakCapture.clear
    $Trainer.hat = hat
    display_outfit_preview
    eq "and goes back on", SpeakCapture.lines, [t.t(:if_hat_on)]
    SpeakCapture.clear
    shiftHairColor(10)
    display_outfit_preview
    eq "a shift says its hue once, not again with the preview", SpeakCapture.lines, [t.t(:if_hue, :n => 40)]
    SpeakCapture.clear
    $Trainer.hair_color = 0
    display_outfit_preview
    eq "Reset: the dye is gone", SpeakCapture.lines, [t.t(:if_dye_off)]
    SpeakCapture.clear
    OutfitSelector.new.changeToNextHairstyle(1)
    display_outfit_preview
    eq "a new hairstyle is said by the selector, its dye reset with it said no more", SpeakCapture.lines,
       ["Afro, #{t.t(:if_hair_version, :n => 2)}"]
    SpeakCapture.clear
    hide_outfit_preview
    $Trainer.hat = nil
    display_outfit_preview
    silent "a new menu starts from what it first shows"

    shop = HairMartAdapter.new
    SpeakCapture.clear
    shop.toggleEvent(nil)
    shop.switchVersion(nil, 1)
    eq "the hair shop: its hat shown, then the base colour it swapped to", SpeakCapture.lines,
       [t.t(:if_hat_on), t.t(:if_hair_version, :n => 2)]
    SpeakCapture.clear
    HairMartAdapter.new(nil).toggleEvent(nil)
    silent "with no hat worn the toggle changes nothing, so nothing is said"
  ensure
    PokeAccess::IFOutfits.forget
    $Trainer = old_trainer
  end
end
