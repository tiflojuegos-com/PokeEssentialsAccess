# Ashen Frost's Blackjack (bo4p5687's minigame, edited: Blackjack minigame/*, a dealer and one player): the offers and the
# results are messages, so what is added is what it paints: the cards as each is turned up, the bet and the card sum, all of
# them on the info key while the game asks what to do.
module PokeAccess
  module AshenBlackjack
    SUITS = [:vp_hearts, :vp_diamonds, :vp_clubs, :vp_spades]
    FACES = { 0 => :vp_ace, 10 => :vp_jack, 11 => :vp_queen, 12 => :vp_king }

    # A card by its number: four suits to a value, the ace first (the deck's order, 1 - Init.rb).
    def self.card_name(value)
      rank = value / 4
      face = FACES[rank]
      PokeAccess::I18n.t(:vp_card_bare, :value => face ? PokeAccess::I18n.t(face) : (rank + 1).to_s,
                                        :suit => PokeAccess::I18n.t(SUITS[value % 4]))
    end

    # Says a card drawn face up, once per hand: the game draws the same card again when it opens a hand. The player's are
    # always face up; the dealer's only as drawCard shows them. The card sum it just painted follows, when it changed.
    def self.drawn(scene, args)
      name = args[0].to_s.to_sym
      table = PokeAccess.ivar(scene, :@player) || {}
      who = table[name]
      return unless who
      pos = args[1]
      return unless who[:status][pos] || who[:player]
      seen = scene.instance_variable_get(:@access_bj_seen) || []
      scene.instance_variable_set(:@access_bj_seen, seen)
      publish(scene)
      mark = [name, pos, who[:card][pos]]
      return if seen.include?(mark)
      seen.push(mark)
      owner = who[:player] ? :ashen_bj_you : :ashen_bj_dealer
      PokeAccess.speak(PokeAccess::I18n.t(owner, :card => card_name(who[:card][pos])), false)
      say_sum(scene) if who[:player]
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Keeps the sum its draw painted, to say it behind the card that made it.
    def self.note_sum(scene, rows)
      text = PokeAccess::PaintCapture.text(rows.map { |r| r[0] })
      scene.instance_variable_set(:@access_bj_sum, text) unless text.empty?
      publish(scene)
    end

    # Says the bet its draw painted, and keeps it for the info key.
    def self.note_bet(scene, rows)
      text = PokeAccess::PaintCapture.text(rows.map { |r| r[0] })
      scene.instance_variable_set(:@access_bj_bet, text)
      PokeAccess.speak(text, false)
      publish(scene)
    end

    # A hand's cards in sight, by name: the player's all, the dealer's those turned up.
    def self.hand(who)
      out = []
      who[:card].each_with_index { |card, i| out.push(card_name(card)) if who[:status][i] || who[:player] }
      out.join(", ")
    end

    # The info key's line: the player's cards and sum, the dealer's cards and the bet, as they stand.
    def self.publish(scene)
      table = PokeAccess.ivar(scene, :@player) || {}
      parts = []
      parts.push(PokeAccess::I18n.t(:pkr_your_hand, :list => hand(table[:player]))) if table[:player]
      parts.push(scene.instance_variable_get(:@access_bj_sum))
      parts.push(PokeAccess::I18n.t(:ashen_bj_dealer_hand, :list => hand(table[:dealer]))) if table[:dealer]
      parts.push(scene.instance_variable_get(:@access_bj_bet))
      text = PokeAccess.sentences(parts.compact)
      PokeAccess::Info.set_info(:text, text, text)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The sum painted last, unless it is the one already said.
    def self.say_sum(scene)
      text = scene.instance_variable_get(:@access_bj_sum)
      return unless text && PokeAccess::Cursor.changed?(scene, :ashen_bj_sum, text)
      PokeAccess.speak(text, false)
    end

    # A new hand: nothing is said on sight of its cards yet.
    def self.new_hand(scene)
      scene.instance_variable_set(:@access_bj_seen, [])
      PokeAccess::Cursor.reset(scene, :ashen_bj_sum)
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  after("BlackJack::Play", :drawCard) { |scene, _ret, args| PokeAccess::AshenBlackjack.drawn(scene, args) }
  on_paint("BlackJack::Play", :drawTxtSum) { |scene, rows, _args| PokeAccess::AshenBlackjack.note_sum(scene, rows) }
  on_paint("BlackJack::Play", :drawTxtBet) { |scene, rows, _args| PokeAccess::AshenBlackjack.note_bet(scene, rows) }
  before("BlackJack::Play", :clearCard) { |scene, _args| PokeAccess::AshenBlackjack.new_hand(scene) }
  clear_info_on("BlackJack::Play", :endScene)
end
