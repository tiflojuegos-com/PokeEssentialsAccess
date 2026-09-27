# FieldMoves.can?: the engine's finder for a Pokemon that knows the move, the items games hand moves to, and the
# badge; nil (the party could not be read) is never a no.
def field_moves_with_finder(result)
  tr = PokeAccess::Engine.player
  tr.instance_variable_set(:@spec_finder, result)
  def tr.get_pokemon_with_move(_m); @spec_finder; end
  yield tr
ensure
  class << tr; remove_method :get_pokemon_with_move; end
end

def field_moves_with_bag(items)
  had = $PokemonBag
  bag = Object.new
  bag.instance_variable_set(:@items, items)
  def bag.pbQuantity(item); @items.include?(item) ? 1 : 0; end
  $PokemonBag = bag
  yield
ensure
  $PokemonBag = had
end

Suite.define("field moves: the party, an item a game registered, and nothing readable") do
  fm = PokeAccess::FieldMoves
  truthy "a party the engine cannot search answers nothing, not no", fm.can?(:DIVE).nil?
  field_moves_with_finder(:pk) { truthy "a Pokemon that knows it", fm.can?(:DIVE) }
  field_moves_with_finder(nil) do
    eq "nobody knows it", fm.can?(:DIVE), false
    items = fm.instance_variable_get(:@items)
    saved = items[:DIVE]
    begin
      fm.register_item(:DIVE, :SPECGEAR)
      field_moves_with_bag([:SPECGEAR]) { truthy "but the game's own gear is in the bag", fm.can?(:DIVE) }
      field_moves_with_bag([]) { eq "and without it, no", fm.can?(:DIVE), false }
    ensure
      if saved then items[:DIVE] = saved else items.delete(:DIVE) end
    end
  end
end

Suite.define("field moves: Marin's HM Items make the item the whole rule") do
  fm = PokeAccess::FieldMoves
  Object.const_set(:USING_SURF_ITEM, true)
  Object.const_set(:SURF_ITEM, :SPECSURFITEM)
  begin
    field_moves_with_finder(:pk) do
      field_moves_with_bag([]) { eq "knowing Surf is not enough once the item has taken it over", fm.can?(:SURF), false }
      field_moves_with_bag([:SPECSURFITEM]) { truthy "the item is", fm.can?(:SURF) }
    end
  ensure
    Object.send(:remove_const, :USING_SURF_ITEM)
    Object.send(:remove_const, :SURF_ITEM)
  end
end

Suite.define("field moves: the Advanced Items plugin is asked through its own predicate") do
  fm = PokeAccess::FieldMoves
  mod = Module.new
  mod.const_set(:CUT_CONFIG, { :internal_name => :CUTITEM, :item => true })
  Object.const_set(:AdvancedItemsFieldMoves, mod)
  class Object
    private
    def pbCanUseItem(cfg); $spec_aifm_ok && cfg[:internal_name] == :CUTITEM; end
  end
  begin
    field_moves_with_finder(nil) do
      $spec_aifm_ok = true
      truthy "the plugin says the item may be used", fm.can?(:CUT)
      $spec_aifm_ok = false
      eq "and when it says no, the party decides", fm.can?(:CUT), false
    end
  ensure
    $spec_aifm_ok = nil
    class Object; remove_method :pbCanUseItem; end
    Object.send(:remove_const, :AdvancedItemsFieldMoves)
  end
end

Suite.define("field moves: the badge a move needs") do
  fm = PokeAccess::FieldMoves
  tr = PokeAccess::Engine.player
  had = tr.badges
  Object.const_set(:BADGEFORSTRENGTH, 3)
  begin
    field_moves_with_finder(:pk) do
      tr.badges = [false, false, false, false]
      eq "the move known, the badge missing", fm.can?(:STRENGTH), false
      tr.badges = [false, false, false, true]
      truthy "badge won", fm.can?(:STRENGTH)
    end
  ensure
    tr.badges = had
    Object.send(:remove_const, :BADGEFORSTRENGTH)
  end
end
