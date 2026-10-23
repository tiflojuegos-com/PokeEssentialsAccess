# The BW Key Items ceremony (plugins/bw_key_items.rb) paints only the item's icon: it says what the scene is and leaves
# the item's name to the game's message after it; where no message follows, a picture name stands for its item.

# BW Key Items' scene, its opener answering as the game's does. The plugin is evaluated again once the scene exists,
# so its hook binds to it.
class GetKeyItemScene
  def initialize(item); @item = item; end
  def pbStartScene; :started; end
end
path = File.join(Harness::ROOT, "plugins", "bw_key_items.rb")
eval(Harness.source(path), TOPLEVEL_BINDING, path)

class KeyItemGetGdTest < PokeAccessTest
  test "the ceremony says only that it is a key item, queued, whatever item it opens with" do
    [:SUPERROD, 4, "SUPERROD_key", "VIAL_key", "itemDexMaleKey"].each do |item|
      SpeakCapture.clear
      GetKeyItemScene.new(item).pbStartScene
      assert_equal [[PokeAccess::I18n.t(:key_item_ceremony), false]], SpeakCapture.log, "opened with #{item.inspect}"
    end
  end

  test "the scene's opener answers as the game's" do
    assert_equal :started, GetKeyItemScene.new(:SUPERROD).pbStartScene
  end

  test "a picture name stands for the item it shows" do
    { "VIAL_key" => "Vial", "SUPERROD_KEY" => "Superrod", "item12_super_rod_key" => "Super rod" }.each do |pic, want|
      assert_equal want, PokeAccess::KeyItemGet.picture_name(pic), "the picture #{pic.inspect}"
    end
  end

  test "a real item, or a picture name with nothing left of it, stands for no name" do
    [:SUPERROD, 4, "_key", "item_"].each do |item|
      assert_nil PokeAccess::KeyItemGet.picture_name(item), "for #{item.inspect}"
    end
  end
end
