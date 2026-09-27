# The BW Key Items ceremony (plugins/bw_key_items.rb) paints only the item's icon: it says what the scene is and
# leaves the name to the game's message after it, whether it is passed an item id or a picture name.
class KeyItemCeremonyStub
  def initialize(item); @item = item; end
  def pbStartScene; :started; end
end

Suite.define("key item ceremony: the item is never named from its icon, an id or a picture name alike") do
  t = PokeAccess::I18n
  saved = Object.const_defined?(:GetKeyItemScene) ? GetKeyItemScene : nil
  begin
    Object.send(:remove_const, :GetKeyItemScene) if saved
    Object.const_set(:GetKeyItemScene, KeyItemCeremonyStub)
    unless $pa_key_item_ceremony_loaded
      load File.expand_path("../../../plugins/bw_key_items.rb", File.dirname(__FILE__))
      $pa_key_item_ceremony_loaded = true
    end
    [:SUPERROD, "SUPERROD_key", "VIAL_key", "itemDexMaleKey"].each do |item|
      SpeakCapture.clear
      eq "#{item.inspect}: the scene keeps its own return", GetKeyItemScene.new(item).pbStartScene, :started
      eq "#{item.inspect}: the ceremony alone, queued", SpeakCapture.log, [[t.t(:key_item_ceremony), false]]
    end
  ensure
    Object.send(:remove_const, :GetKeyItemScene)
    Object.const_set(:GetKeyItemScene, saved) if saved
  end
end
