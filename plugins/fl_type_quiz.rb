# FL's Type Quiz (TypeQuiz::Scene, also the Pokenav Definitivo's copy): the question is type pictures with no text; a new
# question says its types and the focused answer, each cursor step the answer under it, each pick the result the screen paints.
module PokeAccess
  module FLTypeQuiz
    @asking = false

    # Runs the block while the scene sets a question up: the cursor and repaint calls inside it are said by the question's
    # own reading.
    def self.asking
      @asking = true
      yield
    ensure
      @asking = false
    end

    # A type's name from the game's data: the quiz lists types by symbol, which the gen-6 tables know by the number getID
    # gives them, as the quiz paints and answers by it; the symbol itself where the data names none.
    def self.type_name(type)
      id = PokeAccess::Engine.gen6? ? (getID(PBTypes, type) rescue nil) : type
      name = id.nil? ? nil : PokeAccess::Data.type_name(id)
      name.nil? || name.to_s.empty? ? type.to_s : name.to_s
    end

    # The current question: the attacking type against the defending one or two.
    def self.matchup(scene)
      q = PokeAccess.ivar(scene, :@question)
      return nil unless q
      defense = PokeAccess::Util.types_phrase(type_name(q.defense1_type), type_name(q.defense2_type))
      PokeAccess::I18n.t(:tquiz_matchup, :attack => type_name(q.attack_type), :defense => defense)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The answers the screen lists, as the game words them.
    def self.answers
      list = PokeAccess.const_at("TypeQuiz::Question::ANSWERS")
      list.is_a?(Array) ? list : []
    end

    # The answer under the cursor with its place in the list.
    def self.focus(scene)
      index = PokeAccess.ivar(scene, :@index)
      list = answers
      return nil unless index.is_a?(Integer) && index >= 0 && list[index]
      PokeAccess::I18n.t(:list_entry, :name => PokeAccess.clean(list[index]), :n => index + 1, :tot => list.length)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The result the screen paints in its middle after an answer; nil while it paints none.
    def self.label(scene)
      t = PokeAccess.clean(PokeAccess.ivar(scene, :@answer_label).to_s)
      t.empty? ? nil : t
    end

    # The painted top line, the score and the question count in screen order, less the result between them.
    def self.status(scene, pairs)
      rows = (pairs || []).select { |r| r[2].is_a?(Numeric) && r[3].is_a?(Numeric) }
      top = rows.map { |r| r[3] }.min
      shown = rows.select { |r| r[3] == top }.sort_by { |r| r[2] }.map { |r| PokeAccess.clean(r[0]) }
      PokeAccess.sentences(shown.reject { |t| t == label(scene) })
    end

    # The wording of the answer the question has.
    def self.right_answer(scene)
      q = PokeAccess.ivar(scene, :@question)
      text = q ? answers[q.result] : nil
      text ? PokeAccess::I18n.t(:tquiz_right, :answer => PokeAccess.clean(text)) : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Says the result once per question, cutting in; after a miss the game moves the cursor to the right answer, which is
    # said with it.
    def self.result(scene, revealed)
      text = label(scene)
      key = [PokeAccess.ivar(scene, :@questions_count), text]
      return unless text && PokeAccess::Cursor.changed?(scene, :tquiz_result, key)
      PokeAccess.speak(PokeAccess.sentences([text, revealed ? right_answer(scene) : nil]), true)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # After every repaint: the question and the painted status on the info key, and the result once it shows.
    def self.painted(scene, pairs)
      t = PokeAccess.sentences([matchup(scene), status(scene, pairs)])
      PokeAccess::Info.set_info(:text, t) unless t.empty?
      result(scene, false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # After a cursor step: the answer now focused, or, while a result shows, the game's own move to the right answer.
    def self.moved(scene)
      return if @asking
      if label(scene)
        result(scene, true)
      else
        t = focus(scene)
        PokeAccess.speak(t, true) if t
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Says a new question, queued behind the last result: its types and the answer the cursor starts on. The call past the
    # last question sets none up.
    def self.asked(scene)
      count = PokeAccess.ivar(scene, :@questions_count)
      total = PokeAccess.ivar(scene, :@questions_total)
      return unless count.is_a?(Integer) && total.is_a?(Integer) && count <= total
      PokeAccess.speak(PokeAccess.sentences([matchup(scene), focus(scene)]), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Takes the question off the info key and the result off the dedup as the screen closes.
    def self.closed(scene)
      PokeAccess::Info.clear_text
      PokeAccess::Cursor.reset(scene, :tquiz_result)
    end
  end
end

# A question is said once the scene has set it up; the repaint and the cursor calls inside next_question stay unsaid.
PokeAccess::Hooks.around_hook("TypeQuiz::Scene", :next_question, :optional => true) do |scene, nxt, _a|
  r = nil
  PokeAccess::FLTypeQuiz.asking { r = nxt.call }
  PokeAccess::FLTypeQuiz.asked(scene)
  r
end

# Every repaint is sampled for its status line and the result; the question itself is only pictures.
PokeAccess::Hooks.around_hook("TypeQuiz::Scene", :refresh, :optional => true) do |scene, nxt, _a|
  r = nil
  pairs = PokeAccess::PaintCapture.sample { r = nxt.call }
  PokeAccess::FLTypeQuiz.painted(scene, pairs)
  r
end

# The cursor moves with the player's keys, and once more to the right answer after a miss.
PokeAccess::Hooks.around_hook("TypeQuiz::Scene", :update_cursor, :optional => true) do |scene, nxt, _a|
  r = nxt.call
  PokeAccess::FLTypeQuiz.moved(scene)
  r
end

PokeAccess::Hooks.before_hook("TypeQuiz::Scene", :end_scene, :optional => true) { |scene, _a| PokeAccess::FLTypeQuiz.closed(scene) }
