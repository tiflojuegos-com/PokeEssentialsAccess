# Reminiscencia's upgrade tree (ScrollTree: @selec picks one of five stats, $Trainer.buffStatFriend holds [cost,
# percent] pairs), its help screen (AyudasUI) and the world map's place panel (OpenWorldMap).
module PokeAccess
  module ReminExtras
    STATS = [:rem_st_atk, :rem_st_spatk, :rem_st_def, :rem_st_spdef, :rem_st_speed]
    @help = nil

    # Voices the focused stat, its bonus and the next level's cost (marked when the coins fall short), again after a
    # purchase; the coins come with the opening read and with a purchase.
    # param purchase true after raiseStat
    def self.scroll_tree(scene, purchase = false)
      idx = PokeAccess.ivar(scene, :@selec)
      return unless idx.is_a?(Integer) && idx >= 0 && idx < STATS.length
      key = [idx, ($Trainer.buffStatFriend[idx].dup rescue nil)]
      first = PokeAccess::Cursor.pending?(scene, :rem_tree)
      PokeAccess::Cursor.announce(scene, :rem_tree, key, true) do
        row = ($Trainer.buffStatFriend[idx] rescue nil)
        name = PokeAccess::I18n.t(STATS[idx])
        coins = ($PokemonBag.pbQuantity(:COIN) rescue nil)
        if row.is_a?(Array)
          parts = [[name, :brief], [PokeAccess::I18n.t(:rem_tree_bonus, :pct => row[1].to_i), :medium],
                   [PokeAccess::I18n.t(:rem_tree_cost, :cost => row[0].to_i), :brief]]
          parts.push([PokeAccess::I18n.t(:rem_tree_short), :brief]) if coins && row[0].to_i > coins.to_i
          parts.push([PokeAccess::I18n.t(:rem_coins, :n => coins.to_i), :brief]) if coins && (first || purchase)
          PokeAccess::Verbosity.info_line(:shop_item, parts)
        else
          name
        end
      end
    rescue StandardError
      nil
    end

    # Arms the capture while AyudasUI or OpenWorldMap paints (the map's drawInfo paints the focused place, "???"
    # when unvisited); the dedup is cleared on entry, so reopening a section reads it again.
    def self.help_on(scene)
      @help = scene
      PokeAccess::Cursor.reset(scene, :rem_help_info)
    end

    def self.help_off
      PokeAccess::Cursor.reset(@list, :rem_help_list) if @list
      @help = nil
    end

    # The help screen's section list, held during its update (the screen's loop) and read by the per-frame poll.
    @list = nil

    def self.list_on(scene); @list = scene; end
    def self.list_off; @list = nil; end
    def self.list_poll; help_section(@list) if @list; end

    # A help section's paragraph (drawTextEx, text in argument 5), queued; only what is painted on the help's own
    # "desc" panel, not a text-entry prompt drawn through the same function.
    def self.help_body(bitmap, text)
      return unless @help && bitmap
      panel = (PokeAccess.sprite(@help, "desc") rescue nil)
      return unless panel && (panel.bitmap.equal?(bitmap) rescue false)
      t = PokeAccess.clean(text.to_s)
      return if t.empty?
      PokeAccess.speak(t, false)
    rescue StandardError
      nil
    end

    # The help screen's ten image-only sections: [tag the section checks before opening (nil: always open), label].
    HELP_SECTIONS = [[nil, :rem_help_controls], ["pokemon", :rem_help_pokemon], ["objetos", :rem_help_items],
                     ["capturas", :rem_help_catching], ["phione", :rem_help_phione],
                     ["ubicaciones", :rem_help_places], ["auxilio", :rem_help_rescue],
                     ["alarmado", :rem_help_alarm], ["cartas", :rem_help_blessings],
                     ["cartas", :rem_help_upgrades]]

    # Speaks the focused section on every move, with its position and whether it is still locked; a section past the
    # ones the player has unlocked is painted "???" (HelpUI/unknown), said as the word for an unknown one.
    def self.help_section(scene)
      idx = PokeAccess.ivar(scene, :@index)
      total = (numeroOpcionesAyudas rescue HELP_SECTIONS.length)
      return unless idx.is_a?(Integer) && idx >= 0 && idx < HELP_SECTIONS.length
      tag, key = HELP_SECTIONS[idx]
      open = tag.nil? || ($Trainer.ayudasUI.include?(tag) rescue true)
      hidden = (idx > $Trainer.ayudasUI.length - 1 rescue false)
      name = PokeAccess::I18n.t(hidden ? :rem_help_unknown : key)
      name = "#{name}, #{PokeAccess::I18n.t(:rem_help_locked)}" unless open
      PokeAccess::Cursor.announce(scene, :rem_help_list, idx, true) do
        PokeAccess::Verbosity.list_entry(name, idx + 1, total)
      end
    rescue StandardError
      nil
    end

    # True when the bitmap is the held screen's own text panel: "desc" (AyudasUI) or "info" (OpenWorldMap).
    def self.own_panel?(bitmap)
      return false unless bitmap
      ["desc", "info"].any? do |n|
        p = (PokeAccess.sprite(@help, n) rescue nil)
        p && (p.bitmap.equal?(bitmap) rescue false)
      end
    end

    # Speaks what the held screen paints on its own panel; the world map's "???" for a place never visited is said as
    # the word for it, since a screen reader drops the question marks.
    def self.help_text(bitmap, rows)
      return unless @help && rows.is_a?(Array)
      return unless own_panel?(bitmap)
      lines = []
      rows.each do |r|
        t = (r.is_a?(Array) ? r[0] : nil)
        t = PokeAccess.clean(t.to_s) if t
        t = PokeAccess::I18n.t(:rem_map_unvisited) if t =~ /\A\?+\z/
        lines.push(t) if t && !t.empty?
      end
      return if lines.empty?
      t = lines.join(". ")
      PokeAccess::Cursor.announce(@help, :rem_help_info, t, true) { t }
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("reminiscencia") do
  # The upgrade tree after positionSelector (at setup and on every move) and raiseStat (a purchase); makeloop is the
  # blocking loop, which an after-hook would only reach on the way out. Its row leaves the info key at pbEndScene.
  after("ScrollTree", :positionSelector) { |s, _r, _a| PokeAccess::ReminExtras.scroll_tree(s) }
  after("ScrollTree", :raiseStat) { |s, _r, _a| PokeAccess::ReminExtras.scroll_tree(s, true) }
  after("ScrollTree", :pbEndScene, :optional => true) { |_s, _r, _a| PokeAccess::Info.clear_text }

  [["AyudasUI", :chosenOption], ["OpenWorldMap", :drawInfo]].each do |cname, meth|
    around(cname, meth) do |scene, nxt, _a|
      PokeAccess::ReminExtras.help_on(scene)
      begin
        nxt.call
      ensure
        PokeAccess::ReminExtras.help_off
      end
    end
  end
  around("AyudasUI", :update) do |s, nxt, _a|
    PokeAccess::ReminExtras.list_on(s)
    begin; nxt.call; ensure; PokeAccess::ReminExtras.list_off; end
  end
  # AyudasUI and ScrollTree run whole inside their constructor, from the pause menu's loop: declared so that leaving
  # one says the menu's focus again.
  [["AyudasUI", :initialize], ["ScrollTree", :initialize]].each { |cname, meth| PokeAccess::MenuReturn.bare(cname, meth) }
  poll_each_frame { PokeAccess::ReminExtras.list_poll }
  kernel("pbDrawTextPositions", :before) { |args, _r| PokeAccess::ReminExtras.help_text(args[0], args[1]) }
  kernel("drawTextEx", :before) { |args, _r| PokeAccess::ReminExtras.help_body(args[0], args[5]) }
end
