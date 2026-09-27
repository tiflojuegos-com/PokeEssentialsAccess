# IF2H's Pokeblock kit: the kit menu (PokeblockKit_Scene), the blender's berry picker (its list data in @bag and
# @filterlist, so it has its own extractor), the Pokeblock case and the condition screen.
module PokeAccess
  module HoennPokeblocks
    # A berry row as the list paints it: name and remaining quantity (stock minus those thrown in), or the close
    # row; the focused berry's description and block colour go to the info key.
    def self.berry_row(win, i)
      if i == win.itemCount - 1
        set_focus_info(win)
        ((_INTL("CLOSE BAG") rescue "CLOSE BAG")).to_s
      else
        bag = win.instance_variable_get(:@bag)
        fl  = win.instance_variable_get(:@filterlist)
        pocket = bag.pockets[::PokeblockSettings::BERRY_POCKET_OF_BAG]
        entry = (fl && fl[i]) ? pocket[fl[i]] : nil
        return nil unless entry
        name = (win.instance_variable_get(:@adapter).getDisplayName(entry[0]) rescue nil)
        name = (::GameData::Item.get(entry[0]).name.to_s rescue entry[0].to_s) if name.nil?
        scene = win.instance_variable_get(:@scene)
        qty = entry[1].to_i
        qty -= (scene.selectedBerries.count(::GameData::Item.get(entry[0])) rescue 0)
        set_focus_info(win)
        "#{name}: #{qty}"
      end
    end

    # The flavours in the order the block panel lists them, and the conditions in the order the condition
    # graph draws them.
    FLAVOR_KEYS = [:bdx_fl_spicy, :bdx_fl_dry, :bdx_fl_sweet, :bdx_fl_bitter, :bdx_fl_sour]
    CONDITION_KEYS = [:cnd_cool, :cnd_beauty, :cnd_cute, :cnd_smart, :cnd_tough]
    CONDITION_MAX = 255

    # The game's two switches for what its screens leave out: the simplified blending drops a block's level,
    # and with either of them on there is no feel and no sheen.
    def self.simple?; (::PokeblockSettings::SIMPLIFIED_BERRY_BLENDING rescue false) ? true : false; end
    def self.plain?; simple? || ((::PokeblockSettings::DONT_USE_SHEEN rescue false) ? true : false); end

    # A Pokeblock case row: the block's name, then from medium its level, flavours and feel (the side panel), or
    # the close row, which clears the info key; the info key keeps a block's whole row.
    def self.case_row(win, i)
      list = PokeAccess.ivar(win, :@list) || []
      if i >= list.length
        PokeAccess::Info.clear_text
        return ((_INTL("CLOSE CASE") rescue "CLOSE CASE")).to_s
      end
      b = list[i]
      parts = [[b.name.to_s, :brief]]
      parts.push([PokeAccess::I18n.t(:dbk_level, :n => b.level), :medium]) if b.level && !simple?
      flavors = []
      FLAVOR_KEYS.each_with_index { |k, j| flavors.push(PokeAccess::I18n.t(k)) if (b.flavor[j] rescue 0).to_i > 0 }
      parts.push([PokeAccess::I18n.t(:pbk_flavors, :list => flavors.join(", ")), :medium]) unless flavors.empty?
      parts.push([PokeAccess::I18n.t(:pbk_feel, :n => b.smoothness), :medium]) unless plain?
      PokeAccess::Verbosity.info_line(:bag_item, parts)
    end

    # The Pokemon the condition screen shows, published to the info key with its row whole for Ctrl+T.
    def self.condition_text(scene)
      pk = (PokeAccess.ivar(scene, :@party)[PokeAccess.ivar(scene, :@index)] rescue nil)
      return nil unless pk
      PokeAccess::Info.set_info(:pokemon, pk, PokeAccess::Verbosity.whole { condition_line(pk) })
      condition_line(pk)
    rescue StandardError
      nil
    end

    # A member's row: the name and the conditions its graph draws (each flagged at its maximum), then the level
    # from medium, and the sex sign, shiny star and nature in full.
    def self.condition_line(pk)
      name = PokeAccess.clean(pk.name.to_s)
      signed = [name, PokeAccess::Party.gender_glyph(pk)].compact.join(" ")
      nature = PokeAccess::I18n.t(:sm_nature, :n => pk.nature.name)
      conds = PokeAccess::I18n.t(:pbk_conditions, :list => conditions(pk).map { |k, v| condition_word(k, v) }.join(", "))
      parts = [[PokeAccess::Verbosity.keep?(:party, :full) ? signed : name, :brief]]
      parts.push([PokeAccess::I18n.t(:pk_shiny), :full]) if PokeAccess::Party.shiny?(pk)
      parts.push([PokeAccess::I18n.t(:dbk_level, :n => pk.level), :medium])
      parts.push([nature, :full])
      parts.push([conds, :brief])
      PokeAccess::Verbosity.line(:party, parts)
    end

    # The conditions the screen draws, as [key, value] pairs: the five, and the sheen where the game keeps it.
    def self.conditions(pk)
      pairs = CONDITION_KEYS.zip([pk.cool, pk.beauty, pk.cute, pk.smart, pk.tough])
      pairs.push([:cnd_sheen, pk.sheen]) unless plain?
      pairs
    end

    def self.condition_word(key, value)
      w = "#{PokeAccess::I18n.t(key)} #{value.to_i}"
      value.to_i >= CONDITION_MAX ? "#{w} #{PokeAccess::I18n.t(:cnd_max)}" : w
    end

    # A block is about to be eaten: the conditions as they stand, kept until the bars move.
    def self.feeding(scene)
      pk = (PokeAccess.ivar(scene, :@party)[PokeAccess.ivar(scene, :@index)] rescue nil)
      @fed = pk
      @before = pk ? conditions(pk).map { |_k, v| v.to_i } : nil
    rescue StandardError
      @fed = nil
    end

    # After the bars move: the conditions that rose (the ones the screen marks with an arrow) and their values,
    # queued; nothing when none rose.
    def self.fed
      pk = @fed
      before = @before
      @fed = nil
      @before = nil
      return unless pk && before
      rose = []
      conditions(pk).each_with_index { |(k, v), i| rose.push(condition_word(k, v)) if v.to_i > before[i].to_i }
      PokeAccess.speak(PokeAccess::I18n.t(:pbk_rose, :list => rose.join(", ")), false) unless rose.empty?
    rescue StandardError
      nil
    end

    def self.set_focus_info(win)
      it = (win.item rescue nil)
      return PokeAccess::Info.clear_text unless it
      d = (::GameData::Item.get(it).description.to_s rescue "")
      c = (::GameData::BerryData.get(it).block_color_name.to_s rescue "")
      t = [d, c].reject { |s| s.to_s.empty? }.join(" ")
      PokeAccess::Info.set_info(:text, t.empty? ? nil : PokeAccess.clean(t))
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Menus.def_extractor("Window_MultiBerrySelection") { |win, i| PokeAccess::HoennPokeblocks.berry_row(win, i) }

# The Pokeblock case, the condition screen and the blender's chosen berries.
PokeAccess::Game.define("infinitefusion_hoenn") do
  screen_reader("Window_PokeblockCase") { |win, i| PokeAccess::HoennPokeblocks.case_row(win, i) }

  # The condition screen redraws on every party move; keyed on the index and the line, so two members that read
  # alike are both said. The first reading queues.
  after("PokeblockCondition_Scene", :pbDrawPokemonInfo) do |scene, _r, _a|
    t = PokeAccess::HoennPokeblocks.condition_text(scene)
    PokeAccess::Cursor.announce(scene, :pbk_cond, [PokeAccess.ivar(scene, :@index), t], true, false) { t } if t
  end
  after("PokeblockCase_Scene", :pbEndScene, :optional => true) { |_s, _r, _a| PokeAccess::Info.clear_text }

  # Feeding moves the bars without redrawing the Pokemon, and then waits for a key under the arrows.
  before("PokeblockCondition_Scene", :pbAtePokeblock) { |scene, _a| PokeAccess::HoennPokeblocks.feeding(scene) }
  after("PokeblockCondition_Scene", :pbUpdateConditionBars) { |_scene, _r, _a| PokeAccess::HoennPokeblocks.fed }

  # The chosen berries show only as icons, so their count is said when it changes (pbRefresh follows each one).
  after("MultiBerrySelection_Scene", :pbRefresh) do |scene, _r, _a|
    n = (scene.selectedBerries.length rescue nil)
    if n && PokeAccess::Cursor.changed?(scene, :mbs_sel, n) && n > 0
      PokeAccess.speak(PokeAccess::I18n.t(:pbk_selected, :n => n, :tot => 4), false)
    end
  end
end

PokeAccess::SceneWatcher.reader("PokeblockKit_Scene", :pbScene, :pbk_kit) do |s|
  cmds = PokeAccess.ivar(s, :@commands)
  idx  = PokeAccess.ivar(s, :@index)
  (cmds.is_a?(Array) && idx.is_a?(Integer) && cmds[idx]) ? [idx, lambda { PokeAccess.clean(cmds[idx].to_s) }] : nil
end
