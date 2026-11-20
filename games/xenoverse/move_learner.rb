module PokeAccess
  # The move relearner and the Virtual Move Tutor (0229_NewMovelearner, MoveRelearnerScene): a list of move bars
  # (@pastmoves) whose cursor is local to pbChooseMove, so each move is read as drawMoveInfo paints its data; and its own
  # Yes/No box (pbConfirm, whose question the core says), whose choice is local too and shows only as the chosen
  # button's bounce.
  module XenoverseMoveLearner
    YES_REST = 226
    NO_REST = 266

    # Keeps the question the screen paints over the list as it opens.
    def self.started(rows)
      @question = PokeAccess.clean(rows.first.to_s)
    end

    # Says the move drawMoveInfo just painted, with its place in the list, the first time after the question.
    def self.painted(scene, index)
      moves = PokeAccess.ivar(scene, :@pastmoves)
      return unless moves.is_a?(Array) && index.is_a?(Integer) && moves[index]
      id = moves[index]
      line = PokeAccess::MoveInfo.by_id_via_data(id, :learn_move).to_s
      name = (PokeAccess::Data.move_name(id) rescue nil).to_s
      if !name.empty? && line[0, name.length] == name
        line = PokeAccess::Verbosity.list_entry(name, index + 1, moves.length) + line[name.length..-1]
      end
      PokeAccess::Info.set_info(:text, PokeAccess::MoveInfo.by_id_via_data(id))
      first = !@question.to_s.empty?
      text = first ? PokeAccess.sentences([@question, line]) : line
      @question = nil
      PokeAccess.speak(text, !first)
    end

    # Starts reading a Yes/No box.
    def self.confirming
      @confirm, @choice = true, nil
    end

    # Ends reading the Yes/No box.
    def self.confirmed
      @confirm = nil
    end

    # Says the box's first choice after its question, then each choice the cursor bounces onto.
    def self.poll(scene)
      return unless @confirm
      box = PokeAccess.ivar(scene, :@s)
      return unless box.is_a?(Hash) && box["yes"] && box["no"]
      choice = bounced(box) || @choice || :yes
      return if choice == @choice
      first = @choice.nil?
      @choice = choice
      label = PokeAccess::XenoversePainted.of_sprite(box[choice.to_s]).last.to_s
      PokeAccess.speak(label, !first)
    end

    # The button raised above its resting place, which is the one just chosen; nil while both rest.
    def self.bounced(box)
      return :no if (box["no"].y rescue NO_REST) < NO_REST
      return :yes if (box["yes"].y rescue YES_REST) < YES_REST
      nil
    end
  end
end

PokeAccess::Game.define("xenoverse") do
  on_paint("MoveRelearnerScene", :pbStartScene) do |_scene, rows, _a|
    PokeAccess::XenoverseMoveLearner.started(rows.map { |r| r[0] })
  end
  after("MoveRelearnerScene", :drawMoveInfo) { |scene, _r, args| PokeAccess::XenoverseMoveLearner.painted(scene, args[0]) }
  around("MoveRelearnerScene", :pbConfirm) do |_scene, call_next, _args|
    PokeAccess::XenoverseMoveLearner.confirming
    begin
      call_next.call
    ensure
      PokeAccess::XenoverseMoveLearner.confirmed
    end
  end
  before("MoveRelearnerScene", :pbUpdate) { |scene, _a| PokeAccess::XenoverseMoveLearner.poll(scene) }
  clear_info_on("MoveRelearnerScene", :pbEndScene)
end
