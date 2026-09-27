# Realidea paints the count of one key item, the Paper, through a helper of its own (vercantidad); every other
# key item shows none. The profile keeps that one count; it is loaded for this suite alone.
Suite.define("realidea: the Paper keeps the count its bag paints, other key items none") do
  m = PokeAccess::Menus
  meta = (class << m; self; end)
  meta.send(:alias_method, :rea_spec_bag_hides_qty?, :bag_hides_qty?)
  Object.send(:define_method, :vercantidad) { |item| item == :PAPEL }
  Object.send(:define_method, :pbIsImportantItem?) { |item| [:PAPEL, :BICI].include?(item) }
  begin
    load File.expand_path("../../../games/realidea/bag_qty.rb", File.dirname(__FILE__))
    falsy "the Paper shows its count", m.bag_hides_qty?(:PAPEL)
    truthy "another key item does not", m.bag_hides_qty?(:BICI)
    falsy "and an ordinary item does", m.bag_hides_qty?(:POCION)
  ensure
    meta.send(:alias_method, :bag_hides_qty?, :rea_spec_bag_hides_qty?)
    meta.send(:remove_method, :rea_spec_bag_hides_qty?)
    Object.send(:remove_method, :vercantidad)
    Object.send(:remove_method, :pbIsImportantItem?)
  end
end
