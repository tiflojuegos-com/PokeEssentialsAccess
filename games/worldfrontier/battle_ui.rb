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

    # The item splash's two lines: the item, then "de" its holder, as the bar paints them; nil without an item.
    def self.item_splash(battler, item)
      item ||= (battler.item rescue nil)
      item ||= (battler.effects[PBEffects::GemConsumed] rescue nil)
      name = item ? (GameData::Item.get(item).name rescue nil) : nil
      return nil if name.nil? || name.to_s.empty?
      "#{name} #{_INTL('de {1}', battler.name)}"
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

PokeAccess::Game.define("worldfrontier") do
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
  # The splash is a blocking animation, said before it; it runs only with the ability splash on.
  before("WFItemSplashScene", :pbShowItemSplash) do |_scene, args|
    shown = (::Battle::Scene::USE_ITEM_SPLASH rescue false)
    text = shown && args[0] ? PokeAccess::WfBattleBox.item_splash(args[0], args[1]) : nil
    PokeAccess.speak_clean(text, false) if text
  end
  # The key buttons, shown or hidden on each menu window and info panel the game opens or closes.
  after("Battle::Scene", :wf_update_info_buttons) { |scene, _ret, _args| PokeAccess::WfMenuKeys.shown(scene) }
  poll_each_frame { PokeAccess::WfMenuKeys.release }
end
