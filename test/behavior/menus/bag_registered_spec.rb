# A bag row's registered mark, in each shape a bag keeps it: Pokemon Z has both the list (registered?) and the old
# slot (registeredItem), and paints the mark when either says so.
Suite.define("bag: the registered mark follows what the row paints, both slots of a double bag included") do
  m = PokeAccess::Menus
  double = Object.new
  def double.registered?(item); item == :BICI; end
  def double.registeredItem; :CANA; end
  truthy "an item the list registers is marked", m.bag_registered?(double, :BICI)
  truthy "one the old slot still points at is marked too, as the row paints it", m.bag_registered?(double, :CANA)
  falsy "and one neither holds is not", m.bag_registered?(double, :POCION)
  modern = Object.new
  def modern.registered?(item); item == :BICI; end
  falsy "a bag with only the list answers by the list", m.bag_registered?(modern, :CANA)
  old = Object.new
  def old.registeredItem; :CANA; end
  truthy "a bag with only the old slot answers by the slot", m.bag_registered?(old, :CANA)
end
