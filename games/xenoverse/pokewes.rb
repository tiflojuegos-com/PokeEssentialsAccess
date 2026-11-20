module PokeAccess
  # A Xenoverse screen that runs its own loop with one cursor: holds the scene while the loop runs (a stack, as the
  # Pokédex opens another Pokédex inside itself) and says the block's [key, line] whenever the key changes, the first
  # line queued after what opened the screen.
  class XenoverseCursorScreen
    # param slot the cursor's name
    def initialize(slot, &line)
      @slot, @line, @stack = slot, line, []
    end

    # Starts reading a screen that opens over the one before.
    def watch(scene)
      @stack.push(scene)
      @opening = true
      PokeAccess::Cursor.reset(self, @slot)
    end

    # Forgets the screen in front as it closes, and reads the one under it again.
    def unwatch
      @stack.pop
      PokeAccess::Info.clear_text
      PokeAccess::Cursor.reset(self, @slot)
    end

    # The screen in front, or nil.
    def scene
      @stack.last
    end

    # Says the line of the screen in front when its key changes.
    def poll
      return if @stack.empty?
      pair = @line.call(@stack.last, @opening)
      return unless pair.is_a?(Array) && !pair[0].nil? && !pair[1].to_s.empty?
      spoken = PokeAccess::Cursor.announce(self, @slot, pair[0], !@opening) do
        PokeAccess::Info.set_info(:text, pair[1])
        pair[1]
      end
      @opening = false if spoken
    end
  end

  # PokéWES (0197) and what it opens: its four apps (@index), the MN gems (MNScene), the achievements
  # (0129, AchievementsScreen) and the Pokédex (0216-0220: DexMain, DexInfo, DexSearch, DexSearchChoice).
  module XenoverseWES
    # The app under PokéWES's cursor, by the label painted for it; the Retrodex key's painted hint after the first.
    def self.app(scene, opening)
      index = PokeAccess.ivar(scene, :@index)
      labels = [:@text, :@text1, :@text2, :@text3].map { |iv| (PokeAccess.ivar(scene, iv)[0][0] rescue nil) }
      return nil unless index.is_a?(Integer) && labels[index]
      line = PokeAccess::Verbosity.list_entry(PokeAccess.clean(labels[index].to_s), index + 1, labels.length)
      retro = PokeAccess::XenoversePainted.of_sprite(PokeAccess.sprite(scene, "rd")).first
      line = PokeAccess::Verbosity.with_hint(line, retro) if opening && retro
      [index, line]
    end

    # The gem under the MN cursor: its painted name, whether it was won (switches 186-190, as the scene tests them)
    # and the description painted for it.
    def self.gem(scene, _opening)
      index = PokeAccess.ivar(scene, :@index)
      return nil unless index.is_a?(Integer) && index >= 0 && index < 5
      names = [:@name, :@name1, :@name2, :@name3, :@name4].map { |iv| (PokeAccess.ivar(scene, iv)[0][0] rescue nil) }
      overlays = [:@overlay, :@overlay1, :@overlay2, :@overlay3, :@overlay4].map { |iv| PokeAccess.ivar(scene, iv) }
      won = ($game_switches[186 + index] rescue nil)
      parts = [PokeAccess::Verbosity.list_entry(PokeAccess.clean(names[index].to_s), index + 1, 5)]
      parts.push(PokeAccess::I18n.t(:opt_unavailable)) if won == false
      parts.push(PokeAccess::XenoversePainted.of(overlays[index]).last)
      [index, PokeAccess.sentences(parts.compact)]
    end

    # The selected achievement as its row paints it: the title or ???, the description, then the progress.
    def self.achievement(scene, opening)
      index = PokeAccess.ivar(scene, :@index)
      total = PokeAccess.ivar(scene, :@amount)
      rows = PokeAccess::XenoversePainted.of_sprite(PokeAccess.sprite(scene, "item7"))
      return nil unless index.is_a?(Integer) && total.is_a?(Integer) && !rows.empty?
      progress, words = rows.partition { |r| r =~ /\A\d+\/\d+\z/ }
      words = words.uniq
      parts = [PokeAccess::Verbosity.list_entry(words.shift.to_s, index + 1, total)] + words + progress
      title = opening ? PokeAccess::XenoversePainted.of_sprite(PokeAccess.sprite(scene, "bg")).first : nil
      [[index, rows], PokeAccess.sentences([title].compact + parts)]
    end

    # The Pokémon under the Pokédex cursor: its name, or unknown, with its place in the list, and seen or caught; the
    # first time after the painted description and counts, and the Search and Xenodex keys as a hint.
    def self.dex(scene, opening)
      list = PokeAccess.ivar(scene, :@dexlist)
      index = PokeAccess.ivar(scene, :@selIndex)
      last = PokeAccess.ivar(scene, :@lastpokemonIndex)
      return nil unless list.is_a?(Array) && index.is_a?(Integer) && last.is_a?(Integer) && list[index]
      species = list[index]
      seen = ($Trainer.seen[species] rescue false)
      owned = ($Trainer.owned[species] rescue false)
      name = seen ? PokeAccess::Data.species_name(species).to_s : PokeAccess::I18n.t(:dex_unknown)
      line = PokeAccess::Verbosity.list_entry(name, index + 1, last + 1)
      line = "#{line}, #{PokeAccess::I18n.t(owned ? :dex_caught : :dex_seen)}" if seen
      line = dex_opening(scene, line) if opening
      [[list.object_id, index], line]
    end

    # The painted description and counts before the first line, Search and Xenodex after it as a hint.
    def self.dex_opening(scene, line)
      rows = PokeAccess::XenoversePainted.of_sprite(PokeAccess.sprite(scene, "overlay"))
      return line if rows.length < 4
      counts = PokeAccess::I18n.t(:dex_region_counts, :name => rows[3], :seen => rows[0], :owned => rows[1])
      text = PokeAccess.sentences([counts, line])
      PokeAccess::XenoversePainted.with_hint(text, [[rows[5], :y, "S"], [rows[6], :a, "Z"]])
    end

    # The field or button under the search cursor: a field's painted name and value, a button's label.
    def self.search(scene, _opening)
      index = PokeAccess.ivar(scene, :@fieldIndex)
      return nil unless index.is_a?(Integer)
      if index >= 7
        label = (PokeAccess.ivar(scene, :@buttonTexts)[index - 7] rescue nil)
        return label ? [index, PokeAccess.clean(label.to_s)] : nil
      end
      rows = PokeAccess::XenoversePainted.of_sprite(PokeAccess.sprite(scene, "field#{index}"))
      return nil if rows.empty?
      text = rows.length > 1 ? PokeAccess::I18n.t(:xenoverse_named, :name => rows[0], :text => rows[1]) : rows[0]
      [[index, text], text]
    end

    # The option under a search choice's cursor.
    def self.choice(scene, _opening)
      index = PokeAccess.ivar(scene, :@selectionIndex)
      options = PokeAccess.ivar(scene, :@input)
      return nil unless index.is_a?(Integer) && options.is_a?(Array) && options[index]
      [index, PokeAccess::Verbosity.list_entry(PokeAccess.clean(options[index].to_s), index + 1, options.length)]
    end

    # Says the Pokémon's page as updatePokemonInfo paints it, its number and name first.
    def self.info(rows)
      texts = rows.map { |r| PokeAccess.clean(r[0].to_s) }.reject { |t| t.empty? }
      return if texts.length < 2
      shiny = ["Show Shiny", "Hide Shiny"].map { |s| (_INTL(s) rescue s) }
      head = [texts[-1], texts[-2]]
      text = PokeAccess.sentences(head + texts[0, texts.length - 2].reject { |t| shiny.include?(t) })
      PokeAccess::Info.set_info(:text, text)
      PokeAccess.speak(text, true)
    end
  end
end

[["PokeWES", :commands, :xenoverse_wes, :app], ["MNScene", :initialize, :xenoverse_mn, :gem],
 ["AchievementsScreen", :openScene, :xenoverse_achievements, :achievement],
 ["DexMain", :inputHandle, :xenoverse_dex, :dex], ["DexSearch", :handleInput, :xenoverse_dex_search, :search],
 ["DexSearchChoice", :selectChoice, :xenoverse_dex_choice, :choice]].each do |cls, meth, slot, line|
  reader = PokeAccess::XenoverseCursorScreen.new(slot) { |scene, opening| PokeAccess::XenoverseWES.send(line, scene, opening) }
  PokeAccess::SceneWatcher.wire(cls, meth, reader)
end
PokeAccess::Game.define("xenoverse") do
  on_paint("DexInfo", :updatePokemonInfo) { |_info, rows, _a| PokeAccess::XenoverseWES.info(rows) }
  clear_info_on("DexInfo", :close)
end
