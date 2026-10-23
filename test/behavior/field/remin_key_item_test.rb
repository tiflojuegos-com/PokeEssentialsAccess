# Reminiscencia's key-item ceremony: the game shows it for every chest and gift and the message after it names a real
# item, so the profile's override (games/reminiscencia/info_screens.rb) keeps the plugin's ceremony quiet for one and
# names the item a picture stands for, which no message follows.
class ReminKeyItemTest < PokeAccessTest
  # The plugin's ceremony, and the profile's override of it: the only block of the profile's file evaluated here,
  # once, the plugin's own method put back until a test puts the override in.
  PLUGIN = PokeAccess::KeyItemGet.method(:announce)
  PROFILE = begin
    path = File.join(Harness::ROOT, "games", "reminiscencia", "info_screens.rb")
    src = Harness.source(path)
    block = src[/^PokeAccess::Game\.define\("reminiscencia"\) do\r?\n  override\("PokeAccess::KeyItemGet".*?^end\r?\n/m]
    raise "the profile's override of the ceremony was not found in #{path}" if block.nil?
    eval(block, TOPLEVEL_BINDING, path, src[0, src.index(block)].count("\n") + 1)
    PokeAccess::KeyItemGet.method(:announce)
  ensure
    PokeAccess::KeyItemGet.define_singleton_method(:announce, PLUGIN)
  end

  test "without the profile, the ceremony says only that it is a key item, queued" do
    PokeAccess::KeyItemGet.announce(4)
    assert_equal [[PokeAccess::I18n.t(:key_item_ceremony), false]], SpeakCapture.log
  end

  test "under the profile, a real item's ceremony says nothing, as its message names it" do
    under_profile { PokeAccess::KeyItemGet.announce(4) }
    assert_nothing_spoken
  end

  test "under the profile, a picture name is said as the item it stands for, queued" do
    { "VIAL_key" => "Vial", "item12_llave_roja" => "Llave roja", "MEDALLON" => "Medallon" }.each do |picture, name|
      SpeakCapture.clear
      under_profile { PokeAccess::KeyItemGet.announce(picture) }
      assert_equal [[PokeAccess::I18n.t(:key_item_get, :name => name), false]], SpeakCapture.log, "for #{picture}"
    end
  end

  test "under the profile, a picture name with no item left in it says nothing" do
    under_profile { %w[_key item3_key].each { |picture| PokeAccess::KeyItemGet.announce(picture) } }
    assert_nothing_spoken
  end

  private

  # Runs the block with the profile's override in place of the plugin's ceremony, the plugin's put back after.
  def under_profile
    PokeAccess::KeyItemGet.define_singleton_method(:announce, PROFILE)
    yield
  ensure
    PokeAccess::KeyItemGet.define_singleton_method(:announce, PLUGIN)
  end
end
