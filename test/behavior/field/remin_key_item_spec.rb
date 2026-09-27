# Reminiscencia shows the key-item ceremony for every chest and gift (a Poke Ball, coins, Heart Scales), and the
# message after it names the item: its profile keeps the ceremony quiet for a real item. Only that override block is
# evaluated, and the plugin's method is put back after.
Suite.define("reminiscencia: the item ceremony says nothing over the message that names the item") do
  path = File.join(Harness::ROOT, "games", "reminiscencia", "info_screens.rb")
  block = File.read(path)[/^PokeAccess::Game\.define\("reminiscencia"\) do\r?\n  override\("PokeAccess::KeyItemGet".*?^end\r?\n/m]
  k = PokeAccess::KeyItemGet
  saved = k.method(:announce)
  t = PokeAccess::I18n
  begin
    SpeakCapture.clear
    k.announce(4)
    eq "the plugin alone calls it a key item", SpeakCapture.lines, [t.t(:key_item_ceremony)]
    truthy "the profile's block is found", !block.nil?
    eval(block, TOPLEVEL_BINDING, path)
    SpeakCapture.clear
    k.announce(4)
    silent "a real item: nothing, as its message names it"
    k.announce("VIAL_key")
    eq "a picture name, which no message follows, is still named", SpeakCapture.lines, [t.t(:key_item_get, :name => "Vial")]
  ensure
    k.define_singleton_method(:announce, saved)
  end
end
