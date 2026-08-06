module PokeAccess
  # Video Poker: set a wager, get five cards, mark which ones to keep, draw, get paid. Win a round and it
  # offers double or nothing, which deals a face-up reference card and four face-down ones to pick from.
  #
  # It sits among the action minigames but it is not one. Its three loops are discrete and keep their cursor
  # in an ivar, so it reads like any other menu. What made it silent is that every single thing on screen is
  # PAINTED: the wager, the five cards, and the Hold/Draw label under each one. Nothing lands in a window a
  # reader can see.
  #
  # Which loop is running decides what to read, so each is held rather than guessed at -- during the wager
  # loop the previous round's hand is still in @hand, so "is there a hand?" would have read cards while the
  # player was choosing a bet, and the double-or-nothing loop moves the very same cursor over the very same
  # five slots as the hold loop while meaning something completely different.
  module VideoPokerRead
    # The plugin names its own constants (HEART 1, DIAMOND 2, CLUB 3, SPADE 4; ACE 1, JACK 11, QUEEN 12,
    # KING 13, JOKER 99), so the vocabulary is its own rather than guessed from sprite-sheet positions.
    SUITS = { 1 => :vp_hearts, 2 => :vp_diamonds, 3 => :vp_clubs, 4 => :vp_spades }
    FACES = { 1 => :vp_ace, 11 => :vp_jack, 12 => :vp_queen, 13 => :vp_king }
    JOKER = 99
    REFERENCE_SLOT = 0

    @mode = nil

    def self.hold(mode); @mode = mode; end
    def self.release; @mode = nil; end

    def self.poll(scene)
      case @mode
      when :wager then wager(scene)
      when :cards then card(scene)
      when :pick then pick(scene)
      end
    rescue StandardError
      nil
    end

    # The bet, whenever it moves, and what is left in the purse.
    #
    # Both belong to the screen, not the scene: the scene only ever reads them back as @screen.wager and
    # @screen.coins, which is also what it prints -- the coin total into its own window, permanently on
    # display. Without it the bet was the one number a blind player had, so there was no way to know how many
    # rounds were left, and the balance is also what moves after a win.
    def self.wager(scene)
      screen = PokeAccess.ivar(scene, :@screen)
      return unless screen
      w = (screen.wager rescue nil)
      return unless w
      c = (screen.coins rescue nil)
      PokeAccess::Cursor.announce(scene, :vp_wager, [w, c], true) do
        line = PokeAccess::I18n.t(:vp_wager, :n => w.to_i)
        c ? "#{line}. #{PokeAccess::I18n.t(:vp_coins, :n => c.to_i)}" : line
      end
    end

    # The payout table, which is a whole window of the screen and pure reference: every combination with the
    # multiplier it pays and what it takes to make it. Too long to speak on a cursor move, so it goes to the
    # info key, refreshed whenever the wager line is -- the table's own numbers scale with the bet.
    def self.payout_table(scene)
      list = PokeAccess.ivar(scene, :@combination_array)
      return nil unless list.is_a?(Array) && !list.empty?
      rows = list.map do |c|
        nm = PokeAccess.clean((c.name rescue "").to_s).to_s.strip
        next nil if nm.empty?
        d = PokeAccess.clean((c.description rescue "").to_s).to_s.strip
        row = PokeAccess::I18n.t(:vp_payout_row, :name => nm, :n => (c.bonus rescue 0).to_i)
        d.empty? ? row : "#{row}, #{d}"
      end
      rows = rows.compact
      rows.empty? ? nil : rows.join(". ")
    rescue StandardError
      nil
    end

    # The focused card and whether it is being kept. The Hold/Draw wording is the screen's own -- the scene
    # composes it in current_label_text -- so the reader says exactly what is printed under the card.
    def self.card(scene)
      hand = PokeAccess.ivar(scene, :@hand)
      i = cursor_index(scene)
      return unless hand.is_a?(Array) && i && hand[i]
      state = label(scene, i)
      PokeAccess::Cursor.announce(scene, :vp_card, [i, state], true) { card_text(hand[i], state) }
    end

    # Double or nothing: only the position can be announced, and that is the whole point of the screen. A
    # face-down card is nil in @hand -- that is the same flag the scene itself uses to decide whether to draw
    # the card or its back -- so naming one would be reading the player a card the screen is hiding.
    def self.pick(scene)
      i = cursor_index(scene)
      return unless i
      hand = PokeAccess.ivar(scene, :@hand)
      total = hand.is_a?(Array) ? hand.length - 1 : 0
      PokeAccess::Cursor.announce(scene, :vp_pick, i, true) do
        PokeAccess::I18n.t(:vp_pick, :n => i, :tot => total)
      end
    end

    # The reference card, said once as the double-or-nothing round opens: it is what the pick is measured
    # against, and it does not change while the cursor moves.
    def self.reference(scene)
      hand = PokeAccess.ivar(scene, :@hand)
      c = hand.is_a?(Array) ? hand[REFERENCE_SLOT] : nil
      return unless c
      PokeAccess.speak(PokeAccess::I18n.t(:vp_reference, :card => card_text(c, "")), true)
    rescue StandardError
      nil
    end

    # What the round paid, in the screen's own words: both result methods put their line into the message
    # window, so it is read straight from there rather than recomposed. That keeps the wording, the amount
    # and the language identical to what a sighted player sees, with nothing for this reader to get wrong.
    def self.result(scene)
      win = PokeAccess.sprite(scene, "message_window")
      t = PokeAccess.clean((win.text rescue "").to_s).to_s.strip if win
      return if t.nil? || t.empty?
      PokeAccess.speak(t, true)
    rescue StandardError
      nil
    end

    def self.cursor_index(scene)
      cur = PokeAccess.ivar(scene, :@cursor)
      i = (cur.index rescue nil)
      i.is_a?(Integer) ? i : nil
    end

    def self.label(scene, i)
      PokeAccess.clean((scene.current_label_text(i) rescue "").to_s).to_s.strip
    end

    def self.card_text(c, state)
      v = (c.value rescue nil)
      return PokeAccess::I18n.t(:vp_joker, :state => state) if v == JOKER
      face = FACES[v]
      value = face ? PokeAccess::I18n.t(face) : v.to_s
      suit = SUITS[(c.suit rescue nil)]
      return state.empty? ? value.to_s : "#{value}, #{state}" unless suit
      return PokeAccess::I18n.t(:vp_card, :value => value, :suit => PokeAccess::I18n.t(suit), :state => state) unless state.empty?
      PokeAccess::I18n.t(:vp_card_bare, :value => value, :suit => PokeAccess::I18n.t(suit))
    end
  end
end

PokeAccess::Hooks.around_hook("VideoPoker::Scene", :select_wager_loop, :optional => true) do |scene, nxt, _a|
  PokeAccess::VideoPokerRead.hold(:wager)
  PokeAccess::Info.set_info(:text, PokeAccess::VideoPokerRead.payout_table(scene))
  begin; nxt.call; ensure; PokeAccess::VideoPokerRead.release; end
end

PokeAccess::Hooks.around_hook("VideoPoker::Scene", :cursor_loop, :optional => true) do |_s, nxt, _a|
  PokeAccess::VideoPokerRead.hold(:cards)
  begin; nxt.call; ensure; PokeAccess::VideoPokerRead.release; end
end

PokeAccess::Hooks.around_hook("VideoPoker::Scene", :double_or_nothing_cursor_select, :optional => true) do |scene, nxt, _a|
  PokeAccess::VideoPokerRead.hold(:pick)
  PokeAccess::VideoPokerRead.reference(scene)
  begin; nxt.call; ensure; PokeAccess::VideoPokerRead.release; end
end

# The result of the round. It is painted into the message window from two named methods, and the frame it
# lands on has no mode held -- the scene is in its confirm loop, not in a cursor loop -- so the per-frame
# poll cannot see it. Without these the player bets, draws, and never learns whether they won.
["show_result", "show_result_as_draw"].each do |meth|
  PokeAccess::Hooks.after_hook("VideoPoker::Scene", meth.to_sym, :optional => true) do |scene, _r, _a|
    PokeAccess::VideoPokerRead.result(scene)
  end
end

# update_all is the one call all three loops make every frame, so one poll serves them all.
PokeAccess::Hooks.after_hook("VideoPoker::Scene", :update_all, :optional => true) do |scene, _r, _a|
  PokeAccess::VideoPokerRead.poll(scene)
end
