# Reminiscencia's move relearner (MoveRelearnerScene): an override of the core gen-6 reader says the focused row
# with its Heart Scale cost (the scales in hand on opening), and pbDrawMoveList publishes the move's detail.
module PokeAccess
  module ReminMoveRelearner
    # The move id focused in the relearner list, or nil (the shared MoveList traversal).
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

    # The Heart Scales a move costs here, as its row writes it under the name, or nil.
    def self.cost(scene, move_id)
      movedata = (PBMoveData.new(move_id) rescue nil)
      movedata ? (scene.send(:moveCost, movedata.category, movedata.basedamage, move_id) rescue nil) : nil
    end

    # The focused row: the move and, from the learn move reading's medium level, its cost; the first one after the
    # screen opens comes after the Heart Scales in hand.
    def self.row_text(scene, move_id)
      name = (PokeAccess::Data.move_name(move_id) rescue nil).to_s
      c = PokeAccess::Verbosity.keep?(:learn_move, :medium) ? cost(scene, move_id) : nil
      line = c ? "#{name}, #{PokeAccess::I18n.t(:rem_heartscale_cost, :n => c, :item => PokeAccess::I18n.t(:rem_heartscale_name))}" : name
      return line if PokeAccess.ivar(scene, :@access_rem_opened)
      scene.instance_variable_set(:@access_rem_opened, true)
      have = ($PokemonBag.pbQuantity(:HEARTSCALE) rescue nil)
      have ? "#{PokeAccess::I18n.t(:rem_scales, :n => have)}. #{line}" : line
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
      first = !PokeAccess.ivar(scene, :@access_rem_opened)
      PokeAccess.speak(PokeAccess::ReminMoveRelearner.row_text(scene, id), !first)
    end
  end

  after("MoveRelearnerScene", :pbDrawMoveList) do |scene, _result, _args|
    PokeAccess::ReminMoveRelearner.sync_info(scene)
  end
end
