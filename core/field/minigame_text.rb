# Triple Triad (TriadScene, same ivars in gen-6 and modern): its help-window lines, the hand, deck and board
# cursors, the opponent's moves, the score and the card shop.

# The help-window lines written through pbDisplay/pbDisplayPaused; both class names are :optional, since which one
# carries the methods varies by game.
["TriadScene", "TriadScreen"].each do |cn|
  ["pbDisplay", "pbDisplayPaused"].each do |m|
    PokeAccess::Hooks.before_hook(cn, m, :optional => true) do |_s, args|
      PokeAccess.say_dialogue(args[0])
    end
  end
end

module PokeAccess
  # Triple Triad cursors: the hand, board and opponent loops keep theirs in a local, so an around-hook holds the
  # scene and a per-frame poll mirrors the same Input.repeat? navigation. Cards and cells come from scene ivars.
  module TripleTriad
    @mode = nil
    @scene = nil
    @choice = 0
    @bx = 0
    @by = 0
    @last = nil

    # Starts mirroring the hand picker: cursor over @cardIndexes (UP/DOWN), focus is @playerCards by index.
    def self.start_hand(scene)
      push(scene)
      @mode = :hand; @scene = scene; @choice = 0; @last = nil
    end

    # Starts mirroring the board placer: cursor over the @battle grid (arrows), reads free/occupied cells.
    def self.start_board(scene)
      push(scene)
      @mode = :board; @scene = scene; @bx = 0; @by = 0; @last = nil
    end

    # Starts mirroring the opponent's hand, a loop of its own that the confirm key opens in an open-hand match.
    def self.start_opponent(scene)
      push(scene)
      @mode = :opponent; @scene = scene; @choice = 0; @last = nil
    end

    # Leaves the opponent's hand with the cursor back on the first card, as the game does, read as a move rather
    # than a loop opening.
    def self.stop_opponent
      stop
      @choice = 0; @last = :back
    end

    # Saves the outer loop's state and starts the help window afresh for the loop opening on scene: a new
    # turn's prompt is read even when it reads the same as the last turn's.
    def self.push(scene)
      (@stack ||= []).push([@mode, @scene, @choice, @bx, @by, @last, @storage])
      PokeAccess::Cursor.reset(scene, :triad_help)
    end

    def self.stop
      @mode, @scene, @choice, @bx, @by, @last, @storage =
        (@stack && @stack.pop) || [nil, nil, 0, 0, 0, nil, nil]
    end

    # Holds the scene and the card storage while the deck selector runs, for the help window and deck_row.
    def self.start_deck(scene, storage)
      push(scene)
      @mode = :deck; @scene = scene; @last = nil; @storage = storage
    end

    # The focused deck row ("Bulbasaur x3") plus the card's type and four side numbers, which only its picture
    # shows; outside the deck loop, exactly what the generic reader says.
    def self.deck_row(win, i)
      base = PokeAccess::Menus.generic_focus(win, i)
      return base unless @mode == :deck && @storage.is_a?(Array)
      e = (@storage[i] rescue nil)
      sp = e.is_a?(Array) ? e[0] : e
      return base unless sp
      card = (TriadCard.new(sp) rescue nil)
      return base unless card
      type = (PokeAccess::Data.type_name(card.type) rescue nil)
      sides = PokeAccess::I18n.t(:triad_sides, :n => num(card.north), :e => num(card.east),
                                 :s => num(card.south), :w => num(card.west))
      [base, (type ? PokeAccess::I18n.t(:mv_type, :t => type) : nil), sides].compact.join(", ")
    rescue StandardError
      (PokeAccess::Menus.generic_focus(win, i) rescue nil)
    end

    # Mirrors the active loop's navigation once per frame and speaks the focus when it changes, and reads the
    # help window whatever the loop.
    def self.poll
      return unless @scene
      poll_help
      case @mode
      when :hand     then poll_hand
      when :opponent then poll_opponent
      when :board    then poll_board
      end
    rescue StandardError
      nil
    end

    # The help window's text when it changes, for the lines the screen assigns straight to the sprite; through
    # say_dialogue, whose dedup absorbs the same line from the pbDisplay hook.
    def self.poll_help
      win = PokeAccess.sprite(@scene, "helpwindow")
      t = (win.text rescue nil)
      return if t.nil? || t.to_s.strip.empty?
      return unless PokeAccess::Cursor.changed?(@scene, :triad_help, t.to_s)
      PokeAccess.say_dialogue(t)
    rescue StandardError
      nil
    end

    # Hand picker: UP/DOWN wrap over the number of cards in hand; speak the focused card.
    def self.poll_hand
      idxs = PokeAccess.ivar(@scene, :@cardIndexes)
      n = (idxs.is_a?(Array) ? idxs.length : 0)
      return if n == 0
      move_choice(n)
      return if @choice == @last
      say_focus(card_text(hand_species(idxs[@choice])), @choice)
    end

    # Speaks the focus a loop's cursor landed on; the first of a loop is queued, the rest interrupt.
    def self.say_focus(text, focus)
      opening = @last.nil?
      @last = focus
      PokeAccess.speak(text, !opening, :menu)
    end

    # Opponent's hand, wrapped by the player's card count as the game's loop is (pbViewOpponentCards(numCards));
    # a position past the rival's last card, where the screen highlights nothing, is said as empty.
    def self.poll_opponent
      own  = PokeAccess.ivar(@scene, :@cardIndexes)
      idxs = PokeAccess.ivar(@scene, :@opponentCardIndexes)
      n = (own.is_a?(Array) ? own.length : 0)
      return if n == 0
      move_choice(n)
      return if @choice == @last
      slot = idxs.is_a?(Array) ? idxs[@choice] : nil
      say_focus(slot.nil? ? PokeAccess::I18n.t(:triad_no_card) : card_text(card_species(:@opponentCards, slot)), @choice)
    end

    # UP/DOWN with the same wrap the game's own loops use.
    def self.move_choice(n)
      if Input.repeat?(Input::DOWN)
        @choice += 1; @choice = 0 if @choice >= n
      elsif Input.repeat?(Input::UP)
        @choice -= 1; @choice = n - 1 if @choice < 0
      end
    end

    # The species behind a hand position: the index arrays hold sprite slots, resolved through the card array ivar.
    def self.card_species(ivar, slot)
      return nil if slot.nil?
      cards = PokeAccess.ivar(@scene, ivar)
      cards.is_a?(Array) ? cards[slot] : nil
    end

    def self.hand_species(slot); card_species(:@playerCards, slot); end

    # Board placer: arrows wrap over the grid; speak the cell position and whether it is free or whose it is.
    def self.poll_board
      bt = PokeAccess.ivar(@scene, :@battle)
      return unless bt
      w = (bt.width rescue 3); h = (bt.height rescue 3)
      if Input.repeat?(Input::DOWN)
        @by += 1; @by = 0 if @by >= h
      elsif Input.repeat?(Input::UP)
        @by -= 1; @by = h - 1 if @by < 0
      elsif Input.repeat?(Input::LEFT)
        @bx -= 1; @bx = w - 1 if @bx < 0
      elsif Input.repeat?(Input::RIGHT)
        @bx += 1; @bx = 0 if @bx >= w
      end
      cur = [@bx, @by]
      say_focus(cell_text(bt, @bx, @by), cur) if cur != @last
    end

    # A card's line: species, type and the four side numbers (top, right, bottom, left).
    def self.card_text(species)
      return nil if species.nil?
      card = (TriadCard.new(species) rescue nil)
      name = PokeAccess::Data.species_name(species) || species.to_s
      return name unless card
      type = (PokeAccess::Data.type_name(card.type) rescue nil)
      name = "#{name}, #{PokeAccess::I18n.t(:mv_type, :t => type)}" if type
      PokeAccess::I18n.t(:triad_card, :name => name,
                         :n => num(card.north), :e => num(card.east),
                         :s => num(card.south), :w => num(card.west))
    rescue StandardError
      (PokeAccess::Data.species_name(species) rescue nil)
    end

    # A board cell: 1-based row and column, then free (with its element under the "elements" rule) or whose it is
    # and the card on it.
    def self.cell_text(bt, x, y)
      pos = PokeAccess::I18n.t(:triad_cell, :row => y + 1, :col => x + 1)
      if (bt.isOccupied?(x, y) rescue false)
        owner = (bt.getOwner(x, y) rescue nil)
        who = (owner == 1) ? PokeAccess::I18n.t(:triad_yours) : PokeAccess::I18n.t(:triad_theirs)
        sp = (bt.getPanel(x, y).card.species rescue nil)
        card = sp ? card_text(sp) : nil
        card ? "#{pos}, #{who}, #{card}" : "#{pos}, #{who}"
      else
        el = element(bt, x, y)
        free = "#{pos}, #{PokeAccess::I18n.t(:triad_free)}"
        el ? "#{free}, #{PokeAccess::I18n.t(:triad_element, :t => el)}" : free
      end
    rescue StandardError
      pos
    end

    # The element a square was dealt under the "elements" rule, by name; nil for none (gen-6 marks none -1,
    # the modern squares nil).
    def self.element(bt, x, y)
      type = (bt.board[y * bt.width + x].type rescue nil)
      return nil if type.nil? || (type.is_a?(Integer) && type < 0)
      PokeAccess::Data.type_name(type)
    rescue StandardError
      nil
    end

    # The opponent's move, card and square, queued; the score that follows it is queued too.
    def self.opponent_played(card, position)
      sp = (card.species rescue nil)
      return unless sp && position
      @after_foe = true
      PokeAccess.speak(PokeAccess::I18n.t(:triad_foe_plays, :card => card_text(sp),
                                          :row => position[1] + 1, :col => position[0] + 1), false, :menu)
    rescue StandardError
      nil
    end

    # The score as the screen counts it (cells owned, plus the cards in hand under "countunplayed"), after the
    # squares the move captured; said when it changes, interrupting except right after the opponent's move.
    def self.score(scene)
      queued = @after_foe ? true : false
      @after_foe = false
      bt = PokeAccess.ivar(scene, :@battle)
      return unless bt
      cells = (bt.width * bt.height rescue 0)
      owners = (0...cells).map { |i| (bt.board[i].owner rescue nil) }
      caps = captures(scene, owners, (bt.width rescue 3))
      you = owners.select { |o| o == 1 }.length
      foe = owners.select { |o| o == 2 }.length
      if (bt.countUnplayedCards rescue false)
        you += (PokeAccess.ivar(scene, :@cardIndexes).length rescue 0)
        foe += (PokeAccess.ivar(scene, :@opponentCardIndexes).length rescue 0)
      end
      return unless PokeAccess::Cursor.changed?(scene, :triad_score, [you, foe])
      line = PokeAccess::I18n.t(:triad_score, :you => you, :foe => foe)
      line = "#{PokeAccess::I18n.t(:triad_captures, :list => caps.join('; '))}. #{line}" unless caps.empty?
      PokeAccess.speak(line, !queued, :menu)
    rescue StandardError
      nil
    end

    # The squares whose owner went from one player to the other since the last count (kept on the scene).
    def self.captures(scene, owners, width)
      prev = PokeAccess.ivar(scene, :@access_triad_owners)
      scene.instance_variable_set(:@access_triad_owners, owners)
      return [] unless prev.is_a?(Array) && prev.length == owners.length
      out = []
      owners.each_with_index do |o, i|
        next unless o.to_i > 0 && prev[i].to_i > 0 && prev[i] != o
        out.push(PokeAccess::I18n.t(:triad_cell, :row => i / width + 1, :col => i % width + 1))
      end
      out
    end

    # The cards show 1-10 (10 drawn as "A"); speak the real number.
    def self.num(v)
      v.to_i
    end

    # Card shop flag (pbBuyTriads / pbSellTriads): while up, the card TriadCard#createBitmap draws is the focused one.
    def self.shopping(on)
      @shop = on ? true : false
      PokeAccess::Cursor.reset(nil, :triad_shop)
    end

    # The card the shop just drew, queued behind the row the list reads for itself.
    def self.shop_card(card)
      return unless @shop
      sp = (card.species rescue nil)
      t = card_text(sp)
      return if t.nil? || t.to_s.empty?
      return unless PokeAccess::Cursor.changed?(nil, :triad_shop, t)
      PokeAccess.speak(t, false, :menu)
    rescue StandardError
      nil
    end
  end
end

["TriadScene", "TriadScreen"].each do |cn|
  PokeAccess::Hooks.around_hook(cn, :pbViewOpponentCards, :optional => true) do |scene, call_next, _a|
    PokeAccess::TripleTriad.start_opponent(scene)
    begin; call_next.call; ensure; PokeAccess::TripleTriad.stop_opponent; end
  end
  PokeAccess::Hooks.around_hook(cn, :pbChooseTriadCard, :optional => true) do |scene, call_next, args|
    PokeAccess::TripleTriad.start_deck(scene, args[0])
    begin; call_next.call; ensure; PokeAccess::TripleTriad.stop; end
  end

  PokeAccess::Hooks.around_hook(cn, :pbPlayerChooseCard, :optional => true) do |scene, call_next, _a|
    PokeAccess::TripleTriad.start_hand(scene)
    begin; call_next.call; ensure; PokeAccess::TripleTriad.stop; end
  end
  PokeAccess::Hooks.around_hook(cn, :pbPlayerPlaceCard, :optional => true) do |scene, call_next, _a|
    PokeAccess::TripleTriad.start_board(scene)
    begin; call_next.call; ensure; PokeAccess::TripleTriad.stop; end
  end
  PokeAccess::Hooks.after_hook(cn, :pbUpdateScore, :optional => true) do |scene, _r, _a|
    PokeAccess::TripleTriad.score(scene)
  end
  PokeAccess::Hooks.after_hook(cn, :pbOpponentPlaceCard, :optional => true) do |_scene, _r, args|
    PokeAccess::TripleTriad.opponent_played(args[0], args[1])
  end
end
PokeAccess::Keys.on_frame { PokeAccess::TripleTriad.poll }

# The deck list is a plain Window_CommandPokemonEx: outside the deck loop this returns the generic text, never nil
# (focused_text only falls back on an exception, so nil would silence every command window).
PokeAccess::Menus.def_extractor("Window_CommandPokemonEx") do |win, i|
  PokeAccess::TripleTriad.deck_row(win, i)
end

# Raises the shop flag around both halves of the shop; createBitmap also draws every card of a match.
["pbBuyTriads", "pbSellTriads"].each do |fn|
  PokeAccess::Hooks.wrap_kernel(fn, "triad_shop_#{fn}", :around) do |_args, call_next|
    PokeAccess::TripleTriad.shopping(true)
    begin
      call_next.call
    ensure
      PokeAccess::TripleTriad.shopping(false)
    end
  end
end

PokeAccess::Hooks.before_hook("TriadCard", :createBitmap, :optional => true) do |card, _args|
  PokeAccess::TripleTriad.shop_card(card)
end
