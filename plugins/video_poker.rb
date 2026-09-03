module PokeAccess
  # Video Poker: set a wager, get five cards, mark which to keep, draw, get paid; a win offers double or
  # nothing, with a face-up reference card and four face-down ones to pick from.
  #
  # Everything on this screen is painted, not windowed, so nothing reaches a reader on its own. Each of the
  # three loops is held rather than inferred: they share @hand and share the cursor while meaning different
  # things.
  module VideoPokerRead
    # The plugin's own constants (HEART 1, DIAMOND 2, CLUB 3, SPADE 4; ACE 1, JACK 11, QUEEN 12, KING 13,
    # JOKER 99), rather than positions guessed off the sprite sheet.
    SUITS = { 1 => :vp_hearts, 2 => :vp_diamonds, 3 => :vp_clubs, 4 => :vp_spades }
    FACES = { 1 => :vp_ace, 11 => :vp_jack, 12 => :vp_queen, 13 => :vp_king }
    JOKER = 99
    REFERENCE_SLOT = 0

    @mode = nil

    def self.hold(mode); @mode = mode; end
    def self.release; @mode = nil; end

    # The message window is read on every frame and not only per mode: it carries the rules of the round --
    # when to press cancel, that the next card must be higher than the reference one -- and those land while
    # no mode is held, in the scene's own confirm loop.
    def self.poll(scene)
      message(scene)
      case @mode
      when :wager then wager(scene)
      when :cards then card(scene)
      when :pick then pick(scene)
      end
    rescue StandardError
      nil
    end

    # The bet, whenever it moves, and the purse beside it.
    #
    # The purse is the scene's player_coins, not the screen's raw coins: until a hand is dealt the entry cost
    # is unpaid, and the window paints coins minus the wager.
    def self.wager(scene)
      screen = PokeAccess.ivar(scene, :@screen)
      return unless screen
      w = (screen.wager rescue nil)
      return unless w
      c = (scene.player_coins rescue nil)
      PokeAccess::Cursor.announce(scene, :vp_wager, [w, c], true) do
        PokeAccess::Info.set_info(:text, payout_table(scene, w))
        line = PokeAccess::I18n.t(:vp_wager, :n => w.to_i)
        c ? "#{line}. #{PokeAccess::I18n.t(:vp_coins, :n => c.to_i)}" : line
      end
    end

    # The payout table for the info key: every combination, what it pays and what makes it. Rebuilt per
    # wager, because each row is wager times bonus, which is what the window paints.
    # return the table as one string, or nil when the scene has no combination list
    def self.payout_table(scene, wager)
      list = PokeAccess.ivar(scene, :@combination_array)
      return nil unless list.is_a?(Array) && !list.empty?
      w = (wager || 1).to_i
      w = 1 if w < 1
      rows = list.map do |c|
        nm = PokeAccess.clean((c.name rescue "").to_s).to_s.strip
        next nil if nm.empty?
        d = PokeAccess.clean((c.description rescue "").to_s).to_s.strip
        row = PokeAccess::I18n.t(:vp_payout_row, :name => nm, :n => (c.bonus rescue 0).to_i * w)
        d.empty? ? row : "#{row}, #{d}"
      end
      rows = rows.compact
      rows.empty? ? nil : rows.join(". ")
    rescue StandardError
      nil
    end

    # The focused card and whether it is being kept. The Hold/Draw wording comes from the scene's own
    # current_label_text, so it matches what is printed under the card.
    def self.card(scene)
      hand = PokeAccess.ivar(scene, :@hand)
      i = cursor_index(scene)
      return unless hand.is_a?(Array) && i && hand[i]
      state = label(scene, i)
      PokeAccess::Cursor.announce(scene, :vp_card, [i, state], true) { card_text(hand[i], state) }
    end

    # Double or nothing: the position only. A face-down card is nil in @hand, which is the same flag the
    # scene uses to draw the back, so naming one would reveal a card the screen hides.
    def self.pick(scene)
      i = cursor_index(scene)
      return unless i
      hand = PokeAccess.ivar(scene, :@hand)
      total = hand.is_a?(Array) ? hand.length - 1 : 0
      PokeAccess::Cursor.announce(scene, :vp_pick, i, true) do
        PokeAccess::I18n.t(:vp_pick, :n => i, :tot => total)
      end
    end

    # The reference card, said once as the double-or-nothing round opens; it does not change while the
    # cursor moves.
    def self.reference(scene)
      hand = PokeAccess.ivar(scene, :@hand)
      c = hand.is_a?(Array) ? hand[REFERENCE_SLOT] : nil
      return unless c
      PokeAccess.speak(PokeAccess::I18n.t(:vp_reference, :card => card_text(c, "")), true)
    rescue StandardError
      nil
    end

    # The message window's line, plus the winning combination while the payout table highlights it -- the
    # message never names the combination and the table is where it appears.
    def self.message_text(scene)
      win = PokeAccess.sprite(scene, "message_window")
      t = PokeAccess.clean((win.text rescue "").to_s).to_s.strip if win
      return nil if t.nil? || t.empty?
      c = combination(scene)
      c ? "#{t}. #{c}" : t
    rescue StandardError
      nil
    end

    # Whatever the window is showing, queued, once per change.
    def self.message(scene)
      t = message_text(scene)
      PokeAccess::Cursor.announce(scene, :vp_msg, t, false) { t } if t
    rescue StandardError
      nil
    end

    # What the round paid. Interrupting, and through the same slot as the frame read, so the two cannot say
    # the same line twice.
    def self.result(scene)
      t = message_text(scene)
      PokeAccess::Cursor.announce(scene, :vp_msg, t, true) { t } if t
    rescue StandardError
      nil
    end

    # The winning combination's name while the payout table is highlighting it, else nil. Both conditions
    # are the scene's own: it draws the highlight only when it has a combination and the flag is up.
    def self.combination(scene)
      return nil unless PokeAccess.ivar(scene, :@highlight_combination)
      nm = (PokeAccess.ivar(scene, :@screen).combination_found.combination.name rescue nil)
      return nil if nm.nil? || nm.to_s.empty?
      PokeAccess.clean(nm.to_s).to_s.strip
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
  PokeAccess::Cursor.reset(scene, :vp_wager)
  begin; nxt.call; ensure; PokeAccess::VideoPokerRead.release; end
end

# Both select loops put the cursor back to its starting slot on entry, and the scene lives for the whole
# session, so the dedup slot has to be cleared each time or a round that ended where the next one begins
# opens in silence over a brand new hand.
PokeAccess::Hooks.around_hook("VideoPoker::Scene", :cursor_loop, :optional => true) do |scene, nxt, _a|
  PokeAccess::VideoPokerRead.hold(:cards)
  PokeAccess::Cursor.reset(scene, :vp_card)
  begin; nxt.call; ensure; PokeAccess::VideoPokerRead.release; end
end

PokeAccess::Hooks.around_hook("VideoPoker::Scene", :double_or_nothing_cursor_select, :optional => true) do |scene, nxt, _a|
  PokeAccess::VideoPokerRead.hold(:pick)
  PokeAccess::Cursor.reset(scene, :vp_pick)
  PokeAccess::VideoPokerRead.reference(scene)
  begin; nxt.call; ensure; PokeAccess::VideoPokerRead.release; end
end

# The result of the round. It lands on a frame with no mode held (the scene is in its confirm loop), so the
# per-frame poll below cannot see it.
["show_result", "show_result_as_draw"].each do |meth|
  PokeAccess::Hooks.after_hook("VideoPoker::Scene", meth.to_sym, :optional => true) do |scene, _r, _a|
    PokeAccess::VideoPokerRead.result(scene)
  end
end

# update_all is the one call all three loops make every frame, so one poll serves them all.
PokeAccess::Hooks.after_hook("VideoPoker::Scene", :update_all, :optional => true) do |scene, _r, _a|
  PokeAccess::VideoPokerRead.poll(scene)
end

# The pay table lives on the info key while playing. main_loop is the whole session -- the VideoPoker::Screen
# loop that is only left by leaving the machine -- so it is released on the way back from it: otherwise the
# info key keeps reciting poker hands out on the map.
PokeAccess::Hooks.around_hook("VideoPoker::Screen", :main_loop, :optional => true) do |_s, nxt, _a|
  begin; nxt.call; ensure; PokeAccess::Info.clear_text; end
end
