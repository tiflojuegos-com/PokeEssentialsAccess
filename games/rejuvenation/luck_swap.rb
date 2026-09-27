module PokeAccess
  # The Luck Swap of Rejuvenation's Xen tower (LuckSwapScene): a row of balls chosen with left and right, the Pokemon
  # under the arrow named in large letters above it, and a help line under the row that tells which row is up: the
  # rentals to pick from, the party to swap from, then the rentals to swap in.
  module RejuvLuckSwap
    # The height at which the scene paints its help line.
    HELP_Y = 304

    # The Pokemon under the arrow as the screen names it, with its place in the row.
    def self.text(scene)
      name = PokeAccess.clean(scene.getMonDisplay.to_s)
      return nil if name.empty?
      pos = PokeAccess::I18n.t(:list_pos, :i => PokeAccess.ivar(scene, :@index) + 1, :n => PokeAccess.ivar(scene, :@length))
      [name, pos].join(", ")
    rescue StandardError
      nil
    end

    # The arrow's place: the row on show and the ball.
    def self.key(scene)
      [PokeAccess.ivar(scene, :@mode), PokeAccess.ivar(scene, :@party), PokeAccess.ivar(scene, :@index)]
    end

    # Says it when the arrow lands on a new ball: the first queued, later moves cutting in; held while a phase opens.
    def self.follow(scene)
      return if @phase
      PokeAccess::Cursor.announce(scene, :rj_luckswap, key(scene), true, false) { text(scene) }
    end

    # Runs a phase's opening (the pick or the swap starting, a party Pokemon swapped out or the swap undone) with the
    # arrow's reader held, then says the help line it painted and the Pokemon under the arrow: queued as the screen
    # opens, cutting in after.
    def self.phase(scene)
      ret = nil
      pairs = []
      @phase = true
      begin
        pairs = PokeAccess::PaintCapture.sample { ret = yield }
      ensure
        @phase = false
      end
      help = pairs.select { |r| r[3] == HELP_Y }.map { |r| PokeAccess.clean(r[0].to_s) }.last
      first = PokeAccess::Cursor.pending?(scene, :rj_luckswap)
      PokeAccess::Cursor.store(scene, :rj_luckswap, key(scene))
      PokeAccess.speak(PokeAccess.sentences([help, text(scene)]), !first)
      ret
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  after("LuckSwapScene", :pbUpdate, :optional => true) do |scene, _r, _a|
    PokeAccess::RejuvLuckSwap.follow(scene)
  end

  around("LuckSwapScene", :startLuckponPick, :optional => true) do |scene, nxt, _a|
    PokeAccess::RejuvLuckSwap.phase(scene) { nxt.call }
  end

  around("LuckSwapScene", :startLuckponSwap, :optional => true) do |scene, nxt, _a|
    PokeAccess::RejuvLuckSwap.phase(scene) { nxt.call }
  end

  around("LuckSwapScene", :pbSwapChosen, :optional => true) do |scene, nxt, _a|
    PokeAccess::RejuvLuckSwap.phase(scene) { nxt.call }
  end

  around("LuckSwapScene", :pbSwapCanceled, :optional => true) do |scene, nxt, _a|
    PokeAccess::RejuvLuckSwap.phase(scene) { nxt.call }
  end
end
