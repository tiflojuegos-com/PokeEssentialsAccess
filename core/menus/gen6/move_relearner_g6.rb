# Gen-6 Move Relearner (MoveRelearnerScene; the modern MoveRelearner_Scene is menus/v21's): speaks the focused move's
# detail on each pbDrawMoveList, or on each pbRefreshInfo in the older screen (Insurgence, Uranium), and the list
# again when a declined question returns to it.
module PokeAccess
  module MoveRelearnerGen6
    # The move id under the focused row (MoveList unwraps BetterMoveRelearner's [id, tag] pairs).
    def self.focused_id(scene)
      PokeAccess::MoveList.focused_id(scene)
    end

    # Speaks the focused move's detail at the learn move reading's level, with its row's tag (Pokemon Z's "MT") in
    # front from medium; the info key keeps it whole.
    def self.detail(scene)
      id = focused_id(scene)
      return if id.nil?
      tag = PokeAccess::MoveList.focused_tag(scene)
      full = PokeAccess::MoveInfo.by_id_via_data(id)
      PokeAccess::Info.set_info(:text, tag.empty? || full.nil? ? full : "#{tag}. #{full}")
      s = PokeAccess::MoveInfo.by_id_via_data(id, :learn_move)
      tag = "" unless PokeAccess::Verbosity.keep?(:learn_move, :medium)
      PokeAccess.speak(tag.empty? || s.nil? ? s : "#{tag}. #{s}", true)
    rescue StandardError
      nil
    end

    # The list the generic reader would read: the older screen's "list", the stock screen's "commands".
    def self.list_sprite(scene)
      PokeAccess.sprite(scene, scene.respond_to?(:pbRefreshInfo) ? "list" : "commands")
    end

    # The older screen's focused row: the move's data at the learn move reading's level (the info key keeps it
    # whole), or the list's own caption for CANCEL (move 0).
    def self.row_text(scene, move)
      if move.to_i > 0
        PokeAccess::Info.set_info(:text, PokeAccess::MoveInfo.by_id_via_data(move))
        return PokeAccess::MoveInfo.by_id_via_data(move, :learn_move)
      end
      list = PokeAccess.sprite(scene, "list")
      list ? PokeAccess::Menus.focused_text(list) : nil
    rescue StandardError
      nil
    end

    # Says the row the older screen's pbRefreshInfo just painted; the first time, queued after the screen's own
    # question.
    def self.refreshed(scene, move)
      text = row_text(scene, move)
      return if text.nil? || text.to_s.empty?
      first = !PokeAccess.ivar(scene, :@access_relearn_asked)
      if first
        scene.instance_variable_set(:@access_relearn_asked, true)
        ask = (PokeAccess.sprite(scene, "msgwindow").text rescue nil)
        text = PokeAccess.sentences([PokeAccess.clean(ask.to_s), text])
      end
      PokeAccess.speak_clean(text, !first, :menu)
    rescue StandardError
      nil
    end

    # The scene class to hook, or "" where this reader does not apply: with both names present (a fork declaring
    # MoveRelearnerScene as an empty subclass of MoveRelearner_Scene), it binds only on a gen-6 engine.
    # Counts the entries to the choice loop (pbChooseMove); from the second on, back from a declined question, which
    # neither redraws nor reads anything, the loop's first update says the list again.
    def self.choosing(scene)
      n = PokeAccess.ivar(scene, :@access_relearn_entries).to_i + 1
      scene.instance_variable_set(:@access_relearn_entries, n)
      scene.instance_variable_set(:@access_relearn_again, true) if n > 1
    end

    # The first update of a re-entered choice loop, queued: the older screen's question and focused row, or the
    # stock screen's focused move.
    def self.again(scene)
      return unless PokeAccess.ivar(scene, :@access_relearn_again)
      scene.instance_variable_set(:@access_relearn_again, false)
      return detail(scene) unless scene.respond_to?(:pbRefreshInfo)
      list = PokeAccess.sprite(scene, "list")
      moves = PokeAccess.ivar(scene, :@moves)
      row = (list && moves.is_a?(Array)) ? row_text(scene, moves[list.index]).to_s : nil
      ask = (PokeAccess.sprite(scene, "msgwindow").text rescue nil)
      text = PokeAccess.sentences([PokeAccess.clean(ask.to_s), row])
      PokeAccess.speak_clean(text, false, :menu) unless text.empty?
    rescue StandardError
      nil
    end

    SCENE = PokeAccess::Engine.era_scene(:gen6, "MoveRelearnerScene", "MoveRelearner_Scene")
  end
end

# Mutes the list's generic read with the mod's own flag (@ignore_input would freeze the gen-6 cursor). A container:
# pbStartScene calls pbDrawMoveList (pbRefreshInfo in the older screen), whose hook speaks the opening read.
PokeAccess::Hooks.after_hook(PokeAccess::MoveRelearnerGen6::SCENE, :pbStartScene, :hook_container => true) do |scene, _r, _a|
  PokeAccess.dedicate(PokeAccess::MoveRelearnerGen6.list_sprite(scene))
end
PokeAccess::Hooks.after_hook(PokeAccess::MoveRelearnerGen6::SCENE, :pbDrawMoveList, :optional => true) do |scene, _r, _a|
  PokeAccess::MoveRelearnerGen6.detail(scene)
end
PokeAccess::Hooks.after_hook(PokeAccess::MoveRelearnerGen6::SCENE, :pbRefreshInfo, :optional => true) do |scene, _r, args|
  PokeAccess::MoveRelearnerGen6.refreshed(scene, args[0])
end
PokeAccess::Hooks.before_hook(PokeAccess::MoveRelearnerGen6::SCENE, :pbChooseMove, :optional => true) do |scene, _a|
  PokeAccess::MoveRelearnerGen6.choosing(scene)
end
PokeAccess::Hooks.after_hook(PokeAccess::MoveRelearnerGen6::SCENE, :pbUpdate, :optional => true,
                             :hook_container => true) do |scene, _r, _a|
  PokeAccess::MoveRelearnerGen6.again(scene)
end
