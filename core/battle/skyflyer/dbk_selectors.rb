module PokeAccess
  # DBK Enhanced Battle UI in-battle SELECTORS (sprite cursors, no command window, so the generic hook
  # cannot see them). Two screens sit on the action path: the Poke Ball picker (which ball to throw) and the
  # battler-selection grid (which battler to inspect). The detail panel that opens AFTER picking a battler is
  # read by dbk_battlerinfo; here we read the CURSOR as it moves. Gated by method existence so only DBK games
  # bind, and no-op on gen-6 (no Battle::Scene).
  module DBKSelectors
    # The focused ball line ("name, count") from the [item_id, count] entry, or the Back label.
    def self.ball_text(items, index)
      e = (items[index] rescue nil)
      return nil unless e
      id = e.is_a?(Array) ? e[0] : e
      item = (GameData::Item.try_get(id) rescue nil)
      return PokeAccess::I18n.t(:dbk_back) unless item
      n = e.is_a?(Array) ? e[1] : nil
      n ? PokeAccess::I18n.t(:dbk_ball, :name => item.name, :n => n) : item.name
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
# move; read the focused ball (deduped by index). The dedup ivar lives on the battle-long Scene, so reset
# it when the selector (re)opens, or reopening on the same index would stay mute.
PokeAccess::Hooks.before_hook("Battle::Scene", :pbSelectBallInfo, :optional => true) do |scene, _a|
  scene.instance_variable_set(:@access_ball_idx, nil)
end
PokeAccess::Hooks.after_hook("Battle::Scene", :pbUpdateBallSelection, :optional => true) do |scene, _ret, args|
  items = args[0]; index = args[1]
  if index != PokeAccess.ivar(scene, :@access_ball_idx)
    scene.instance_variable_set(:@access_ball_idx, index)
    t = PokeAccess::DBKSelectors.ball_text(items, index)
    PokeAccess.speak(t, true) if t && !t.to_s.empty?
  end
end

# Battler selection grid: pbUpdateBattlerSelection(idxSide, idxPoke, select) redraws on each cursor move;
# read the highlighted battler (deduped by the [side, poke] pair). Reset on (re)open like the ball selector.
PokeAccess::Hooks.before_hook("Battle::Scene", :pbSelectBattlerInfo, :optional => true) do |scene, _a|
  scene.instance_variable_set(:@access_bsel, nil)
end
PokeAccess::Hooks.after_hook("Battle::Scene", :pbUpdateBattlerSelection, :optional => true) do |scene, _ret, args|
  key = [args[0], args[1]]
  if key != PokeAccess.ivar(scene, :@access_bsel)
    scene.instance_variable_set(:@access_bsel, key)
    t = PokeAccess::DBKSelectors.battler_text(scene, args[0], args[1])
    PokeAccess.speak(t, true) if t && !t.to_s.empty?
  end
end
