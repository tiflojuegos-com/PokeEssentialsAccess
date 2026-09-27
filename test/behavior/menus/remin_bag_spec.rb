# Reminiscencia's bag is read by its own per-frame poll; watching it claims the item window from the generic command
# reader, which would say every row again.
class PokemonBag_Scene; def pbChooseItem; end; def pbCheckItem; end; end unless defined?(PokemonBag_Scene)
require File.expand_path("../../../games/reminiscencia/bag", File.dirname(__FILE__))

Suite.define("reminiscencia bag: its own reader claims the item window from the generic one") do
  rb = PokeAccess::ReminBag
  win = Object.new
  scene = Object.new
  scene.instance_variable_set(:@sprites, { "itemwindow" => win })
  falsy "the window is nobody's before the bag is watched", PokeAccess.dedicated?(win)
  rb.watch(scene)
  begin
    truthy "and the bag's reader claims it once its choose loop runs", PokeAccess.dedicated?(win)
  ensure
    rb.unwatch
  end
end

# The Special pocket (3) paints under its title how many rogue items the bag holds against their limit
# (getRogueItemCount / rogueItemLimit); said with the pocket's name on a switch, and no other pocket has it.
Suite.define("reminiscencia bag: the Special pocket says its count against the limit with its name") do
  rb = PokeAccess::ReminBag
  saved = [$PokemonBag, $Trainer]
  win = Object.new
  def win.pocket; @pocket; end
  def win.pocket=(v); @pocket = v; end
  had_class = Object.const_defined?(:PokemonBag)
  Object.const_set(:PokemonBag, Class.new) unless had_class
  had_names = PokemonBag.respond_to?(:pocketNames)
  PokemonBag.define_singleton_method(:pocketNames) { ["", "Objetos", "Medicinas", "Especial"] } unless had_names
  begin
    bag = Object.new
    def bag.getRogueItemCount; 3; end
    $PokemonBag = bag
    $Trainer = Struct.new(:rogueItemLimit).new(15)
    win.pocket = 3
    pre = PokeAccess::Menus.bag_prefix(win)
    truthy "the core names the pocket", !pre.empty?
    eq "with the count its title paints", rb.pocket_prefix(win),
       "#{pre.sub(/\.\s*\z/, '')}, #{PokeAccess::I18n.t(:list_pos, :i => 3, :n => 15)}. "
    win.pocket = 1
    eq "another pocket is its name alone", rb.pocket_prefix(win), PokeAccess::Menus.bag_prefix(win)
    PokeAccess::Menus.mark_bag_pocket(win)
    eq "and no pocket is named twice", rb.pocket_prefix(win), ""
  ensure
    $PokemonBag, $Trainer = saved
    (class << PokemonBag; self; end).send(:remove_method, :pocketNames) unless had_names
    Object.send(:remove_const, :PokemonBag) unless had_class
  end
end
