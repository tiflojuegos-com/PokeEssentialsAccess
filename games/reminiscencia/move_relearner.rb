# Reminiscencia's custom move relearner (MoveRelearnerScene, defined by the game in
# games_src/reminiscencia/Data/export/1740 MoveRelearner.rb) draws the focused move's extra data directly
# onto @sprites["overlay"] inside pbDrawMoveList instead of writing it into a standard text window.
#
# The visible list itself is a Window_CommandPokemon in @sprites["commands"], so the core command-window
# reader already voices the focused move NAME when the player moves with the arrows. The problem is the
# info key (T): because this scene never publishes its own info context, T keeps reading the PREVIOUS
# context left by the Pokemon picker (the selected Pokemon), not the focused move's detail.
#
# The game computes and redraws every relevant field inside MoveRelearnerScene#pbDrawMoveList:
#   - the focused move id lives in @moves[@sprites["commands"].index]
#   - type, power and accuracy come from PBMoveData.new(move_id)
#   - the description comes from pbGetMessage(MessageTypes::MoveDescriptions, move_id)
#     (reached here through the mod's engine-agnostic Data adapter / MoveInfo formatter)
#   - the Heart Scale cost is computed by the game's own top-level moveCost(category, basedamage, id)
#
# Patch technique: hook AFTER pbDrawMoveList and publish a ready spoken line to PokeAccess::Info as :text.
# This keeps T on the focused move and, for this game, OVERRIDES the core gen-6 relearner reader (a
# declared Hooks.override, listed by the diag -- not a silent module reopen) so arrow navigation speaks
# only the move name, leaving the full detail for T.
module PokeAccess
  module ReminMoveRelearner
    # The move id currently focused by the custom relearner list, or nil.
    def self.focused_id(scene)
      moves = PokeAccess.ivar(scene, :@moves)
      win = PokeAccess.sprite(scene, "commands")
      idx = (win.index rescue nil)
      return nil unless moves.is_a?(Array) && idx && idx >= 0 && idx < moves.length
      moves[idx]
    rescue StandardError
      nil
    end

    # The full line the info key should read for the focused move: name, type, power, accuracy,
    # description and this game's Heart Scale cost.
    def self.detail_text(scene)
      move_id = focused_id(scene)
      return nil if move_id.nil?
      base = PokeAccess::MoveInfo.by_id_via_data(move_id)
      return nil if base.nil? || base.to_s.empty?
      movedata = (PBMoveData.new(move_id) rescue nil)
      return base unless movedata
      cost = (scene.send(:moveCost, movedata.category, movedata.basedamage, move_id) rescue nil)
      return base if cost.nil?
      item = PokeAccess::I18n.t(:rem_heartscale_name)
      cost_text = PokeAccess::I18n.t(:rem_heartscale_cost, :n => cost, :item => item)
      "#{base} #{cost_text}"
    rescue StandardError
      nil
    end

    # Publishes the focused move detail so the info key reads this menu instead of the previous screen.
    def self.sync_info(scene)
      text = detail_text(scene)
      return if text.nil? || text.to_s.empty?
      PokeAccess::Info.set_info(:text, text)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("reminiscencia") do
  override(PokeAccess::MoveRelearnerGen6, :detail) do |_mod, _original, args|
    scene = args[0]
    id = (PokeAccess::MoveRelearnerGen6.focused_id(scene) rescue nil)
    if id
      name = (PokeAccess::Data.move_name(id) rescue nil)
      PokeAccess.speak(name.to_s, true) if name && !name.to_s.empty?
    end
  end

  after("MoveRelearnerScene", :pbDrawMoveList) do |scene, _result, _args|
    PokeAccess::ReminMoveRelearner.sync_info(scene)
  end
end