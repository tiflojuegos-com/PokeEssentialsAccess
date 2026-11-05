# Poke Poker (Pokepoker; Ashen Frost): a Texas hold'em table whose moves and winners are messages, and whose cards, pot and chips
# are only painted. Said here: the player's hand as it is dealt, the table's cards as they turn, the rest of the hands when
# they are shown, the sums ahead of the player's question, and the raise's menu, a picture with a cursor. The info key keeps all
# of it, and the rivals' chips, as it stands: no cards from a hand's end to the next deal, and the menu only while it is open.
module PokeAccess
  module PokePoker
    # The raise menu's rows, top to bottom, as betui paints them: three sums, all in and the confirmation.
    RAISE_ROWS = { 1 => "5", 2 => "10", 3 => "50", 4 => "100", 5 => :pkr_all_in, 6 => :pkr_confirm }

    # The deck's suits and its faces by value: a card is [its picture's number, its English name, 2 to 14, its suit].
    SUITS = { "Spades" => :vp_spades, "Clubs" => :vp_clubs, "Diamonds" => :vp_diamonds, "Hearts" => :vp_hearts }
    FACES = { 11 => :vp_jack, 12 => :vp_queen, 13 => :vp_king, 14 => :vp_ace }

    # A card's name in the reader's language: the game only paints them, in pictures with no words.
    def self.card_name(card)
      face = FACES[card[2]]
      PokeAccess::I18n.t(:vp_card_bare, :value => face ? PokeAccess::I18n.t(face) : card[2].to_s,
                                        :suit => PokeAccess::I18n.t(SUITS[card[3]]))
    end

    # The dealt cards among ivars, by name.
    def self.cards(scene, *ivars)
      held = ivars.map { |iv| PokeAccess.ivar(scene, iv) }
      held.select { |card| card.is_a?(Array) && !card.empty? }.map { |card| card_name(card) }
    end

    # True once the player has folded this hand: updatefold puts their cards away.
    def self.folded?(scene)
      (PokeAccess.ivar(scene, :@players)[0][1] == 0 rescue false)
    end

    # The player's two cards, by name, while they hold them.
    def self.hand(scene)
      folded?(scene) ? [] : cards(scene, :@player1card1, :@player1card2)
    end

    # The player's two cards as they are dealt, while the player is still at the table.
    def self.dealt(scene)
      own = hand(scene)
      return if own.empty? || (PokeAccess.ivar(scene, :@players)[0][2] <= 0 rescue true)
      PokeAccess.speak(PokeAccess::I18n.t(:pkr_your_hand, :list => own.join(", ")), false)
      publish(scene, [])
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The table's cards face up: none before the flop, then three, four and five (@comcards counts the turns of them).
    def self.table(scene)
      n = PokeAccess.ivar_i(scene, :@comcards)
      return [] if n <= 0
      cards(scene, *(1..(n + 2)).map { |i| "@comcard#{i}".to_sym })
    end

    # The table's cards when they turned, ahead of the round's first move; the new cards alone would hide what stays.
    def self.turned(scene)
      list = table(scene)
      return if list.empty? || !PokeAccess::Cursor.changed?(scene, :pkr_table, list.length)
      PokeAccess.speak(PokeAccess::I18n.t(:pkr_table, :list => list.join(", ")), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The bet to match: before the flop it starts at the blind, as fsubround sets it when it runs; none before the first hand's
    # round starts, @comcards still unset.
    def self.standing_bet(scene)
      bet = PokeAccess.ivar_i(scene, :@previousbet)
      bet.zero? && PokeAccess.ivar(scene, :@comcards) == 0 ? PokeAccess.ivar_i(scene, :@blindvalue) : bet
    end

    # The player's sums as the table paints them, and what they owe to stay in.
    def self.sums(scene)
      players = PokeAccess.ivar(scene, :@players)
      owed = standing_bet(scene) - PokeAccess.ivar_i(scene, :@player1bet)
      parts = [PokeAccess::I18n.t(:pkr_pot, :n => PokeAccess.ivar_i(scene, :@pot))]
      parts.push(PokeAccess::I18n.t(:pkr_owed, :n => owed)) if owed > 0 && !folded?(scene)
      parts.push(PokeAccess::I18n.t(:pkr_chips, :n => players[0][0]))
      parts.join(", ")
    end

    # Whether the move about to be asked is the player's: the first still in the round from @playing, as both subrounds pick it.
    def self.player_next?(scene)
      players = PokeAccess.ivar(scene, :@players)
      seat = PokeAccess.ivar_i(scene, :@playing)
      4.times do
        break if players[seat % 4][1] != 0
        seat += 1
      end
      (seat % 4).zero?
    end

    # The rivals still in the game, with the chips the table paints for each.
    def self.rivals(scene)
      players = PokeAccess.ivar(scene, :@players)
      seats = (1..3).select { |i| players[i][2] > 0 }
      seats.map { |i| PokeAccess::I18n.t(:pkr_seat, :name => players[i][3], :n => players[i][0]) }.join(", ")
    end

    # The info key's line, as the table stands: the raise menu while it is open, the sums, every card in sight and the rivals' chips;
    # parked (Minigames.publish), as the table's messages run over the map, whose frames take the key back.
    # param sight the table's cards up: the deal passes none, as the new five are drawn while @comcards still counts the last hand's
    # param own the player's cards up: none from a hand's end to the next deal
    def self.publish(scene, sight = table(scene), own = hand(scene))
      whole = menu_parts(scene) + [sums(scene)]
      whole.push(PokeAccess::I18n.t(:pkr_your_hand, :list => own.join(", "))) unless own.empty?
      whole.push(PokeAccess::I18n.t(:pkr_table, :list => sight.join(", "))) unless sight.empty?
      whole.concat(scene.instance_variable_get(:@access_pkr_shown) || [])
      seats = rivals(scene)
      whole.push(seats) unless seats.empty?
      PokeAccess::Minigames.publish(scene, PokeAccess.sentences(whole))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Ahead of each move: the table's cards when they turned; ahead of the player's, the sums lead the game's question.
    def self.turn(scene)
      turned(scene)
      publish(scene)
      PokeAccess.before_next_line(sums(scene)) if player_next?(scene)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The hands shown when the round ends: every other player still in it, kept on the info key while they stay painted.
    def self.showdown(scene)
      players = PokeAccess.ivar(scene, :@players)
      shown = (1..3).select { |i| players[i][1] == 1 }.map do |i|
        hand = cards(scene, "@player#{i + 1}card1".to_sym, "@player#{i + 1}card2".to_sym)
        PokeAccess::I18n.t(:pkr_shows, :name => players[i][3], :list => hand.join(", "))
      end
      shown.each { |line| PokeAccess.speak(line, false) }
      PokeAccess::Cursor.reset(scene, :pkr_table)
      scene.instance_variable_set(:@access_pkr_shown, shown)
      publish(scene)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The pot painted: emptied, it is the hand's end, where roundwinner puts every card away with no frame between.
    def self.pot_painted(scene)
      return publish(scene) unless PokeAccess.ivar_i(scene, :@pot).zero?
      scene.instance_variable_set(:@access_pkr_shown, nil)
      publish(scene, [], [])
    end

    # The raise menu as it opens: its title and keys, which the first row (betscene's first updateselect) then goes behind.
    def self.raise_menu(scene)
      keys = PokeAccess::I18n.t(:pkr_raise_keys, :c => PokeAccess::KeyHints.key(:c, "C"), :b => PokeAccess::KeyHints.key(:b, "X"))
      PokeAccess.speak(PokeAccess::Verbosity.with_hint(PokeAccess::I18n.t(:pkr_raise_menu), keys), false)
      scene.instance_variable_set(:@access_pkr_menu, :opening)
    end

    # The raise menu closed: the info key goes back to the table alone.
    def self.raise_closed(scene)
      scene.instance_variable_set(:@access_pkr_menu, nil)
      publish(scene)
    end

    # The words of the row under the menu's arrow, or nil.
    def self.row_words(scene)
      row = RAISE_ROWS[PokeAccess.ivar_i(scene, :@select)]
      row.is_a?(Symbol) ? PokeAccess::I18n.t(row) : row
    end

    # The info key's part for the raise menu while it is open: the sum it stands at and the row under its arrow.
    def self.menu_parts(scene)
      return [] unless scene.instance_variable_get(:@access_pkr_menu)
      [PokeAccess::I18n.t(:pkr_raise, :n => PokeAccess.ivar_i(scene, :@raisevalue)), PokeAccess::I18n.t(:pkr_row, :row => row_words(scene))]
    end

    # The row of the raise menu under its arrow, cutting the last one in, queued as the menu opens.
    def self.raise_row(scene)
      words = row_words(scene)
      return unless words
      opening = scene.instance_variable_get(:@access_pkr_menu) == :opening
      scene.instance_variable_set(:@access_pkr_menu, :open) if opening
      PokeAccess.speak(words, !opening)
      publish(scene)
    end

    # The sum the raise stands at, as the menu's box paints it.
    def self.raised(scene)
      PokeAccess.speak(PokeAccess::I18n.t(:pkr_raise, :n => PokeAccess.ivar_i(scene, :@raisevalue)), true)
      publish(scene)
    end
  end
end

PokeAccess::Hooks.after_hook("Pokepoker", :drawcards, :optional => true, :hook_container => true) do |scene, _ret, _args|
  PokeAccess::PokePoker.dealt(scene)
end
[:fsubround, :osubround].each do |meth|
  PokeAccess::Hooks.before_hook("Pokepoker", meth, :optional => true) { |scene, _args| PokeAccess::PokePoker.turn(scene) }
end
PokeAccess::Hooks.before_hook("Pokepoker", :roundwinner, :optional => true) do |scene, _args|
  PokeAccess::PokePoker.showdown(scene)
end
PokeAccess::Hooks.after_hook("Pokepoker", :updatepot, :optional => true, :hook_container => true) do |scene, _ret, _args|
  PokeAccess::PokePoker.pot_painted(scene)
end
PokeAccess::Hooks.before_hook("Pokepoker", :betscene, :optional => true) { |scene, _args| PokeAccess::PokePoker.raise_menu(scene) }
PokeAccess::Hooks.after_hook("Pokepoker", :betscene, :optional => true, :hook_container => true) do |scene, _ret, _args|
  PokeAccess::PokePoker.raise_closed(scene)
end
PokeAccess::Hooks.after_hook("Pokepoker", :updateselect, :optional => true) do |scene, _ret, _args|
  PokeAccess::PokePoker.raise_row(scene)
end
PokeAccess::Hooks.after_hook("Pokepoker", :updatebet, :optional => true, :hook_container => true) do |scene, _ret, _args|
  PokeAccess::PokePoker.raised(scene)
end
PokeAccess::Hooks.after_hook("Pokepoker", :updatechips, :optional => true, :hook_container => true) do |scene, _ret, _args|
  PokeAccess::PokePoker.publish(scene)
end
PokeAccess::Hooks.before_hook("Pokepoker", :pokerdispose, :optional => true) { |_scene, _args| PokeAccess::Minigames.unpublish }
