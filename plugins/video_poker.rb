module PokeAccess
  # Video Poker, all painted: the wager, the five cards to keep or draw, and double or nothing (a face-up reference
  # card, four face-down to pick). The three loops share @hand and the cursor, so the one running is held (hold).
  module VideoPokerRead
    # Suit and face values as the plugin's own constants number them.
    SUITS = { 1 => :vp_hearts, 2 => :vp_diamonds, 3 => :vp_clubs, 4 => :vp_spades }
    FACES = { 1 => :vp_ace, 11 => :vp_jack, 12 => :vp_queen, 13 => :vp_king }
    JOKER = 99
    REFERENCE_SLOT = 0

    @mode = nil

    def self.hold(mode); @mode = mode; end
    def self.release; @mode = nil; end

    # Each frame: the message window, even with no loop held (the round's rules land in the confirm loop), then the
    # held loop's focus.
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

    # The bet whenever it moves, and the purse beside it as painted: the scene's player_coins (coins less the unpaid
    # wager), not the screen's raw coins.
    def self.wager(scene)
      screen = PokeAccess.ivar(scene, :@screen)
      return unless screen
      w = (screen.wager rescue nil)
      return unless w
      c = (scene.player_coins rescue nil)
      PokeAccess::Cursor.announce(scene, :vp_wager, [w, c], true, false) do
        PokeAccess::Info.set_info(:text, payout_table(scene, w))
        line = PokeAccess::I18n.t(:vp_wager, :n => w.to_i)
        c ? "#{line}. #{PokeAccess::I18n.t(:vp_coins, :n => c.to_i)}" : line
      end
    end

    # The payout table for the info key, as one string: every combination, what it pays at this wager (bonus times
    # wager, as painted) and what makes it; nil with no combination list.
    def self.payout_table(scene, wager)
      list = PokeAccess.ivar(scene, :@combination_array)
      return nil unless list.is_a?(Array) && !list.empty?
      w = (wager || 1).to_i
      w = 1 if w < 1
      rows = list.map do |c|
        nm = PokeAccess.clean((c.name rescue "").to_s)
        next nil if nm.empty?
        d = PokeAccess.clean((c.description rescue "").to_s)
        row = PokeAccess::I18n.t(:vp_payout_row, :name => nm, :n => (c.bonus rescue 0).to_i * w)
        d.empty? ? row : "#{row}, #{d}"
      end
      rows = rows.compact
      rows.empty? ? nil : rows.join(". ")
    rescue StandardError
      nil
    end

    # The focused card, whether it is being kept, and whether it flashes as part of the combination found. The
    # Hold/Draw wording comes from the scene's own current_label_text, so it matches what is printed under the card.
    def self.card(scene)
      hand = PokeAccess.ivar(scene, :@hand)
      i = cursor_index(scene)
      return unless hand.is_a?(Array) && i && hand[i]
      state = label(scene, i)
      combo = flashing?(scene, i)
      PokeAccess::Cursor.announce(scene, :vp_card, [i, state, combo], true, false) do
        t = card_text(hand[i], state)
        combo ? "#{t}, #{PokeAccess::I18n.t(:vp_in_combo)}" : t
      end
    end

    # Whether a card flashes while cards are picked: the combination found is highlighted, the game flashes its
    # cards (FLASH_CARDS) and this card is one of them.
    def self.flashing?(scene, i)
      return false unless PokeAccess.ivar(scene, :@highlight_combination)
      flash = PokeAccess.const_at("VideoPoker::FLASH_CARDS")
      return false if flash == false
      (PokeAccess.ivar(scene, :@screen).hand_card_in_combination?(i) rescue false) ? true : false
    end

    # Double or nothing: the cursor's position only, as the screen hides the face-down cards.
    def self.pick(scene)
      i = cursor_index(scene)
      return unless i
      hand = PokeAccess.ivar(scene, :@hand)
      total = hand.is_a?(Array) ? hand.length - 1 : 0
      PokeAccess::Cursor.announce(scene, :vp_pick, i, true, false) do
        PokeAccess::I18n.t(:vp_pick, :n => i, :tot => total)
      end
    end

    # The reference card, once as the double-or-nothing round opens; queued, so it does not cut the round's result or
    # the new message line.
    def self.reference(scene)
      hand = PokeAccess.ivar(scene, :@hand)
      c = hand.is_a?(Array) ? hand[REFERENCE_SLOT] : nil
      return unless c
      PokeAccess.speak(PokeAccess::I18n.t(:vp_reference, :card => card_text(c, "")), false)
    rescue StandardError
      nil
    end

    # The message window's line, plus the winning combination while the payout table highlights it.
    def self.message_text(scene)
      win = PokeAccess.sprite(scene, "message_window")
      t = PokeAccess.clean((win.text rescue "").to_s) if win
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

    # What the round paid, interrupting, through the frame read's dedup slot.
    def self.result(scene)
      t = message_text(scene)
      PokeAccess::Cursor.announce(scene, :vp_msg, t, true) { t } if t
    rescue StandardError
      nil
    end

    # The winning combination's name while the payout table highlights it (@highlight_combination), else nil.
    def self.combination(scene)
      return nil unless PokeAccess.ivar(scene, :@highlight_combination)
      nm = (PokeAccess.ivar(scene, :@screen).combination_found.combination.name rescue nil)
      return nil if nm.nil? || nm.to_s.empty?
      PokeAccess.clean(nm.to_s)
    rescue StandardError
      nil
    end

    def self.cursor_index(scene)
      cur = PokeAccess.ivar(scene, :@cursor)
      i = (cur.index rescue nil)
      i.is_a?(Integer) ? i : nil
    end

    def self.label(scene, i)
      PokeAccess.clean((scene.current_label_text(i) rescue "").to_s)
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

# Each loop clears its dedup slot on entry: the cursor starts again on the same slot, over a new hand.
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

# The round's result, interrupting, as the scene shows it.
["show_result", "show_result_as_draw"].each do |meth|
  PokeAccess::Hooks.after_hook("VideoPoker::Scene", meth.to_sym, :optional => true) do |scene, _r, _a|
    PokeAccess::VideoPokerRead.result(scene)
  end
end

# update_all is the one call all three loops make every frame, so one poll serves them all.
PokeAccess::Hooks.after_hook("VideoPoker::Scene", :update_all, :optional => true) do |scene, _r, _a|
  PokeAccess::VideoPokerRead.poll(scene)
end

# The pay table sits on the info key while playing: published once the wager is settled (the slider or a fixed
# wager's yes/no), cleared when main_loop, the whole session at the machine, returns.
PokeAccess::Hooks.after_hook("VideoPoker::Screen", :select_wager, :optional => true) do |screen, ret, _a|
  scene = PokeAccess.ivar(screen, :@scene)
  if ret && scene
    PokeAccess::Info.set_info(:text, PokeAccess::VideoPokerRead.payout_table(scene, (screen.wager rescue nil)))
  end
end

PokeAccess::Hooks.around_hook("VideoPoker::Screen", :main_loop, :optional => true) do |_s, nxt, _a|
  begin; nxt.call; ensure; PokeAccess::Info.clear_text; end
end
