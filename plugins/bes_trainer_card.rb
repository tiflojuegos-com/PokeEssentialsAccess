# Yuko115 and Pablus94's Custom Trainer Card (BES, TrainerCard#dorso1 the front and #dorso2 the back, a blocking loop
# each): every face is read once as it opens, from the text it paints and its stars or badges; C turns it to the other.
module PokeAccess
  module BesTrainerCard
    TAG = :bes_card
    STARS_VARIABLE = 18
    MAX_STARS = 5
    BADGE_SLOTS = 8
    @faces = []

    # Runs one face's loop with its paint armed, for the pulse to read once it has landed. Turning the card calls the
    # other face inside this one, so the depth of the stack tells the card opening from a turn.
    def self.face(kind)
      @faces.push(kind)
      PokeAccess::PaintCapture.arm(TAG)
      yield
    ensure
      @faces.pop
      PokeAccess::PaintCapture.take_pairs(TAG)
    end

    # The stars the front draws, from the game variable the script lights them by; none outside the five it draws.
    def self.stars_line
      n = ($game_variables[STARS_VARIABLE] rescue 0).to_i
      return unless n >= 1 && n <= MAX_STARS
      PokeAccess::I18n.t(:stars_count, :n => n)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The badges the back shows: how many of the trainer's first eight, the ones the script draws a medal for.
    def self.badges_line
      badges = $Trainer.badges
      n = (0...BADGE_SLOTS).select { |i| badges[i] }.length
      PokeAccess::I18n.t(:tr_badges, :n => n)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A face's text: its stars or badges, then what it painted in reading order, each label joined to its value.
    def self.face_text(kind, pairs)
      rows = PokeAccess::PaintCapture.pair_labels(PokeAccess::PaintCapture.laid_out(pairs))
      lines = PokeAccess::KeyHints.gate(rows).map { |l| PokeAccess::KeyHints.localize(l, nil, true) }
      extra = (kind == :front) ? stars_line : badges_line
      PokeAccess.sentences([extra, PokeAccess::PaintCapture.text(lines, false)])
    end

    # Each frame of the loop: speaks the face whose paint has landed, once. The card opening is queued behind what
    # came before it; a turn interrupts.
    def self.flush
      kind = @faces.last
      return unless kind && PokeAccess::PaintCapture.pending?(TAG)
      PokeAccess.speak(face_text(kind, PokeAccess::PaintCapture.take_pairs(TAG)), @faces.length > 1)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Hooks.around_hook("TrainerCard", :dorso1, :optional => true) do |_card, nxt, _a|
  PokeAccess::BesTrainerCard.face(:front) { nxt.call }
end
PokeAccess::Hooks.around_hook("TrainerCard", :dorso2, :optional => true) do |_card, nxt, _a|
  PokeAccess::BesTrainerCard.face(:back) { nxt.call }
end
PokeAccess::Frame.each_pulse { PokeAccess::BesTrainerCard.flush }
