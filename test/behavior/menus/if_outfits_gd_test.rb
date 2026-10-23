# Infinite Fusion's wardrobe (games/infinitefusion_common/outfits.rb): what each selector puts on, a dye's hue, what
# the preview alone shows changed (a hat toggled, a dye reset, the colour version swapped) and the hair shop's swaps.

# The game's outfit data, by id: the names its menus show, which its lookups answer from (with_outfit_data).
module IFOutfitData
  Entry = Struct.new(:name)
  HAIRS = { "afro" => Entry.new("Afro"), "bob" => Entry.new("Bob") }
  HATS = { "cap" => Entry.new("Gorra"), "beanie" => Entry.new("Gorro"), "nameless" => Entry.new("") }
  CLOTHES = { "casual" => Entry.new("Ropa casual"), "suit" => Entry.new("Traje") }
end

# The game's wardrobe functions the profile hooks, reduced to what they change on the player; the preview hides the one
# already up before it draws, as the game's does.
def shiftHairColor(incr); $Trainer.hair_color = $Trainer.hair_color.to_i + incr; end
def shiftClothesColor(incr); $Trainer.clothes_color = $Trainer.clothes_color.to_i + incr; end

def shiftHatColor(incr, secondary = false)
  if secondary
    $Trainer.hat2_color = $Trainer.hat2_color.to_i + incr
  else
    $Trainer.hat_color = $Trainer.hat_color.to_i + incr
  end
end

def display_outfit_preview(_x = 320, _y = 0, _border = true)
  hide_outfit_preview if $if_outfit_preview_up
  $if_outfit_preview_up = true
  :previewed
end

def hide_outfit_preview; $if_outfit_preview_up = nil; end

# The wardrobe's selector, reduced to what each change puts on: the next hairstyle (its dye reset with it), clothes
# and hat.
class OutfitSelector
  def changeToNextHairstyle(_incr, _all = false); $Trainer.hair_color = 0; $Trainer.hair = "2_bob"; end
  def changeToNextClothes(_incr, _all = false); $Trainer.clothes = "suit"; end
  def changeToNextHat(_incr, _all = false); $Trainer.hat = "beanie"; end
end

# The hair shop's preview, reduced to its hat toggle (shown only with a hat worn) and its colour version.
class HairMartAdapter
  def initialize(worn_hat = "cap"); @version = 1; @hat_visible = false; @worn_hat = worn_hat; end
  def toggleEvent(_item); @hat_visible = !@hat_visible; end
  def switchVersion(_item, delta = 1); @version += delta; end
end

class IfOutfitsGdTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "infinitefusion_common", "outfits.rb")
  # What the player wears: clothes, the hats (the second one Hoenn's), the hair and each dye.
  Dress = Struct.new(:clothes, :hat, :hat2, :hair, :hair_color, :hat_color, :hat2_color, :clothes_color)

  # Evaluates the profile file once, as boot does, its hooks bound to the stand-ins above.
  def self.load_profile
    profiles = PokeAccess::Game.profiles.dup
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
  ensure
    PokeAccess::Game.profiles.replace(profiles)
  end
  load_profile

  # The player in casual clothes, a cap and an afro dyed 30, with no preview up.
  def setup
    super
    @trainer_was = $Trainer
    $Trainer = Dress.new("casual", "cap", nil, "3_afro", 30, 0, 0, 0)
    $if_outfit_preview_up = nil
  end

  # Forgets the menu's preview and puts the game's player back.
  def teardown
    PokeAccess::IFOutfits.forget
    $if_outfit_preview_up = nil
    $Trainer = @trainer_was
    super
  end

  test "a hairstyle reads by its name and its colour version" do
    assert_equal "Afro, #{t(:if_hair_version, :n => 3)}", with_outfit_data { PokeAccess::IFOutfits.item(:hair) }
  end

  test "a hair id without a colour version reads the style's name alone" do
    $Trainer.hair = "afro"
    assert_equal "Afro", with_outfit_data { PokeAccess::IFOutfits.item(:hair) }
  end

  test "clothes and a hat read by their outfit-data names" do
    names = with_outfit_data { [PokeAccess::IFOutfits.item(:clothes), PokeAccess::IFOutfits.item(:hat)] }
    assert_equal ["Ropa casual", "Gorra"], names
  end

  test "nothing worn reads as none" do
    [nil, ""].each do |none|
      $Trainer.hat = none
      assert_equal t(:if_outfit_none), PokeAccess::IFOutfits.item(:hat), none.inspect
    end
  end

  test "an id the outfit data does not know reads as the id itself, version and all" do
    $Trainer.hat = "straw_hat"
    $Trainer.hair = "3_mohawk"
    names = with_outfit_data { [PokeAccess::IFOutfits.item(:hat), PokeAccess::IFOutfits.item(:hair)] }
    assert_equal ["straw_hat", "3_mohawk"], names
  end

  test "an outfit its data gives no name reads as its id" do
    $Trainer.hat = "nameless"
    assert_equal "nameless", with_outfit_data { PokeAccess::IFOutfits.item(:hat) }
  end

  test "a selector says nothing of a player it cannot read" do
    $Trainer = nil
    PokeAccess::IFOutfits.say_item(:hat)
    assert_nothing_spoken
  end

  test "the clothes and hat selectors say what is worn now" do
    selector = OutfitSelector.new
    with_outfit_data do
      selector.changeToNextClothes(1)
      selector.changeToNextHat(1)
    end
    assert_equal [["Traje", true], ["Gorro", true]], SpeakCapture.log
  end

  test "a new hairstyle is said by the selector, the dye it resets said no more by the preview" do
    with_outfit_data do
      display_outfit_preview
      OutfitSelector.new.changeToNextHairstyle(1)
      display_outfit_preview
    end
    assert_equal [["Bob, #{t(:if_hair_version, :n => 2)}", true]], SpeakCapture.log
  end

  test "each dye shift says the hue that dye now has" do
    shifts = [["hair", lambda { shiftHairColor(5) }, 35], ["clothes", lambda { shiftClothesColor(6) }, 6],
              ["hat", lambda { shiftHatColor(7) }, 7], ["second hat", lambda { shiftHatColor(9, true) }, 9]]
    shifts.each do |dye, shift, hue|
      SpeakCapture.clear
      shift.call
      assert_equal [[t(:if_hue, :n => hue), true]], SpeakCapture.log, dye
    end
  end

  test "a dye shift is said once, not again by the preview after it, even one down to no dye" do
    display_outfit_preview
    shiftHairColor(-30)
    display_outfit_preview
    assert_equal [t(:if_hue, :n => 0)], SpeakCapture.lines
  end

  test "a menu's first preview only takes note of what it shows" do
    display_outfit_preview
    assert_nothing_spoken
  end

  test "the preview keeps the game's own return" do
    assert_equal :previewed, display_outfit_preview
  end

  test "the hat taken off and put back on in the preview is said each time" do
    display_outfit_preview
    $Trainer.hat = nil
    display_outfit_preview
    assert_equal [[t(:if_hat_off), true]], SpeakCapture.log, "taken off"
    SpeakCapture.clear
    $Trainer.hat = "cap"
    display_outfit_preview
    assert_equal [[t(:if_hat_on), true]], SpeakCapture.log, "put back on"
  end

  test "the second hat toggled in the preview is said as the first is" do
    $Trainer.hat2 = ""
    assert_equal [t(:if_hat_on)], preview_saying { $Trainer.hat2 = "beanie" }, "put on"
    assert_equal [t(:if_hat_off)], preview_saying { $Trainer.hat2 = "" }, "taken off"
  end

  test "both hats taken off at once are said once" do
    $Trainer.hat2 = "beanie"
    said = preview_saying do
      $Trainer.hat = nil
      $Trainer.hat2 = nil
    end
    assert_equal [t(:if_hat_off)], said
  end

  test "a dye reset in the preview is said, whichever dye it was" do
    [:hair_color, :hat_color, :hat2_color, :clothes_color].each do |dye|
      $Trainer[dye] = 20
      assert_equal [t(:if_dye_off)], preview_saying { $Trainer[dye] = 0 }, dye.to_s
    end
  end

  test "a dye given in the preview is no reset" do
    assert_equal [], preview_saying { $Trainer.clothes_color = 40 }
  end

  test "a hat and a dye changed in one repaint are said together" do
    said = preview_saying do
      $Trainer.hat = nil
      $Trainer.hair_color = 0
    end
    assert_equal ["#{t(:if_hat_off)}, #{t(:if_dye_off)}"], said
  end

  test "the colour version swapped in the preview is said" do
    assert_equal [t(:if_hair_version, :n => 2)], preview_saying { $Trainer.hair = "2_afro" }
  end

  test "another hairstyle seen by the preview is no version swap" do
    assert_equal [], preview_saying { $Trainer.hair = "3_bob" }
  end

  test "a hair id that drops its colour version in the preview is no dye reset" do
    assert_equal [], preview_saying { $Trainer.hair = "afro" }
  end

  test "a menu closed and opened again starts from what it first shows" do
    display_outfit_preview
    hide_outfit_preview
    $Trainer.hat = nil
    display_outfit_preview
    assert_nothing_spoken
  end

  test "the hair shop's hat toggle says whether the preview shows the hat" do
    shop = HairMartAdapter.new
    shop.toggleEvent(nil)
    shop.toggleEvent(nil)
    assert_equal [[t(:if_hat_on), true], [t(:if_hat_off), true]], SpeakCapture.log
  end

  test "with no hat worn the hair shop's toggle changes nothing and says nothing" do
    HairMartAdapter.new(nil).toggleEvent(nil)
    assert_nothing_spoken
  end

  test "the hair shop's colour swap says the base colour version it swapped to" do
    shop = HairMartAdapter.new
    shop.switchVersion(nil, 1)
    shop.switchVersion(nil, -1)
    assert_equal [[t(:if_hair_version, :n => 2), true], [t(:if_hair_version, :n => 1), true]], SpeakCapture.log
  end

  private

  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # Runs the block with the game's get_hair_by_id, get_hat_by_id and get_clothes_by_id answering from IFOutfitData,
  # whatever stood there put back afterwards.
  def with_outfit_data(&blk)
    GameFunctions.with(:get_hair_by_id => lambda { |id| IFOutfitData::HAIRS[id] },
                       :get_hat_by_id => lambda { |id| IFOutfitData::HATS[id] },
                       :get_clothes_by_id => lambda { |id| IFOutfitData::CLOTHES[id] }, &blk)
  end

  # What a menu's preview says of the change the block makes after its first preview.
  def preview_saying
    display_outfit_preview
    SpeakCapture.clear
    yield
    display_outfit_preview
    SpeakCapture.lines
  ensure
    hide_outfit_preview
  end
end
