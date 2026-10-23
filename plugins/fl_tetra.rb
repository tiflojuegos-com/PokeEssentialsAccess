# FL's Poké Tetra (PokeTetra::Scene, a Triple Triad on a 4x4 board with neutral blocks): the duel's rules and blocked
# squares, the hand, rival's hand and board cursors (from their loops' sprites), each move, the score, the deck chooser.
module PokeAccess
  module Tetra
    # The z the game gives the card under the cursor; the rest of a hand sits at 2.
    FOCUS_Z = 4

    # An owner's number on a square: free, the player's, the rival's, or a neutral block.
    FREE = 0
    PLAYER = 1
    FOE = 2
    BLOCK = -1

    # The trade rule's values (@trade) that change which cards the players keep, when the hands are not the party's.
    TRADE_RULES = { 1 => :ttr_rule_direct, 2 => :ttr_rule_winall }

    # The deck chooser's scene while it runs, for the preview card its loop draws.
    @deck_scene = nil

    # The game's own card of a species, or nil where it cannot be built.
    def self.card_for(species)
      klass = PokeAccess.const_at("PokeTetra::Card")
      klass ? klass.new(species) : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A species' name as the game gives it.
    def self.species_name(species)
      name = PokeAccess::Data.species_name(species)
      (name.nil? || name.to_s.empty?) ? species.to_s : name.to_s
    end

    # A card as its picture shows it: species, type and the four sides, top first.
    def self.card_text(card)
      return nil if card.nil?
      type = PokeAccess::Data.type_name(card.type)
      name = species_name(card.species)
      name = "#{name}, #{PokeAccess::I18n.t(:mv_type, :t => type)}" if type && !type.to_s.empty?
      PokeAccess::I18n.t(:triad_card, :name => name, :n => card.north.to_i, :e => card.east.to_i,
                         :s => card.south.to_i, :w => card.west.to_i)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The line of the card a hand slot holds, from the species the scene was handed; the species alone where the card
    # cannot be built.
    def self.slot_text(cards, slot)
      species = cards.is_a?(Array) ? cards[slot] : nil
      return nil if species.nil?
      card_text(card_for(species)) || species_name(species)
    end

    # The game's square at a column and row of its board.
    def self.square_at(battle, x, y)
      battle.board[y * battle.width + x]
    end

    # Whether a column and row are on the board.
    def self.on_board?(battle, x, y)
      x >= 0 && x < battle.width && y >= 0 && y < battle.height
    end

    # Who a square's card belongs to, in words.
    def self.owner_word(owner)
      PokeAccess::I18n.t(owner == PLAYER ? :triad_yours : :triad_theirs)
    end

    # The place in slots and the sprite of the card the game has raised: the one under the cursor.
    def self.raised(scene, prefix, slots)
      return nil unless slots.is_a?(Array)
      slots.each_with_index do |slot, i|
        sprite = PokeAccess.sprite(scene, "#{prefix}#{slot}")
        return [i, sprite] if sprite && (sprite.z rescue nil) == FOCUS_Z
      end
      nil
    end

    # The hand picker's entry for the watcher: the card under the cursor, keyed by its place and by the rival's views
    # closed so far, so that coming back from one reads the first card again.
    def self.hand_entry(scene)
      slots = PokeAccess.ivar(scene, :@cardIndexes)
      found = raised(scene, "player", slots)
      return nil unless found
      views = PokeAccess.ivar(scene, :@access_ttr_views).to_i
      cards = PokeAccess.ivar(scene, :@playerCards)
      [[found[0], views], lambda { slot_text(cards, slots[found[0]]) }]
    end

    # The rival's hand viewer's entry: the card under the cursor, or no card where it stands past their last one, which
    # the screen shows as nothing raised.
    def self.foe_entry(scene)
      slots = PokeAccess.ivar(scene, :@opponentCardIndexes)
      return nil unless slots.is_a?(Array)
      found = raised(scene, "opponent", slots)
      return [:none, lambda { PokeAccess::I18n.t(:triad_no_card) }] unless found
      cards = PokeAccess.ivar(scene, :@opponentCards)
      [found[0], lambda { slot_text(cards, slots[found[0]]) }]
    end

    # Counts a close of the rival's hand viewer on the scene, which the hand picker's key carries.
    def self.foe_closed(scene)
      scene.instance_variable_set(:@access_ttr_views, PokeAccess.ivar(scene, :@access_ttr_views).to_i + 1)
    end

    # The column and row a card sprite sits on: where the game puts the placed card is the field's origin plus the
    # card's size per square.
    def self.cell_of(sprite)
      left = PokeAccess.const_at("PokeTetra::Scene::FIELD_BASE_X")
      top = PokeAccess.const_at("PokeTetra::Scene::FIELD_BASE_Y")
      wide = PokeAccess.const_at("PokeTetra::Card::WIDTH")
      high = PokeAccess.const_at("PokeTetra::Card::HEIGHT")
      return nil unless left && top && wide && high
      [(sprite.x - left) / wide, (sprite.y - top) / high]
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The board placer's entry: the square the card being placed has been moved onto, none off the board.
    def self.board_entry(scene)
      found = raised(scene, "player", PokeAccess.ivar(scene, :@cardIndexes))
      cell = found ? cell_of(found[1]) : nil
      battle = PokeAccess.ivar(scene, :@battle)
      return nil unless cell && battle && on_board?(battle, cell[0], cell[1])
      [cell, lambda { cell_text(scene, cell[0], cell[1]) }]
    end

    # A board square as the screen shows it: its row and column, then free, a block, or whose card is on it.
    def self.cell_text(scene, x, y)
      battle = PokeAccess.ivar(scene, :@battle)
      pos = PokeAccess::I18n.t(:triad_cell, :row => y + 1, :col => x + 1)
      square = square_at(battle, x, y)
      owner = square.owner.to_i
      return "#{pos}, #{PokeAccess::I18n.t(:ttr_blocked)}" if owner == BLOCK
      return "#{pos}, #{PokeAccess::I18n.t(:triad_free)}" if owner == FREE
      card = card_text(square.card)
      card ? "#{pos}, #{owner_word(owner)}, #{card}" : "#{pos}, #{owner_word(owner)}"
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Every square's owner, row by row.
    def self.owners_of(battle)
      (0...(battle.width * battle.height)).map { |i| battle.board[i].owner }
    end

    # The squares whose owner went from one player to the other since the last move; the owners the board holds now are
    # kept on the scene for the next move.
    def self.flipped(scene, battle)
      owners = owners_of(battle)
      before = PokeAccess.ivar(scene, :@access_ttr_owners)
      scene.instance_variable_set(:@access_ttr_owners, owners)
      return [] unless before.is_a?(Array) && before.length == owners.length
      changed = []
      owners.each_with_index do |owner, i|
        changed.push(i) if owner.to_i > 0 && before[i].to_i > 0 && before[i] != owner
      end
      changed
    end

    # The flipped squares as a sentence: each one's row and column and the card now on it.
    def self.captures_text(battle, indexes)
      return nil if indexes.empty?
      list = indexes.map do |i|
        pos = PokeAccess::I18n.t(:triad_cell, :row => i / battle.width + 1, :col => i % battle.width + 1)
        card = battle.board[i].card
        card ? "#{pos}, #{species_name(card.species)}" : pos
      end
      PokeAccess::I18n.t(:triad_captures, :list => list.join("; "))
    end

    # Says a move as the game hands it to the scene (flips on the board, score not yet redrawn): the card and where it
    # went, then the squares it flipped; the player's cuts in, the rival's queues with the card in full.
    # param mine true for the player's move
    def self.moved(scene, args, mine)
      battle = PokeAccess.ivar(scene, :@battle)
      x, y = args[0]
      return if battle.nil? || x.nil? || y.nil?
      flips = flipped(scene, battle)
      card = square_at(battle, x, y).card
      played = if mine
                 PokeAccess::I18n.t(:ttr_you_play, :card => species_name(card.species), :row => y + 1, :col => x + 1)
               else
                 PokeAccess::I18n.t(:triad_foe_plays, :card => card_text(card), :row => y + 1, :col => x + 1)
               end
      PokeAccess.speak(PokeAccess.sentences([played, captures_text(battle, flips)]), mine, :menu)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The score as the screen counts it: the squares each side owns, plus the cards left in hand under the
    # "countunplayed" rule.
    def self.scores(scene, battle)
      owners = owners_of(battle)
      you = owners.select { |o| o == PLAYER }.length
      foe = owners.select { |o| o == FOE }.length
      if PokeAccess.ivar(battle, :@countUnplayedCards)
        you += PokeAccess.ivar(scene, :@cardIndexes).to_a.length
        foe += PokeAccess.ivar(scene, :@opponentCardIndexes).to_a.length
      end
      [you, foe]
    end

    # One square for the board's overview: free, blocked, or its card's species and whose it is.
    def self.cell_brief(square)
      owner = square.owner.to_i
      return PokeAccess::I18n.t(:ttr_blocked) if owner == BLOCK
      return PokeAccess::I18n.t(:triad_free) if owner == FREE
      card = square.card
      card ? "#{species_name(card.species)} #{owner_word(owner)}" : owner_word(owner)
    end

    # The whole board for the info key: the score, then each row's squares by what they hold.
    def self.overview(battle, you, foe)
      rows = (0...battle.height).map do |y|
        cells = (0...battle.width).map { |x| cell_brief(square_at(battle, x, y)) }
        PokeAccess::I18n.t(:ttr_row, :row => y + 1, :cells => cells.join(", "))
      end
      PokeAccess.sentences([PokeAccess::I18n.t(:triad_score, :you => you, :foe => foe)].concat(rows))
    end

    # The score each time the game redraws it changed, queued behind the move that changed it, and the board for the
    # info key.
    def self.score(scene)
      battle = PokeAccess.ivar(scene, :@battle)
      return unless battle
      you, foe = scores(scene, battle)
      PokeAccess::Info.set_info(:text, overview(battle, you, foe))
      return unless PokeAccess::Cursor.changed?(scene, :ttr_score, [you, foe])
      PokeAccess.speak(PokeAccess::I18n.t(:triad_score, :you => you, :foe => foe), false, :menu)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The squares the duel blocks, which the screen shows as dark squares and no line says.
    def self.blocks(scene, indexes)
      battle = PokeAccess.ivar(scene, :@battle)
      return unless battle && indexes.is_a?(Array) && !indexes.empty?
      cells = indexes.sort.map do |i|
        PokeAccess::I18n.t(:triad_cell, :row => i / battle.width + 1, :col => i % battle.width + 1)
      end
      PokeAccess.speak(PokeAccess::I18n.t(:ttr_blocks, :n => cells.length, :list => cells.join("; ")), false, :menu)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The rules the duel's flags switch on, in words; the trade rule too when the hands are not the party.
    def self.rules_line(battle)
      rules = [[PokeAccess.ivar(battle, :@openHand), :ttr_rule_open],
               [PokeAccess.ivar(battle, :@sameWins), :ttr_rule_same],
               [PokeAccess.ivar(battle, :@wrapAround), :ttr_rule_wrap],
               [PokeAccess.ivar(battle, :@randomHand), :ttr_rule_random],
               [PokeAccess.ivar(battle, :@countUnplayedCards), :ttr_rule_count],
               [PokeAccess.ivar(battle, :@disableTypeBonus), :ttr_rule_notype]]
      words = rules.select { |on, _key| on }.map { |_on, key| PokeAccess::I18n.t(key) }
      trade = PokeAccess.const_at("PokeTetra::USE_PARTY") ? nil : TRADE_RULES[PokeAccess.ivar(battle, :@trade)]
      words.push(PokeAccess::I18n.t(trade)) if trade
      words.empty? ? nil : PokeAccess::I18n.t(:ttr_rules, :list => words.join(", "))
    end

    # The key that shows the rival's cards, said while hints are and only when the rules allow it.
    def self.open_hint(battle)
      return nil unless PokeAccess.ivar(battle, :@openHand) && PokeAccess::Verbosity.hints?
      PokeAccess::I18n.t(:ttr_open_hint, :key => PokeAccess::KeyHints.key(:a, "Z"))
    end

    # What opens a duel, queued: who it is against, its rules, the board's size and the key for an open hand.
    def self.opening(scene, battle)
      PokeAccess::Cursor.reset(scene, :ttr_score)
      return unless battle
      duel = PokeAccess::I18n.t(:ttr_duel, :foe => battle.opponentName)
      board = PokeAccess::I18n.t(:ttr_board, :rows => battle.height, :cols => battle.width)
      PokeAccess.speak_clean(PokeAccess.sentences([duel, rules_line(battle), board, open_hint(battle)]), false, :menu)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Says a taken square cannot take the card, which the game answers with a buzzer and nothing else.
    # param taken what isOccupied? answered
    def self.refused(taken)
      PokeAccess.speak(PokeAccess::I18n.t(:ttr_occupied), true, :menu) if taken
    end

    # The deck chooser's prompt, its help window written straight to the sprite, keyed on itself.
    def self.help_entry(scene)
      box = PokeAccess.sprite(scene, "helpwindow")
      text = box ? PokeAccess.clean((box.text rescue "").to_s) : ""
      [text, text]
    end

    # Whether a hand slot's sprite shows a card the chooser has taken.
    def self.taken_slot?(sprite)
      return false unless sprite
      (sprite.visible && sprite.bitmap) ? true : false
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # The deck chooser's count: the cards its sprites show as taken, of the hand's size.
    def self.chosen_entry(scene)
      size = PokeAccess.const_at("PokeTetra::HAND_SIZE")
      return nil unless size
      taken = (0...size).select { |i| taken_slot?(PokeAccess.sprite(scene, "player#{i}")) }.length
      [taken, lambda { PokeAccess::I18n.t(:ttr_chosen, :n => taken, :max => size) }]
    end

    # Runs the deck chooser with its scene held, so previewed knows the cards drawn meanwhile are the chooser's.
    def self.choosing(scene)
      @deck_scene = scene
      PokeAccess::Cursor.reset(scene, :ttr_preview)
      yield
    ensure
      @deck_scene = nil
    end

    # The card the chooser's preview has just drawn, queued behind the row the list reads for itself; once per card.
    def self.previewed(card)
      scene = @deck_scene
      return unless scene
      text = card_text(card)
      return if text.nil? || !PokeAccess::Cursor.changed?(scene, :ttr_preview, text)
      PokeAccess.speak(text, false, :menu)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

# The rules and the board as a duel opens, said ahead of the fade-in; the battle is the scene's first argument, which
# it only keeps once it runs.
PokeAccess::Hooks.before_hook("PokeTetra::Scene", :pbStartScene, :optional => true) do |scene, args|
  PokeAccess::Tetra.opening(scene, args[0])
end

# The dark squares the duel blocks, from the indexes it hands over.
PokeAccess::Hooks.before_hook("PokeTetra::Scene", :pbPutBlockCards, :optional => true) do |scene, args|
  PokeAccess::Tetra.blocks(scene, args[0])
end

# The help window's lines (who goes first, the rival's turn, the result, the cards won or lost), written through
# pbDisplay and pbDisplayPaused.
["pbDisplay", "pbDisplayPaused"].each do |m|
  PokeAccess::Hooks.before_hook("PokeTetra::Scene", m, :optional => true) do |_s, args|
    PokeAccess.say_dialogue(args[0])
  end
end

# The player's move and the rival's, read as the game hands them over: ahead of pbUpdateScore, which they call, so the
# move comes before the score.
PokeAccess::Hooks.before_hook("PokeTetra::Scene", :pbEndPlaceCard, :optional => true) do |scene, args|
  PokeAccess::Tetra.moved(scene, args, true)
end
PokeAccess::Hooks.before_hook("PokeTetra::Scene", :pbEndOpponentPlaceCard, :optional => true) do |scene, args|
  PokeAccess::Tetra.moved(scene, args, false)
end

# The score, once the move's cards are off the hand it counts.
PokeAccess::Hooks.before_hook("PokeTetra::Scene", :pbUpdateScore, :optional => true) do |scene, _args|
  PokeAccess::Tetra.score(scene)
end

# The board in the info key stays with the duel.
PokeAccess::Hooks.before_hook("PokeTetra::Scene", :pbEndScene, :optional => true) do |_scene, _args|
  PokeAccess::Info.clear_text
end

# The hand picker: UP and DOWN raise one card of the hand, which is read from the sprite the loop raised.
PokeAccess::SceneWatcher.reader("PokeTetra::Scene", :pbPlayerChooseCard, :ttr_hand, :optional => true) do |scene|
  PokeAccess::Tetra.hand_entry(scene)
end

# The rival's hand, opened by the A key of an open-hand duel from inside the picker.
PokeAccess::SceneWatcher.reader("PokeTetra::Scene", :pbViewOpponentCards, :ttr_foe, :optional => true) do |scene|
  PokeAccess::Tetra.foe_entry(scene)
end
PokeAccess::Hooks.around_hook("PokeTetra::Scene", :pbViewOpponentCards, :optional => true) do |scene, nxt, _a|
  begin
    nxt.call
  ensure
    PokeAccess::Tetra.foe_closed(scene)
  end
end

# The board placer: the arrows slide the chosen card over the squares, read from where its sprite stands.
PokeAccess::SceneWatcher.reader("PokeTetra::Scene", :pbPlayerPlaceCard, :ttr_cell, :optional => true) do |scene|
  PokeAccess::Tetra.board_entry(scene)
end

# A taken square: the game answers its confirm key there with isOccupied? and a buzzer.
PokeAccess::Hooks.around_hook("PokeTetra::Screen", :isOccupied?, :optional => true) do |_screen, nxt, _a|
  taken = nxt.call
  PokeAccess::Tetra.refused(taken)
  taken
end

# The deck chooser, which runs when the hand is not the party's six: its prompt, the count of cards taken so far, and
# the card its preview draws for the row in focus (the row itself is the generic list's).
PokeAccess::Hooks.around_hook("PokeTetra::Scene", :pbChooseCard, :optional => true) do |scene, nxt, _a|
  PokeAccess::Tetra.choosing(scene) { nxt.call }
end
PokeAccess::SceneWatcher.reader("PokeTetra::Scene", :pbChooseCard, :ttr_help, :optional => true) do |scene|
  PokeAccess::Tetra.help_entry(scene)
end
PokeAccess::SceneWatcher.reader("PokeTetra::Scene", :pbChooseCard, :ttr_taken, :optional => true,
                                :queued => true) do |scene|
  PokeAccess::Tetra.chosen_entry(scene)
end
PokeAccess::Hooks.before_hook("PokeTetra::Card", :createBitmap, :optional => true) do |card, _args|
  PokeAccess::Tetra.previewed(card)
end
