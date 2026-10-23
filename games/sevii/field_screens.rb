module PokeAccess
  # Screens Sevii opens from its maps with no window to read: the Fossil Maniac's drawer (Drawer, a 5x2 grid of item
  # icons), the Game Corner's prize wheels (PrizeWheel), the caves' braille inscriptions (pbBrailleMessage), Drake's
  # book of pictures in Ever Grande (pbDrakeBook) and the banner a quest's start or end slides in (QuestAnim).
  module SeviiField
    # The lines the quest banner being built has painted, or nil outside one.
    @banner = nil

    # The drawer's slot under the cursor: its item or that it is empty, with its row and column.
    def self.drawer_slot(scene)
      sym = (PokeAccess.ivar(scene, :@Items) || [])[PokeAccess.ivar_i(scene, :@SelNo)]
      pos = { :row => PokeAccess.ivar_i(scene, :@SelRow) + 1, :col => PokeAccess.ivar_i(scene, :@SelCol) + 1 }
      return PokeAccess::I18n.t(:sv_slot_empty, pos) if sym.nil?
      PokeAccess::I18n.t(:sv_slot, pos.dup.merge!(:name => PokeAccess.clean(PBItems.getName(getID(PBItems, sym)))))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Says the drawer's slot when the cursor lands on another: the first one queued, as the drawer opens.
    def self.drawer_moved(scene, interrupt)
      PokeAccess::Cursor.announce(scene, :sv_drawer, PokeAccess.ivar_i(scene, :@SelNo), interrupt) { drawer_slot(scene) }
    end

    # A repaint of the drawer: the slot the cursor moved to, cutting in, or the same slot again, queued behind the
    # answer, after a No to taking its item (the only repaint that leaves the cursor where it was).
    def self.drawer_refreshed(scene)
      stayed = PokeAccess::Cursor.current(scene, :sv_drawer) == PokeAccess.ivar_i(scene, :@SelNo)
      PokeAccess::Cursor.reset(scene, :sv_drawer) if stayed
      drawer_moved(scene, !stayed)
    end

    # The drawer as it opens: its first slot, then its keys while key hints are said.
    def self.drawer_opened(scene)
      drawer_moved(scene, false)
      PokeAccess.speak(keys(:sv_drawer_keys, :take), false) if PokeAccess::Verbosity.hints?
    end

    # A screen's keys line: confirm doing what the key names (its placeholder act), cancel leaving.
    def self.keys(key, act)
      PokeAccess::I18n.t(key, act => PokeAccess::KeyHints.key(:c, PokeAccess::I18n.t(:key_enter)),
                              :quit => PokeAccess::KeyHints.key(:b, PokeAccess::I18n.t(:key_escape)))
    end

    # One prize as the wheel holds it: an item, a Pokemon, or an amount of coins or money.
    def self.prize(scene, p)
      item = getID(PBItems, p)
      return PokeAccess.clean(PBItems.getName(item)) if item > 0
      species = getID(PBSpecies, p)
      return PokeAccess.clean(PBSpecies.getName(species)) if species > 0
      PokeAccess::I18n.t(PokeAccess.ivar(scene, :@prizecoins) ? :sv_wheel_coins : :tr_money, :n => p.to_i)
    end

    # The wheel's ten prizes in its order, said as it opens, queued, then its keys while key hints are said.
    def self.wheel_opened(scene)
      list = (PokeAccess.ivar(scene, :@prizes) || []).map { |p| prize(scene, p) }
      return if list.empty?
      text = PokeAccess::I18n.t(:sv_wheel_prizes, :list => list.join(", "))
      PokeAccess.speak(PokeAccess::Verbosity.with_hint(text, keys(:sv_wheel_keys, :spin)), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
    end

    # Runs the banner a quest's start or end slides in (QuestAnim#initialize, which paints it, then waits for a key),
    # keeping the lines it paints.
    def self.quest_banner
      @banner = []
      yield
    ensure
      @banner = nil
    end

    # A line the banner paints. The second, "NEW QUEST" or "QUEST COMPLETE" under the quest's name, says both as a
    # line of dialogue, then the key that closes the banner while key hints are said.
    def self.banner_painted(text)
      return unless @banner
      @banner.push(PokeAccess.clean(text.to_s))
      return unless @banner.length == 2
      PokeAccess.say_dialogue(PokeAccess.sentences(@banner))
      return unless PokeAccess::Verbosity.hints?
      key = PokeAccess::KeyHints.key(:c, PokeAccess::I18n.t(:key_enter))
      PokeAccess.speak(PokeAccess::I18n.t(:title_press, :key => key), false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
    end
  end
end

PokeAccess::Game.define("sevii") do
  before("Drawer", :main) { |scene, _a| PokeAccess::SeviiField.drawer_opened(scene) }
  after("Drawer", :pbRefresh) { |scene, _r, _a| PokeAccess::SeviiField.drawer_refreshed(scene) }

  before("PrizeWheel", :main) { |scene, _a| PokeAccess::SeviiField.wheel_opened(scene) }

  # The text the window draws as dots, said as a line of dialogue, so the message history keeps the clue.
  kernel("pbBrailleMessage") do |args, _r|
    PokeAccess.say_dialogue(PokeAccess::I18n.t(:sv_braille, :text => PokeAccess.clean(args[0].to_s)))
  end

  around("QuestAnim", :initialize) { |_s, nxt, _a| PokeAccess::SeviiField.quest_banner { nxt.call } }
  kernel("pbDrawOutlineText") { |args, _r| PokeAccess::SeviiField.banner_painted(args[5]) }

  # The book's four pictures described, then the confirm key that closes it while key hints are said.
  kernel("pbDrakeBook") do |_args, _r|
    key = PokeAccess::KeyHints.key(:c, PokeAccess::I18n.t(:key_enter))
    hint = PokeAccess::I18n.t(:title_press, :key => key)
    PokeAccess.speak(PokeAccess::Verbosity.with_hint(PokeAccess::I18n.t(:sv_drake_book), hint, " "), true)
  end
end
