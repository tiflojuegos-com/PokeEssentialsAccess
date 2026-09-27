# Soulstones' own bag (games/soulstones1/bag.rb) never draws the frame the stock bag gives an item that could be
# registered, so no row is said as registrable. The profile file is loaded for this suite alone and its override taken
# back afterwards: it belongs to the Soulstones process.
Suite.define("soulstones1 bag: a key item the game could register is not said as registrable") do
  m = PokeAccess::Menus
  meta = (class << m; self; end)
  had_can = Object.private_method_defined?(:pbCanRegisterItem?) || Object.method_defined?(:pbCanRegisterItem?)
  had_imp = Object.private_method_defined?(:pbIsImportantItem?) || Object.method_defined?(:pbIsImportantItem?)
  Object.send(:define_method, :pbCanRegisterItem?) { |_item| true } unless had_can
  Object.send(:define_method, :pbIsImportantItem?) { |_item| true } unless had_imp
  bag = Object.new
  def bag.registered?(_item); false; end
  meta.send(:alias_method, :ss1_spec_registrable, :bag_registrable?)
  begin
    truthy "the stock bag's reading marks it", m.bag_registrable?(bag, 5)
    load File.join(Harness::ROOT, "games", "soulstones1", "bag.rb")
    falsy "Soulstones' bag paints no such frame, so its reading does not either", m.bag_registrable?(bag, 5)
  ensure
    meta.send(:alias_method, :bag_registrable?, :ss1_spec_registrable)
    meta.send(:remove_method, :ss1_spec_registrable)
    Object.send(:remove_method, :pbCanRegisterItem?) unless had_can
    Object.send(:remove_method, :pbIsImportantItem?) unless had_imp
  end
end
