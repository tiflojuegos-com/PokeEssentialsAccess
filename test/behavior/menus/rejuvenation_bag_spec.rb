# Rejuvenation's favourite items (games/rejuvenation/bag_favourites.rb): the star its bag paints beside a starred
# item is said with the row, and a star set under a still cursor makes the row be said again.
load File.expand_path("../../../games/rejuvenation/bag_favourites.rb", File.dirname(__FILE__))
# Rejuvenation's bag with favourites: Z stars an item, and pocket 9 gathers the starred ones through getPocketItems.
class RVEngineFavBag
  FAVORITES = 9
  attr_reader :pockets, :contents
  def initialize(pockets, contents, favs); @pockets = pockets; @contents = contents; @favs = favs; end
  def isFavorite?(item); @favs.include?(item); end
  def addFavorite(item); @favs.push(item) unless isFavorite?(item); end
  def getPocketItems(pocket); pocket == FAVORITES ? @pockets.flatten.select { |i| isFavorite?(i) } : @pockets[pocket]; end
end

Suite.define("rejuvenation: a favourite item is said as such, and Z's star under a still cursor is heard") do
  decs = PokeAccess::Menus.bag_decorators
  added = !decs.include?(PokeAccess::RejuvenationFavourites)
  decs.push(PokeAccess::RejuvenationFavourites) if added
  begin
    fav = PokeAccess::I18n.t(:mb_favourite)
    bag = RVEngineFavBag.new([[], [:POTION, :REPEL]], { :POTION => 3, :REPEL => 1 }, [:REPEL])
    win = Object.new
    win.instance_variable_set(:@bag, bag)
    win.instance_variable_set(:@pocket, 1)
    def win.pocket; @pocket; end
    win.instance_variable_set(:@index, 0)
    def win.index; @index; end
    def win.itemCount; @bag.getPocketItems(@pocket).length + 1; end
    def win.item; @bag.getPocketItems(@pocket)[@index]; end
    falsy "an item not starred has no mark", PokeAccess::Menus.bag_row(win, 0).include?(fav)
    before = PokeAccess::Menus.bag_witness(win, 0)
    truthy "a pocket of bare ids has a witness too", before
    bag.addFavorite(:POTION)
    truthy "a starred one carries the mark", PokeAccess::Menus.bag_row(win, 0).include?(fav)
    truthy "and the witness changes with Z's star, so the row is said again", PokeAccess::Menus.bag_witness(win, 0) != before
    win.instance_variable_set(:@pocket, RVEngineFavBag::FAVORITES)
    win.instance_variable_set(:@index, 1)
    row = PokeAccess::Menus.bag_row(win, 1)
    truthy "the favourites pocket reads its second item with the count and the mark: #{row}",
           row.include?("REPEL: 1") && row.include?(fav)
    eq "and its witness is that item's", PokeAccess::Menus.bag_witness(win, 1)[0, 2], [:REPEL, 1]
  ensure
    decs.delete(PokeAccess::RejuvenationFavourites) if added
  end
end
