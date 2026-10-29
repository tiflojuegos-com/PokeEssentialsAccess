module PokeAccess
  # Rejuvenation's ability box (AbilityBoxes on): PokeBattle_Scene#pbShowAbilityBox slides in a battler's name and its
  # ability or item, often with no message that names them, and #pbChangeAbilityBox repaints it in place. Its line,
  # the game's own pbAbilityBoxToText, waits for what is said next, a message or an HP change, and goes ahead of it,
  # unless that message names both the battler and what the box shows; a box nothing follows is said as it leaves,
  # or as the battle's scene ends (#pbEndBattle) with it still on screen.
  module RejuvAbilityBox
    @pending = nil

    # The box on the battler's side of the scene, or nil where the game shows none.
    def self.box(scene, battler)
      PokeAccess.sprite(scene, (battler.index.to_i & 1) == 0 ? "abilityboxplayer" : "abilityboxfoe")
    end

    # What the battler's box displays while it is on screen (the game's getDisplayVars), else nil.
    def self.displayed(scene, battler)
      b = box(scene, battler)
      b && b.onscreen ? b.getDisplayVars : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Whether the battler's own box is on screen, the only one pbChangeAbilityBox repaints.
    def self.own_box_up?(scene, battler)
      b = box(scene, battler)
      b && b.onscreen && b.index == battler.index ? true : false
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # The keywords a call passed (item:, attrname:, message:), or none.
    def self.keywords(args)
      args.last.is_a?(Hash) ? args.last : {}
    end

    # Runs the game's pbShowAbilityBox (the block): a box that slid in for it, off screen before or showing something
    # else, waits with its line.
    def self.show(scene, args)
      before = displayed(scene, args[0])
      ret = yield
      now = displayed(scene, args[0])
      if now && now != before
        kw = keywords(args)
        hold(scene, args[0], kw[:item], kw[:attrname])
      end
      ret
    end

    # Runs the game's pbChangeAbilityBox (the block): the line of the box it repaints waits in place of the one before.
    def self.change(scene, args)
      up = own_box_up?(scene, args[0])
      ret = yield
      hold(scene, args[0]) if up
      ret
    end

    # Says any box still waiting, then keeps this one's line with the battler's name and the attribute the box paints,
    # both of which a message must name to stand for it.
    def self.hold(scene, battler, item = nil, attrname = nil)
      flush
      attr = PokeAccess.ivar(box(scene, battler), :@pokeattr)
      @pending = [scene.pbAbilityBoxToText(battler, item, attrname), battler.name.to_s, attr.to_s]
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Whether a line names both the waiting box's battler and what the box shows.
    def self.named?(line)
      t = line.to_s.downcase
      !@pending[2].empty? && t.include?(@pending[2].downcase) && t.include?(@pending[1].downcase)
    end

    # A message is about to be said: the waiting box goes first, or is dropped where the message names it.
    def self.before_line(message)
      return unless @pending
      line = PokeAccess.clean(message.to_s)
      return if line.empty?
      if named?(line)
        @pending = nil
      else
        flush
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A battler's HP is about to change: the waiting box goes ahead of that change, unless the message the change
    # shows (its message: keyword) names it, which then drops it.
    def self.before_hp(args)
      return unless @pending
      msg = keywords(args)[:message]
      flush unless msg && named?(PokeAccess.clean(msg.to_s))
    end

    # Says the waiting box's line, queued, once.
    def self.flush
      return unless @pending
      text = @pending[0]
      @pending = nil
      PokeAccess.speak_clean(text, false)
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  around("PokeBattle_Scene", :pbShowAbilityBox) do |scene, nxt, args|
    PokeAccess::RejuvAbilityBox.show(scene, args) { nxt.call }
  end

  around("PokeBattle_Scene", :pbChangeAbilityBox) do |scene, nxt, args|
    PokeAccess::RejuvAbilityBox.change(scene, args) { nxt.call }
  end

  before("PokeBattle_Scene", :pbHideAbilityBox) { |_s, _a| PokeAccess::RejuvAbilityBox.flush }

  before("PokeBattle_Scene", :pbEndBattle) { |_s, _a| PokeAccess::RejuvAbilityBox.flush }

  before("PokeBattle_Battler", :pbReduceHP) { |_b, args| PokeAccess::RejuvAbilityBox.before_hp(args) }

  before("PokeBattle_Battler", :pbRecoverHP) { |_b, args| PokeAccess::RejuvAbilityBox.before_hp(args) }

  override(PokeAccess, :say_dialogue) do |_mod, original, args|
    PokeAccess::RejuvAbilityBox.before_line(args[0])
    original.call
  end
end
