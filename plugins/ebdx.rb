module PokeAccess
  # Elite Battle: DX, which swaps the stock battle menus for windows of its own, as its v19.1 release and the v21 port
  # draw them alike: the command buttons, the move buttons with their mechanic buttons (Mega Evolution, and the ZUD
  # patch's Ultra Burst, Z-Move and Dynamax), the target buttons, the battle questions' choice boxes, the battle bag,
  # the databox marks, the party lineups, the opponent who comes on to speak and the Pokedex page a capture shows.
  module Ebdx
    # The PP a move button writes, "15/15".
    PP_TEXT = /\A\s*(\d+)\s*\/\s*(\d+)\s*\z/

    # The fight menu's mechanic buttons as [mechanic, flag that shows it, its sprite].
    BUTTONS = [[:mega, :@showMega, :@megaButton], [:ultra, :@showUltra, :@ultraButton],
               [:zmove, :@showZMove, :@zMoveButton], [:dynamax, :@showDynamax, :@dynaButton]]

    # Keeps the labels compileCommands returns, the buttons refreshCommands paints, and forgets the focused one so the
    # menu's opening reads it again; where the player's side holds several Pokemon, first says, queued, the one whose
    # databox the menu marks.
    def self.commands_drawn(win, labels, idx)
      win.instance_variable_set(:@access_cmds, labels)
      PokeAccess::Cursor.reset(win, :ebdx_cmd)
      PokeAccess::Info.set_info(:battle_foe, nil)
      battle = PokeAccess.ivar(win, :@battle)
      return unless battle && (battle.pbSideSize(0) rescue 1).to_i > 1
      b = (battle.battlers[idx] rescue nil)
      PokeAccess.speak(b.name, false) if b && (b.pokemon rescue nil)
    end

    # Says the focused command button once per change, the first after an opening queued.
    def self.command_focus(win)
      labels = PokeAccess.ivar(win, :@access_cmds)
      idx = PokeAccess.ivar(win, :@index)
      return unless labels.is_a?(Array) && idx.is_a?(Integer) && labels[idx]
      PokeAccess::Cursor.announce(win, :ebdx_cmd, [idx, labels[idx]], true, false) { labels[idx] }
    end

    # Notes a string pbDrawOutlineText paints while move buttons are drawn.
    def self.outlined(text)
      @outlines.push(text.to_s) if @outlines
    end

    # Runs a generateButtons keeping on the window, per move button, the name and the PP it paints.
    def self.buttons_drawn(win)
      @outlines = []
      yield
    ensure
      rows = @outlines || []
      @outlines = nil
      keep_buttons(win, rows)
    end

    # The outline texts of the buttons in paint order, each name followed by its PP, as [name, "15/15"] pairs.
    def self.keep_buttons(win, rows)
      moves = []
      rows.each do |t|
        if t =~ PP_TEXT && moves.last && moves.last[1].nil?
          moves.last[1] = t
        else
          moves.push([t, nil])
        end
      end
      win.instance_variable_set(:@access_moves, moves)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Forgets the focused move, the painted buttons and the mechanic buttons as the menu opens for a battler.
    def self.fight_opened(win)
      PokeAccess::Cursor.reset(win, :ebdx_move)
      win.instance_variable_set(:@access_moves, nil)
      win.instance_variable_set(:@access_buttons, {})
    end

    # A mechanic button as the core's toggles count it: 0 hidden, 1 shown, 2 pressed (its sprite on its lit half).
    def self.button_state(win, shown, sprite)
      return 0 unless PokeAccess.ivar(win, shown)
      sp = PokeAccess.ivar(win, sprite)
      (sp && sp.src_rect.x > 0) ? 2 : 1
    end

    # Each frame of the fight menu: a mechanic button pressed or released is said at once, then the focused move once
    # per change (again when its button is repainted under another name), queued on opening and after a toggle, then
    # a button that came up available.
    def self.fight_focus(win)
      states = PokeAccess.ivar(win, :@access_buttons)
      states = win.instance_variable_set(:@access_buttons, {}) unless states.is_a?(Hash)
      ready = []
      toggled = false
      BUTTONS.each do |mech, shown, sprite|
        v = button_state(win, shown, sprite)
        last = states[mech]
        states[mech] = v
        if PokeAccess::Battle.mega_reveal?(last, v)
          ready.push(PokeAccess::Battle.ready_text(mech))
        else
          k = PokeAccess::Battle.zud_key(mech, last, v)
          next unless k
          PokeAccess.speak(k.is_a?(Array) ? PokeAccess::I18n.t(k[0], :name => PokeAccess::I18n.t(k[1])) :
                                            PokeAccess::I18n.t(k), true)
          toggled = true
        end
      end
      read_move(win, !toggled)
      ready.each { |t| PokeAccess.speak(t, false) }
    end

    # Says the move under the cursor once per change of slot or of what its button paints; the move's own name and PP
    # stand in for a button whose paint was not caught.
    # param interrupt false right after a toggle, so the move follows the toggle's line
    def self.read_move(win, interrupt)
      idx = PokeAccess.ivar(win, :@index)
      return unless idx.is_a?(Integer) && idx >= 0
      battler = PokeAccess.ivar(win, :@battler)
      move = battler ? (battler.moves[idx] rescue nil) : nil
      return unless move && PokeAccess::MoveInfo.real_id?(PokeAccess::MoveInfo.id_of(move))
      painted = (PokeAccess.ivar(win, :@access_moves) || [])[idx] || [(move.name rescue nil), nil]
      PokeAccess::Cursor.announce(win, :ebdx_move, [idx, painted], interrupt, false) do
        move_line(win, idx, move, painted)
      end
    end

    # A move button's line at the battle_move level: the name it paints (whole where the button cut it short), the
    # type and category its icons show and the PP it writes, with the power and accuracy the stock menu's reading gives.
    def self.move_line(win, idx, move, painted)
      PokeAccess::Info.set_info(:move, move)
      data = (GameData::Move.get(move.id) rescue nil)
      ty = data ? (GameData::Type.get(data.type).name rescue nil) : nil
      pp, tot = pp_of(painted[1], move)
      PokeAccess::MoveInfo.leveled(:battle_move, whole_name(painted[0], move), ty,
                                   PokeAccess.attr_of(move, :power, :baseDamage), (move.accuracy rescue 0),
                                   :cat => PokeAccess::MoveInfo.category_word(button_category(win, idx, move)),
                                   :pp => pp, :total_pp => tot)
    end

    # A painted move name, said whole where the button cut it short ("All-Out Pummel..."), keeping the "Z-" ZUD puts
    # before a status move.
    def self.whole_name(painted, move)
      return painted unless painted.to_s =~ /\A(Z-)?(.+?)\.\.\.\z/
      pre = $1
      stem = $2
      full = (move.name rescue nil).to_s
      full.index(stem) == 0 ? "#{pre}#{full}" : painted
    end

    # The PP a button writes, as [left, total]; the move's own where nothing was caught.
    def self.pp_of(text, move)
      return [$1.to_i, $2.to_i] if text.to_s =~ PP_TEXT
      [(move.pp rescue nil), PokeAccess.attr_of(move, :total_pp, :totalpp)]
    end

    # The category icon a move button shows (0 physical, 1 special, 2 status), kept on its sprite; ZUD draws a Max
    # Move's from its base move.
    def self.button_category(win, idx, move)
      sp = (PokeAccess.ivar(win, :@button) || {})["#{idx}"]
      c = (sp.param rescue nil)
      c.is_a?(Integer) ? c : PokeAccess::MoveInfo.category_of(move)
    end

    # Runs a pbChooseTarget keeping on the target window who chooses and whether the move hits several battlers;
    # cancelled, the move menu it goes back to says its focused move again.
    def self.choosing(scene, args)
      note_choice(PokeAccess.ivar(scene, :@targetWindow), args)
      ret = yield
      reopen_moves(scene) if ret.is_a?(Integer) && ret < 0
      ret
    end

    # Keeps the chooser's index and whether the move's target data hits more than one battler.
    def self.note_choice(win, args)
      return unless win
      win.instance_variable_set(:@access_chooser, args[0])
      win.instance_variable_set(:@access_spread, (args[1].num_targets rescue 1).to_i != 1)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Forgets the move the fight window last said, so its next frame says it again.
    def self.reopen_moves(scene)
      fw = PokeAccess.ivar(scene, :@fightWindow)
      PokeAccess::Cursor.reset(fw, :ebdx_move) if fw
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Keeps the names the target buttons stand for (pbCreateTargetTexts: a name, "" for a fainted battler, nil for
    # none) and forgets the focused one.
    def self.targets_drawn(win, texts)
      win.instance_variable_set(:@access_texts, texts.is_a?(Array) ? texts.dup : nil)
      PokeAccess::Cursor.reset(win, :ebdx_target)
    end

    # Says the battler under the target cursor, or every one a move that hits several lights, each by name and side;
    # the first after the window opens queued.
    def self.target_focus(win)
      texts = PokeAccess.ivar(win, :@access_texts)
      idx = PokeAccess.ivar(win, :@index)
      return unless texts.is_a?(Array) && idx.is_a?(Integer) && idx >= 0
      spread = PokeAccess.ivar(win, :@access_spread)
      PokeAccess::Cursor.announce(win, :ebdx_target, spread ? :all : idx, true, false) do
        line = target_text(win, texts, spread ? nil : idx)
        PokeAccess::Info.set_info(:text, line)
        line
      end
    end

    # The battler at idx, or every named one with idx nil, as "name, side".
    def self.target_text(win, texts, idx)
      chooser = PokeAccess.ivar(win, :@access_chooser)
      slots = idx ? [idx] : (0...texts.length).reject { |i| texts[i].nil? }
      slots.map do |i|
        nm = texts[i].to_s.empty? ? PokeAccess::I18n.t(:bt_empty_slot) : texts[i].to_s
        "#{nm}, #{PokeAccess::I18n.t(PokeAccess::Battle.target_side_key(i, chooser))}"
      end.join(". ")
    end

    # Forgets what the bag last said, so its opening reads the focused button again.
    def self.bag_opened(bag)
      PokeAccess::Cursor.reset(bag, :ebdx_bag)
      PokeAccess::Cursor.reset(bag, :ebdx_bag_page)
    end

    # Says what the bag's selector sits on once per change, the first after the bag opens queued.
    def self.bag_focus(bag)
      spot = bag_spot(bag)
      return unless spot
      PokeAccess::Cursor.announce(bag, :ebdx_bag, spot, true, false) { bag_text(bag, spot) }
    end

    # What the selector sits on as [kind, index]: a main button (:main, 0-5), the open pocket's back button (:back) or
    # one of its items (:item); nil for anything else, such as an item left over while no pocket is open.
    def self.bag_spot(bag)
      sprites = bag.sprites
      at = (sprites["sel"].anchor rescue nil)
      return nil if at.nil?
      open = PokeAccess.ivar(bag, :@selPocket).to_i != 0
      (0..5).each do |k|
        next unless at.equal?(sprites["pocket#{k}"])
        return (k == 5 && open) ? [:back, 5] : [:main, k]
      end
      return nil unless open
      (PokeAccess.ivar(bag, :@items) || {}).each { |k, sp| return [:item, k.to_i] if at.equal?(sp) }
      nil
    end

    # A spot's line: a pocket by the name its item list's header paints, the last-used item, back, or an item. Off
    # the items, the page header is forgotten, so the next pocket opened says it again.
    def self.bag_text(bag, spot)
      kind, k = spot
      return item_text(bag, k) if kind == :item
      PokeAccess::Cursor.reset(bag, :ebdx_bag_page)
      return PokeAccess::I18n.t(:bb_back) if kind == :back || k == 5
      return pocket_name(k) if k < 4
      last = PokeAccess.ivar(bag, :@lastUsed)
      nm = (last && last != 0) ? (GameData::Item.get(last).name rescue nil) : nil
      [PokeAccess::I18n.t(:bb_last), nm].compact.join(", ")
    end

    # The pocket a main button opens, by the name its item list's header paints: Settings.bag_pocket_names at the
    # pocket BagWindowEBDX#confirm opens.
    def self.pocket_name(k)
      names = (::Settings.bag_pocket_names rescue nil)
      return nil unless names.is_a?(Array)
      return names[[2, 1, 4, 5][k]] if names.length == 6
      names[[2, 3, 5, 7][k]]
    end

    # An item slot as its button paints it, the name and "x" with the quantity, headed by the pocket's name and page
    # when the page changes; also the info key's item.
    def self.item_text(bag, k)
      e = (PokeAccess.ivar(bag, :@pocket) || [])[k]
      return nil unless e
      PokeAccess::Info.set_info(:item, e[0])
      line = "#{(GameData::Item.get(e[0]).name rescue e[0].to_s)}, x#{e[1]}"
      page = k / 6
      key = "#{PokeAccess.ivar(bag, :@selPocket)}-#{page}"
      return line unless PokeAccess::Cursor.changed?(bag, :ebdx_bag_page, key)
      "#{PokeAccess.ivar(bag, :@pname)}, #{page + 1}/#{PokeAccess.ivar(bag, :@pages)}. #{line}"
    end

    # Runs a useItem? confirmation: the chosen item's description, which its use button paints, queued; the pulse
    # then says which button the selector sits on.
    def self.confirming(bag)
      begin
        @confirm = bag
        PokeAccess::Cursor.reset(bag, :ebdx_bag_confirm)
        desc = (GameData::Item.get(PokeAccess.ivar(bag, :@ret)).description rescue nil)
        PokeAccess.speak(PokeAccess.clean(desc.to_s), false) unless desc.to_s.strip.empty?
      rescue StandardError => e
        PokeAccess.swallowed(e)
      end
      yield
    ensure
      @confirm = nil
      PokeAccess::Cursor.reset(bag, :ebdx_bag)
    end

    # Each pulse of a confirmation: the use or don't-use button the selector sits on, the first queued.
    def self.confirm_focus
      bag = @confirm
      return unless bag
      sprites = bag.sprites
      at = (sprites["sel"].anchor rescue nil)
      idx = [sprites["confirm"], sprites["cancel"]].index { |s| s && s.equal?(at) }
      return if idx.nil?
      PokeAccess::Cursor.announce(bag, :ebdx_bag_confirm, idx, true, false) do
        PokeAccess::I18n.t(idx == 0 ? :ura_bag_use : :ura_bag_dont_use)
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Keeps on a refreshed databox's battler the marks its sprites show (Battle.note_marks).
    def self.box_marks(box)
      return unless PokeAccess.ivar(box, :@loaded)
      PokeAccess::Battle.note_marks(box, box_icons(box))
    end

    # The databox sprites that hold a mark, as [sprite key, the file it shows, which Battle.marks_of words]: the
    # caught Poke Ball, the Mega symbol, the Ultra Burst and Dynamax symbols of ZUD's patch, and the Alpha, Noble and
    # Totem symbols Golden Crown's copy of that patch adds.
    BOX_MARKS = [["caught", "battleBoxOwned"], ["mega", "symMega"], ["ultra", "symUltra"], ["dynamax", "symDynamax"],
                 ["alpha", "alphaness"], ["noble", "nobleness"], ["totem", "totemness"]]

    # The marks a databox shows, by the files they come from: the shiny gold of the name first (a Shadow Pokemon's
    # name is painted purple instead, in Dark Horizon's copy), then each mark sprite holding a picture, the Mega one
    # showing the Primal symbol for a Primal battler.
    def self.box_icons(box)
      sprites = PokeAccess.ivar(box, :@sprites) || {}
      pk = PokeAccess.ivar(box, :@pokemon)
      out = []
      out.push("shiny") if (pk.shiny? rescue false) && !(pk.shadowPokemon? rescue false)
      primal = (PokeAccess.ivar(box, :@battler).primal? rescue false)
      BOX_MARKS.each do |key, file|
        next unless shown?(sprites[key])
        out.push((key == "mega" && primal) ? "icon_primal" : file)
      end
      out
    end

    # Whether a databox sprite holds a picture.
    def self.shown?(sp)
      bm = (sp.bitmap rescue nil)
      (bm && !(bm.disposed? rescue false)) ? true : false
    end

    # Says, queued, a party lineup as it slides in: its side's balls counted by how each is drawn.
    def self.lineup(line)
      battle = PokeAccess.ivar(line, :@battle)
      return unless battle
      side = PokeAccess.ivar(line, :@side).to_i
      num = (PokeAccess.ivar(line, :@num) || 6).to_i
      counts = ball_counts(((battle.pbParty(side) rescue nil) || [])[0, num] || [])
      return if counts.empty?
      PokeAccess.speak(PokeAccess::I18n.t(side.even? ? :ura_balls_mine : :ura_balls_foe, :list => counts), false)
    end

    # A side's balls as drawn: healthy, with a status condition, fainted (an egg is drawn fainted); an empty slot draws
    # none.
    def self.ball_counts(party)
      n = [0, 0, 0]
      party.each do |pk|
        next unless pk
        if (pk.hp rescue 0).to_i < 1 || (pk.egg? rescue false)
          n[2] += 1
        elsif status?(pk)
          n[1] += 1
        else
          n[0] += 1
        end
      end
      keys = [:ura_balls_ok, :ura_balls_status, :ura_balls_fainted]
      (0...3).select { |k| n[k] > 0 }.map { |k| PokeAccess::I18n.t(keys[k], :n => n[k]) }.join(", ")
    end

    # Whether a Pokemon's ball is drawn with a status condition.
    def self.status?(pk)
      st = (pk.status rescue nil)
      !(st.nil? || st == :NONE || st == 0)
    end

    # The opponent pbShowOpponent slides in leads, by name, the line it says next (a scripted battle line, the lose
    # text); a picture shown by file name instead is no trainer of the battle, and an index past them shows none.
    def self.speaker(scene, args)
      return unless args[2].nil?
      tr = ((PokeAccess.ivar(scene, :@battle).opponent rescue nil) || [])[args[0].to_i]
      nm = (tr.name rescue nil)
      PokeAccess.before_next_line(nm) unless nm.to_s.strip.empty?
    end

    # Runs the capture's Pokedex page paint and speaks the page, queued, as painted (DexEntry.painted_entry), with
    # the types its icons show; the line also goes to the info key.
    def self.dex_drawn(page)
      ret = nil
      rows = PokeAccess::PaintCapture.sample { ret = yield }
      dex_page(page, rows)
      ret
    end

    # The page's painted rows in reading order and its species' types, as the core reads a Pokedex info page.
    def self.dex_page(page, rows)
      pk = PokeAccess.ivar(page, :@pokemon)
      data = species_data(PokeAccess.ivar(page, :@species), (pk.form rescue 0))
      t = PokeAccess::DexEntry.painted_entry(PokeAccess::PaintCapture.laid_out(rows), nil, type_names(data))
      PokeAccess.speak(t, false) if t
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A species form's data, as the page looks it up.
    def self.species_data(sp, form)
      (GameData::Species.get_species_form(sp, form) rescue nil) || (GameData::Species.get(sp) rescue nil)
    end

    # The type names a species' data gives: types from v20 on, type1 and type2 in v19.
    def self.type_names(data)
      return [] if data.nil?
      list = (data.types rescue nil) || [(data.type1 rescue nil), (data.type2 rescue nil)].compact.uniq
      list.map { |t| (GameData::Type.get(t).name rescue t.to_s) }
    end
  end
end

# The windows' update hooks are containers: an update only moves the window's own sprites, so no reader runs inside.
PokeAccess::Hooks.after_hook("CommandWindowEBDX", :compileCommands, :optional => true) do |win, labels, args|
  PokeAccess::Ebdx.commands_drawn(win, labels, args[0])
end
PokeAccess::Hooks.after_hook("CommandWindowEBDX", :update, :optional => true, :hook_container => true) do |win, _r, _a|
  PokeAccess::Ebdx.command_focus(win)
end

PokeAccess::Hooks.after_hook("FightWindowEBDX", :battler=, :optional => true) do |win, _r, _a|
  PokeAccess::Ebdx.fight_opened(win)
end
PokeAccess::Hooks.around_hook("FightWindowEBDX", :generateButtons, :optional => true) do |win, nxt, _a|
  PokeAccess::Ebdx.buttons_drawn(win) { nxt.call }
end
PokeAccess::Hooks.after_hook("FightWindowEBDX", :update, :optional => true, :hook_container => true) do |win, _r, _a|
  PokeAccess::Ebdx.fight_focus(win)
end
PokeAccess::Hooks.wrap_kernel("pbDrawOutlineText", "plugin_ebdx_outline", :before) do |args, _r|
  PokeAccess::Ebdx.outlined(args[5])
end

PokeAccess::Hooks.around_hook("Battle::Scene", :pbChooseTarget, :optional => true) do |scene, nxt, args|
  PokeAccess::Ebdx.choosing(scene, args) { nxt.call }
end
PokeAccess::Hooks.around_hook("PokeBattle_Scene", :pbChooseTarget, :optional => true) do |scene, nxt, args|
  PokeAccess::Ebdx.choosing(scene, args) { nxt.call }
end
PokeAccess::Hooks.after_hook("TargetWindowEBDX", :refresh, :optional => true) do |win, _r, args|
  PokeAccess::Ebdx.targets_drawn(win, args[0])
end
PokeAccess::Hooks.after_hook("TargetWindowEBDX", :index=, :optional => true) do |win, _r, _a|
  PokeAccess::Ebdx.target_focus(win)
end

PokeAccess::FocusReader.define("ChoiceWindowEBDX", :items => :@commands, :slot => :ebdx_choice, :optional => true,
                               :hook_container => true) { |c| c }

PokeAccess::Hooks.before_hook("BagWindowEBDX", :show, :optional => true) do |bag, _a|
  PokeAccess::Ebdx.bag_opened(bag)
end
# hook_container: the update can open a pocket with nothing usable, whose message the battle reader says.
PokeAccess::Hooks.after_hook("BagWindowEBDX", :update, :optional => true, :hook_container => true) do |bag, _r, _a|
  PokeAccess::Ebdx.bag_focus(bag)
end
PokeAccess::Hooks.around_hook("BagWindowEBDX", :useItem?, :optional => true) do |bag, nxt, _a|
  PokeAccess::Ebdx.confirming(bag) { nxt.call }
end
PokeAccess::Frame.each_pulse { PokeAccess::Ebdx.confirm_focus }

PokeAccess::Hooks.after_hook("DataBoxEBDX", :refresh, :optional => true) do |box, _r, _a|
  PokeAccess::Ebdx.box_marks(box)
end
PokeAccess::Battle.icon_mark(/\AsymMega\z/i, :bt_mark_mega)
PokeAccess::Battle.icon_mark(/\AsymUltra\z/i, :bt_m_ultra)
PokeAccess::Battle.icon_mark(/\AsymDynamax\z/i, :bt_m_dynamax)
PokeAccess::Battle.icon_mark(/\Aalphaness\z/i, :bt_m_alpha)
PokeAccess::Battle.icon_mark(/\Anobleness\z/i, :bt_m_noble)
PokeAccess::Battle.icon_mark(/\Atotemness\z/i, :bt_m_totem)

PokeAccess::Hooks.after_hook("PartyLineupEBDX", :refresh, :optional => true) do |line, _r, _a|
  PokeAccess::Ebdx.lineup(line)
end

PokeAccess::Hooks.before_hook("Battle::Scene", :pbShowOpponent, :optional => true) do |scene, args|
  PokeAccess::Ebdx.speaker(scene, args)
end
PokeAccess::Hooks.before_hook("PokeBattle_Scene", :pbShowOpponent, :optional => true) do |scene, args|
  PokeAccess::Ebdx.speaker(scene, args)
end

PokeAccess::Hooks.around_hook("EliteBattle_Pokedex", :drawPage, :optional => true) do |page, nxt, _a|
  PokeAccess::Ebdx.dex_drawn(page) { nxt.call }
end
