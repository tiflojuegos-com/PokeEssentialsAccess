# Minigame text. Most gen-6 minigames show prompts/results through pbMessage (already voiced). Triple
# Triad is the exception: it writes to its own help window via pbDisplay/pbDisplayPaused, so those
# lines (whose turn, card flips, win/lose) were silent. This reads them; the board navigation is read
# separately below. Triple Triad ships in every game (TriadScene, same ivars across gen-6 and modern).

# Triple Triad voices its help-window lines. Which of the two classes carries them varies by game, so both
# names are offered as :optional -- the games that split the work (TriadScreen present but every method on
# TriadScene, which is most of them) bind only where the method really lives, with no false typo noise.
# say_dialogue dedups (one voicing within half a second) and remembers the line for the repeat key.
["TriadScene", "TriadScreen"].each do |cn|
  ["pbDisplay", "pbDisplayPaused"].each do |m|
    PokeAccess::Hooks.before_hook(cn, m, :optional => true) do |_s, args|
      PokeAccess.say_dialogue(args[0])
    end
  end
end

module PokeAccess
  # Triple Triad board navigation. Choosing a card from hand (pbPlayerChooseCard) and placing it on the
  # board (pbPlayerPlaceCard) run their own blocking loops whose cursor (choice / boardX,boardY) is a LOCAL
  # variable, so no hook sees it. As with other local-cursor menus, an around-hook holds the scene during
  # the loop and a per-frame poll mirrors the same Input.repeat? navigation to know the focus and speak it.
  # The card data (species + the four side numbers) and the board cells (free / owner) are read from the
  # scene's ivars (@cardIndexes, @playerCards, @battle), which are identical across all games' TriadScene.
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

    # Starts mirroring the opponent's hand, which the confirm key opens over the player's own in an open-hand
    # match. It is a loop of its own with its own cursor, so without this the mirror kept reading the
    # PLAYER's cards while the screen showed the rival's, and every arrow moved a cursor nobody could see.
    def self.start_opponent(scene)
      push(scene)
      @mode = :opponent; @scene = scene; @choice = 0; @last = nil
    end

    # Leaves the opponent's hand. The game puts the player's cursor back on the first card, so the mirror
    # does too: restoring the position it had would have it naming a card the screen no longer highlights.
    def self.stop_opponent
      stop
      @choice = 0; @last = nil
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

    # Holds the scene while the DECK selector runs, which reads nothing of its own: its list is a real
    # command window and the generic reader already names the focused card. What it is here for is the help
    # window, which that loop writes four of its eight prompts into.
    def self.start_deck(scene, storage)
      push(scene)
      @mode = :deck; @scene = scene; @last = nil; @storage = storage
    end

    # The focused row of the DECK list, with the four side numbers appended. The row itself already says the
    # species and how many are left ("Bulbasaur x3"); the sides are the only thing that decides which card
    # to take, and the screen shows them as a picture. They were said later, in hand, when the choice is
    # already made.
    #
    # The list is a real command window, so this is an extractor rather than a mirrored cursor: the window
    # is handed in and the index with it, and the storage the loop was called with says which species each
    # row is. Outside this loop it answers exactly what the generic reader would.
    def self.deck_row(win, i)
      base = PokeAccess::Menus.generic_focus(win, i)
      return base unless @mode == :deck && @storage.is_a?(Array)
      e = (@storage[i] rescue nil)
      sp = e.is_a?(Array) ? e[0] : e
      return base unless sp
      card = (TriadCard.new(sp) rescue nil)
      return base unless card
      "#{base}, #{PokeAccess::I18n.t(:triad_sides, :n => num(card.north), :e => num(card.east),
                                     :s => num(card.south), :w => num(card.west))}"
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

    # The help window, which this screen writes in TWO ways: through pbDisplay/pbDisplayPaused, already
    # hooked above, and by assigning straight to the sprite -- eight of those, in four methods, and among
    # them the line that says the confirm key opens the rival's hand. A feature the mod can read and the
    # player had no way of knowing existed.
    #
    # Gated on the text through Cursor first: this runs every frame and the window keeps its prompt for the
    # whole loop, and say_dialogue's half-second window let the same line back in twice a second. Routed
    # through say_dialogue after that, since it is the message path: its dedup absorbs the pbDisplay hook
    # painting the same line, and the repeat key gets these prompts as well.
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
      if @choice != @last
        @last = @choice
        t = card_text(hand_species(idxs[@choice]))
        PokeAccess.speak(t, true)
      end
    end

    # Opponent's hand, wrapped by the PLAYER's card count and not the rival's.
    #
    # The screen's own loop is entered as pbViewOpponentCards(numCards) from pbPlayerChooseCard(numCards),
    # where numCards is the player's hand, so that is what it wraps on. The two hands empty separately, so
    # mirroring the rival's length puts the wrap in a different place as soon as the rival leads.
    #
    # A position past the rival's last card is named as empty, because the game's redraw only highlights
    # while i == choice over ITS cards and so highlights nothing there; naming a card would claim a focus
    # the screen does not show, and silence is indistinguishable from a key that did nothing.
    def self.poll_opponent
      own  = PokeAccess.ivar(@scene, :@cardIndexes)
      idxs = PokeAccess.ivar(@scene, :@opponentCardIndexes)
      n = (own.is_a?(Array) ? own.length : 0)
      return if n == 0
      move_choice(n)
      return if @choice == @last
      @last = @choice
      slot = idxs.is_a?(Array) ? idxs[@choice] : nil
      t = slot.nil? ? PokeAccess::I18n.t(:triad_no_card) : card_text(card_species(:@opponentCards, slot))
      PokeAccess.speak(t, true)
    end

    # UP/DOWN with the same wrap the game's own loops use.
    def self.move_choice(n)
      if Input.repeat?(Input::DOWN)
        @choice += 1; @choice = 0 if @choice >= n
      elsif Input.repeat?(Input::UP)
        @choice -= 1; @choice = n - 1 if @choice < 0
      end
    end

    # The species behind a hand position. The index arrays hold sprite slots, not species: the game resolves
    # a slot through its card array (TriadCard.new(@playerCards[spriteIndex])) before building a card.
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
      if cur != @last
        @last = cur
        PokeAccess.speak(cell_text(bt, @bx, @by), true)
      end
    end

    # A hand card's spoken line: species name plus its four side numbers (top, right, bottom, left).
    def self.card_text(species)
      return nil if species.nil?
      card = (TriadCard.new(species) rescue nil)
      name = PokeAccess::Data.species_name(species) || species.to_s
      return name unless card
      PokeAccess::I18n.t(:triad_card, :name => name,
                         :n => num(card.north), :e => num(card.east),
                         :s => num(card.south), :w => num(card.west))
    rescue StandardError
      (PokeAccess::Data.species_name(species) rescue nil)
    end

    # The board cell line: 1-based row/column and free, yours or the opponent's.
    def self.cell_text(bt, x, y)
      pos = PokeAccess::I18n.t(:triad_cell, :row => y + 1, :col => x + 1)
      if (bt.isOccupied?(x, y) rescue false)
        owner = (bt.getOwner(x, y) rescue nil)
        who = (owner == 1) ? PokeAccess::I18n.t(:triad_yours) : PokeAccess::I18n.t(:triad_theirs)
        "#{pos}, #{who}"
      else
        "#{pos}, #{PokeAccess::I18n.t(:triad_free)}"
      end
    rescue StandardError
      pos
    end

    # The scoreboard, counted the way the screen counts it: cells owned per side plus, under "countunplayed",
    # the cards still in hand (pbUpdateScore in 017_Minigames/002_Minigame_TripleTriad.rb). Said only
    # when it moves, interrupting: it is the answer to what just happened.
    def self.score(scene)
      bt = PokeAccess.ivar(scene, :@battle)
      return unless bt
      cells = (bt.width * bt.height rescue 0)
      you = 0
      foe = 0
      (0...cells).each do |i|
        owner = (bt.board[i].owner rescue nil)
        you += 1 if owner == 1
        foe += 1 if owner == 2
      end
      if (bt.countUnplayedCards rescue false)
        you += (PokeAccess.ivar(scene, :@cardIndexes).length rescue 0)
        foe += (PokeAccess.ivar(scene, :@opponentCardIndexes).length rescue 0)
      end
      return unless PokeAccess::Cursor.changed?(scene, :triad_score, [you, foe])
      PokeAccess.speak(PokeAccess::I18n.t(:triad_score, :you => you, :foe => foe), true)
    rescue StandardError
      nil
    end

    # The cards show 1-10 (10 drawn as "A"); speak the real number.
    def self.num(v)
      v.to_i
    end

    # The card shop (pbBuyTriads / pbSellTriads): the rows are strings the generic reader names, but the
    # card drawn beside them is a bitmap built from locals. The loop redraws it with TriadCard#createBitmap
    # whenever the focus lands on a new species, so the card handed to that call is the focused one.
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
      PokeAccess.speak(t, false)
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
end
PokeAccess::Keys.on_frame { PokeAccess::TripleTriad.poll }

# The deck list is a plain Window_CommandPokemonEx, the class half the game's menus use, so this extractor
# has to be transparent everywhere else: outside the deck loop it returns exactly what the generic reader
# would. It cannot return nil -- focused_text does NOT fall back to the generic on nil, only on an
# exception, so a nil here would silence every command window in the game.
PokeAccess::Menus.def_extractor("Window_CommandPokemonEx") do |win, i|
  PokeAccess::TripleTriad.deck_row(win, i)
end

# The flag is raised around both halves of the shop: createBitmap also draws the board and both hands, and
# a reader on it that did not ask where it was would narrate every card of every match.
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
