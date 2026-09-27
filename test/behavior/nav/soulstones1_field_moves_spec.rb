# Soulstones' edit of FL's HMs as Items (games/soulstones1/field_moves.rb): the PokeGear apps in the bag stand in for
# Cut, Rock Smash, Strength, Surf, Dive and Waterfall, and the game still wants each move's badge. The profile file is
# loaded for this suite alone; its declarations and its override are taken back afterwards.
module Soulstones1FieldMovesSpec
  # Runs the block with a bag holding the given items, no party that knows a move, and the given badges won, all put
  # back afterwards.
  def self.world(items, badges)
    fm = PokeAccess::FieldMoves
    bag_was = $PokemonBag
    badges_was = $Trainer.badges
    knows = fm.method(:knows?)
    $PokemonBag = Object.new
    $PokemonBag.define_singleton_method(:pbQuantity) { |id| items.include?(id) ? 1 : 0 }
    $Trainer.badges = [true] * badges + [false] * (8 - badges)
    fm.define_singleton_method(:knows?) { |_m| false }
    yield
  ensure
    $PokemonBag = bag_was
    $Trainer.badges = badges_was
    fm.define_singleton_method(:knows?, knows)
  end
end

Suite.define("soulstones1 field moves: an app in the bag stands in for its move, once the move's badge is won") do
  fm = PokeAccess::FieldMoves
  meta = (class << fm; self; end)
  items_was = {}
  fm.instance_variable_get(:@items).each { |k, v| items_was[k] = v.dup }
  made = []
  { "BADGEFORCUT" => 1, "BADGEFORSURF" => 3 }.each do |c, v|
    next if Object.const_defined?(c)
    Object.const_set(c, v)
    made.push(c)
  end
  meta.send(:alias_method, :ss1_spec_item_ready, :item_ready?)
  begin
    Soulstones1FieldMovesSpec.world([:CUTITEM, :SURFITEM], 8) do
      falsy "the core alone does not know the Mini-Scyther App cuts", fm.can?(:CUT)
    end
    load File.join(Harness::ROOT, "games", "soulstones1", "field_moves.rb")
    apps = PokeAccess::Soulstones1FieldMoves::APPS
    eq "the six moves, each to the item constant the script checks",
       apps, { :CUT => :CUTITEM, :ROCKSMASH => :ROCKSMAMUKEM, :STRENGTH => :STRENGTHITEM, :SURF => :SURFITEM,
               :DIVE => :DIVEITEM, :WATERFALL => :WATERFALLITEM }
    Soulstones1FieldMovesSpec.world([:CUTITEM, :SURFITEM], 8) do
      truthy "with the app and the badge, Cut can be used with no Pokemon that knows it", fm.can?(:CUT)
      truthy "and Surf, so the water is on the way", fm.can?(:SURF)
      falsy "an app not in the bag stands in for nothing", fm.can?(:WATERFALL)
    end
    Soulstones1FieldMovesSpec.world([:CUTITEM, :SURFITEM], 2) do
      truthy "with Cut's badge won, the app cuts", fm.can?(:CUT)
      falsy "without Surf's, the app does not surf, as the game refuses before looking at it", fm.can?(:SURF)
    end
    Soulstones1FieldMovesSpec.world([], 8) do
      falsy "without the app and without a Pokemon that knows it, no Cut", fm.can?(:CUT)
    end
  ensure
    meta.send(:alias_method, :item_ready?, :ss1_spec_item_ready)
    meta.send(:remove_method, :ss1_spec_item_ready)
    fm.instance_variable_set(:@items, items_was)
    made.each { |c| Object.send(:remove_const, c) }
  end
end
