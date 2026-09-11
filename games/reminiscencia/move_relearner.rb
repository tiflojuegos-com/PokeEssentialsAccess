# Reminiscencia's custom move relearner (MoveRelearnerScene, 1740 MoveRelearner.rb) draws the focused move's
# extra data onto @sprites["overlay"] inside pbDrawMoveList. The list is a Window_CommandPokemon in
# @sprites["commands"], marked dedicated by the core relearner; the declared override at the bottom speaks
# the focused move name. The hook runs AFTER pbDrawMoveList and publishes a spoken line (type, power,
# accuracy from PBMoveData, the description through the Data adapter, the Heart Scale cost from the game's
# own moveCost) to PokeAccess::Info as :text, so the info key stays on the focused move. The core gen-6
# relearner reader is displaced by a declared Hooks.override, listed by the diag.
module PokeAccess
  module ReminMoveRelearner
    # The move id currently focused by the custom relearner list, or nil. Same shape as every other
    # hand-drawn move list, so the traversal is the shared one.
    def self.focused_id(scene)
      PokeAccess::MoveList.focused_id(scene)
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
      PokeAccess.speak(name.to_s, true)
    end
  end

  after("MoveRelearnerScene", :pbDrawMoveList) do |scene, _result, _args|
    PokeAccess::ReminMoveRelearner.sync_info(scene)
  end
end