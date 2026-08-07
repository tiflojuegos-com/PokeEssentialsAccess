module PokeAccess
  # DBK Enhanced Battle UI in-battle SELECTORS (sprite cursors, no command window, so the generic hook
  # cannot see them). Two screens sit on the action path: the Poke Ball picker (which ball to throw) and the
  # battler-selection grid (which battler to inspect). The detail panel that opens AFTER picking a battler is
  # read by dbk_battlerinfo; here we read the CURSOR as it moves. Gated by method existence so only DBK games
  # bind, and no-op on gen-6 (no Battle::Scene).
  module DBKSelectors
    # The focused ball line ("name, count") from the [item_id, count] entry, or the Back label.
    # param show_desc true while the panel is showing the ball's description, which is what the details key
    #   toggles: the screen paints a whole paragraph and the index does not move
    def self.ball_text(items, index, show_desc = false)
      e = (items[index] rescue nil)
      return nil unless e
      id = e.is_a?(Array) ? e[0] : e
      item = (GameData::Item.try_get(id) rescue nil)
      return PokeAccess::I18n.t(:dbk_back) unless item
      n = e.is_a?(Array) ? e[1] : nil
      line = n ? PokeAccess::I18n.t(:dbk_ball, :name => item.name, :n => n) : item.name.to_s
      return line unless show_desc
      d = (item.description rescue nil)
      (d && !d.to_s.empty?) ? "#{line}. #{PokeAccess.clean(d.to_s)}" : line
    rescue StandardError
      nil
    end

    # The focused battler line ("name, owner's") for the selection grid, rebuilt the way the plugin lays the
    # grid out (own side, then the other side reversed), so idxSide/idxPoke map to the same battler.
    def self.battler_text(scene, idxSide, idxPoke)
      battle = PokeAccess.ivar(scene, :@battle)
      return nil unless battle
      sides = [(battle.allSameSideBattlers rescue []),
               (battle.allOtherSideBattlers.reverse rescue [])]
      b = (sides[idxSide][idxPoke] rescue nil)
      return nil unless b
      pk = (b.displayPokemon rescue (b.pokemon rescue nil))
      nm = (pk.name rescue (b.name rescue nil))
      return nil unless nm && !nm.to_s.empty?
      owner = (battle.pbGetOwnerFromBattlerIndex(b.index).name rescue nil)
      (owner && !owner.to_s.empty?) ? PokeAccess::I18n.t(:dbk_owner, :name => nm, :owner => owner) : nm.to_s
    rescue StandardError
      nil
    end
  end
end

# Poke Ball selector: pbUpdateBallSelection(items, index, showDesc) redraws on open and on each left/right
# move; read the focused ball. The dedup ivar lives on the battle-long Scene, so reset it when the selector
# (re)opens, or reopening on the same index would stay mute.
#
# The key is [index, showDesc], not the index alone: the details key toggles a full description panel open
# and shut WITHOUT moving the cursor, so an index-only key never noticed that the screen had changed.
PokeAccess::Hooks.before_hook("Battle::Scene", :pbSelectBallInfo, :optional => true) do |scene, _a|
  PokeAccess::Cursor.reset(scene, :dbk_ball)
end
PokeAccess::Hooks.after_hook("Battle::Scene", :pbUpdateBallSelection, :optional => true) do |scene, _ret, args|
  PokeAccess::Cursor.announce(scene, :dbk_ball, [args[1], args[2]]) do
    PokeAccess::DBKSelectors.ball_text(args[0], args[1], args[2])
  end
end

# Battler selection grid: pbUpdateBattlerSelection(idxSide, idxPoke, select) redraws on each cursor move;
# read the highlighted battler (deduped by the [side, poke] pair). Reset on (re)open like the ball selector.
#
# BEFORE and not after, because this method is not just a redraw: called with select true, which is how the
# key opens the panel, it ends in "pbSelectBattlerInfo if select" and that IS the panel's whole modal loop.
# Hooked after, the call that opens the grid would not speak until the player closed it.
#
# Running before also settles the reentrancy question rather than working around it: a before hook does not
# put the original under the guard at all, so pbUpdateBattlerInfo, the reset below and
# pbUpdateMoveInfoWindow are never suppressed. Nothing here reads the return value, so before costs nothing.
PokeAccess::Hooks.before_hook("Battle::Scene", :pbSelectBattlerInfo, :optional => true) do |scene, _a|
  PokeAccess::Cursor.reset(scene, :dbk_bsel)
end
PokeAccess::Hooks.before_hook("Battle::Scene", :pbUpdateBattlerSelection, :optional => true) do |scene, args|
  PokeAccess::Cursor.announce(scene, :dbk_bsel, [args[0], args[1]]) do
    PokeAccess::DBKSelectors.battler_text(scene, args[0], args[1])
  end
end
