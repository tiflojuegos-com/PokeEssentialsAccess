# Minigame text. Most gen-6 minigames show prompts/results through pbMessage (already voiced). Triple
# Triad is the exception: it writes to its own help window via pbDisplay/pbDisplayPaused, so those
# lines (whose turn, card flips, win/lose) were silent. This reads them; the board navigation is read
# separately below. Triple Triad ships in every game (TriadScene, same ivars across gen-6 and modern).

# Triple Triad voices its help-window lines. Which of the two classes carries them varies by game, so both
# names are offered and each is bound only where the method is really there -- otherwise the games that
# split the work (TriadScreen present but every method on TriadScene, which is most of them) report a pile
# of missing hooks that look like a fault and are not. say_dialogue dedups (one voicing within half a
# second) and remembers the line for the repeat key.
["TriadScene", "TriadScreen"].each do |cn|
  ["pbDisplay", "pbDisplayPaused"].each do |m|
    next unless PokeAccess::Engine.has?("#{cn}##{m}")
    PokeAccess::Hooks.before_hook(cn, m) do |_s, args|
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
      push
      @mode = :hand; @scene = scene; @choice = 0; @last = nil
    end

    # Starts mirroring the board placer: cursor over the @battle grid (arrows), reads free/occupied cells.
    def self.start_board(scene)
      push
      @mode = :board; @scene = scene; @bx = 0; @by = 0; @last = nil
    end

    def self.push
      (@stack ||= []).push([@mode, @scene, @choice, @bx, @by, @last])
    end

    def self.stop
      @mode, @scene, @choice, @bx, @by, @last = (@stack && @stack.pop) || [nil, nil, 0, 0, 0, nil]
    end

    # Mirrors the active loop's navigation once per frame and speaks the focus when it changes.
    def self.poll
      return unless @scene
      case @mode
      when :hand  then poll_hand
      when :board then poll_board
      end
    rescue StandardError
      nil
    end

    # Hand picker: UP/DOWN wrap over the number of cards in hand; speak the focused card.
    def self.poll_hand
      idxs = PokeAccess.ivar(@scene, :@cardIndexes)
      n = (idxs.is_a?(Array) ? idxs.length : 0)
      return if n == 0
      if Input.repeat?(Input::DOWN)
        @choice += 1; @choice = 0 if @choice >= n
      elsif Input.repeat?(Input::UP)
        @choice -= 1; @choice = n - 1 if @choice < 0
      end
      if @choice != @last
        @last = @choice
        t = card_text(idxs[@choice])
        PokeAccess.speak(t, true) if t && !t.to_s.empty?
      end
    end

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

    # The cards show 1-10 (10 drawn as "A"); speak the real number.
    def self.num(v)
      v.to_i
    end
  end
end

["TriadScene", "TriadScreen"].each do |cn|
  if PokeAccess::Engine.has?("#{cn}#pbPlayerChooseCard")
    PokeAccess::Hooks.around_hook(cn, :pbPlayerChooseCard) do |scene, call_next, _a|
      PokeAccess::TripleTriad.start_hand(scene)
      begin; call_next.call; ensure; PokeAccess::TripleTriad.stop; end
    end
  end
  if PokeAccess::Engine.has?("#{cn}#pbPlayerPlaceCard")
    PokeAccess::Hooks.around_hook(cn, :pbPlayerPlaceCard) do |scene, call_next, _a|
      PokeAccess::TripleTriad.start_board(scene)
      begin; call_next.call; ensure; PokeAccess::TripleTriad.stop; end
    end
  end
end
PokeAccess::Keys.on_frame { PokeAccess::TripleTriad.poll }
