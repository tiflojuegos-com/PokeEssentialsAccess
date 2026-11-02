# World Frontier's battle screen ([WF] Battle UI and its patches): a databox with no level, a foe's hit points as a
# rounded percentage, the mega and Dynamax icons drawn outlined from a bitmap of their own and the Tera one cut from
# the type strip; the held item's splash (008_ItemSplash), a bar like the ability's with the item and its holder; and
# the key buttons beside the battle menus.
module PokeAccess
  module WfBattleBox
    # A foe's hit points as its box writes them: rounded, never 0 while it stands nor 100 while it is hurt.
    def self.percent(hp, total)
      return 0 if hp.to_i <= 0 || total.to_i <= 0
      pct = (hp.to_f * 100 / total.to_i).round
      pct = 99 if hp.to_i < total.to_i && pct >= 100
      pct < 1 ? 1 : pct
    end

    # The icon its edited move panel paints over a target (pbDrawTypeEffectiveness, from version 1.2.0): its type table
    # for that move, and the weather and the abilities it weighs; nil on an earlier panel.
    def self.move_icon(foe, type, scene = nil, move = nil, user = nil)
      return nil unless scene.respond_to?(:pbMoveInfoWeatherBlocksMove?)
      value = scene.pbMoveInfoTypeMod(type, foe, move)
      return 1 if scene.pbMoveInfoWeatherBlocksMove?(move, type)
      return 0 if value.nil?
      return 1 if scene.pbMoveInfoAllAbilitiesImmune?(user, foe, move, type, value) || Effectiveness.ineffective?(value)
      return 2 if Effectiveness.not_very_effective?(value)
      Effectiveness.super_effective?(value) ? 3 : 4
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end

  # The held item's splash: a bar with the item and its holder, shown ahead of the message about the item or of the
  # animation before it. Its words wait for that message and go ahead of it, or are dropped where it names both; a
  # splash no message follows is said as it leaves, or as the battle's scene ends with it still up.
  module WfItemSplash
    @pending = nil

    # The name of the item a splash shows for a battler, or nil without one.
    def self.item_name(battler, item)
      item ||= (battler.item rescue nil)
      item ||= (battler.effects[PBEffects::GemConsumed] rescue nil)
      name = item ? (GameData::Item.get(item).name rescue nil) : nil
      name.to_s.empty? ? nil : name.to_s
    end

    # Says any splash still waiting, then keeps this one's two lines as the bar paints them, the item and "de" its
    # holder, with both names, which a message must hold to stand for it.
    def self.hold(battler, item)
      flush
      name = item_name(battler, item)
      return unless name
      @pending = ["#{name} #{_INTL('de {1}', battler.name)}", name.downcase, battler.name.to_s.downcase]
    end

    # A message is about to be said: the waiting splash goes first, or is dropped where the message names it.
    def self.before_line(message)
      return unless @pending
      line = PokeAccess.clean(message.to_s).downcase
      return if line.empty?
      return flush unless line.include?(@pending[1]) && line.include?(@pending[2])
      @pending = nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Says the waiting splash, queued, once.
    def self.flush
      text = @pending ? @pending[0] : nil
      @pending = nil
      PokeAccess.speak_clean(text, false) if text
    end

    # Drops the waiting splash.
    def self.forget
      @pending = nil
    end
  end

  # The key buttons World Frontier shows beside its battle menus in place of the Enhanced Battle UI's prompt, which it
  # never lets show: "A: INFO" by both menus, "S: INFO MOV." by the fight menu's. Said as a key hint once per battle
  # and menu, queued after that menu's first line, while key hints are said.
  module WfMenuKeys
    # Each button: its sprite, the panel it opens, its button (JUMPUP, JUMPDOWN) and the key its picture draws.
    BUTTONS = [["button1", :dbk_prompt_info, :x, "A"], ["button3", :dbk_prompt_move, :y, "S"]]

    # The battle menus, by the window that holds each.
    MENUS = [[:command, "commandWindow"], [:fight, "fightWindow"]]

    @pending = nil

    # Holds the hint of the buttons the scene shows beside the menu up now, unless the battle gave that menu's; with
    # the buttons hidden (an info panel open) it holds none.
    def self.shown(scene)
      return unless PokeAccess::Verbosity.hints?
      menu = MENUS.find { |m| up?(scene, m[1]) }
      return if menu.nil? || heard(scene).include?(menu[0])
      parts = BUTTONS.select { |b| up?(scene, b[0]) }.map do |b|
        PokeAccess::I18n.t(:hint_label_key, :label => PokeAccess::I18n.t(b[1]),
                                            :key => PokeAccess::KeyHints.key(b[2], b[3]))
      end
      @pending = parts.empty? ? nil : [scene, menu, PokeAccess.sentences(parts)]
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # From the frame poller: says the held hint, queued, if its menu still shows, and marks that menu's given.
    def self.release
      held = @pending
      return unless held
      @pending = nil
      scene, menu, line = held
      return unless up?(scene, menu[1])
      scene.instance_variable_set(:@access_menu_keys_heard, heard(scene) + [menu[0]])
      PokeAccess.speak(line, false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The menus whose hint a battle's scene has given.
    def self.heard(scene)
      PokeAccess.ivar(scene, :@access_menu_keys_heard) || []
    end

    # Whether the scene's sprite of that name shows.
    def self.up?(scene, key)
      sp = PokeAccess.sprite(scene, key)
      sp ? ((sp.visible rescue false) ? true : false) : false
    end
  end
end

PokeAccess::Battle.icon_mark(/\Atera_types\z/i, :bt_m_tera)

PokeAccess::Caches.register(:wf_item_splash) { PokeAccess::WfItemSplash.forget }

PokeAccess::Game.define("worldfrontier") do
  # The Battle Camera shows a battle's first message in its intro, then swallows the same call the battle makes for it
  # a moment later (@ebs_suppress_next_paused, which lets a brief message through): that call shows nothing.
  override("PokeAccess::BattleScene", :message_shown?) do |_mod, original, args|
    PokeAccess.ivar(args[0], :@ebs_suppress_next_paused) && !args[1][1] ? false : original.call
  end
  override("PokeAccess::Battle", :shown_level) { |_mod, _original, _args| nil }
  override("PokeAccess::Battle", :shown_hp) do |_mod, original, args|
    b = args[0]
    if args[1]
      PokeAccess::I18n.t(:bt_hp_pct, :n => PokeAccess::WfBattleBox.percent(b.hp, b.totalhp))
    else
      original.call
    end
  end
  before("Battle::Scene::PokemonDataBox", :wf_draw_outlined_special_icon) do |_box, args|
    PokeAccess::PaintCapture.note_icons([[args[0], args[1], args[2]]])
  end
  override("PokeAccess::DBKMoveInfo", :effect_index) do |_mod, original, args|
    PokeAccess::WfBattleBox.move_icon(*args) || original.call
  end
  # The splash runs only with the ability splash on. Held once it is up, as showing it first hides one still up, which
  # says that one. A container: the slide-in is a loop of frames.
  after("WFItemSplashScene", :pbShowItemSplash, :optional => true, :hook_container => true) do |_scene, _ret, args|
    shown = (::Battle::Scene::USE_ITEM_SPLASH rescue false)
    PokeAccess::WfItemSplash.hold(args[0], args[1]) if shown && args[0]
  end
  before("WFItemSplashScene", :pbHideItemSplashSide, :optional => true) { |_scene, _a| PokeAccess::WfItemSplash.flush }
  before("Battle::Scene", :pbEndBattle) { |_scene, _a| PokeAccess::WfItemSplash.flush }
  override(PokeAccess, :say_dialogue) do |_mod, original, args|
    PokeAccess::WfItemSplash.before_line(args[0])
    original.call
  end
  # The key buttons, shown or hidden on each menu window and info panel the game opens or closes.
  after("Battle::Scene", :wf_update_info_buttons) { |scene, _ret, _args| PokeAccess::WfMenuKeys.shown(scene) }
  poll_each_frame { PokeAccess::WfMenuKeys.release }
end
