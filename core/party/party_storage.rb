module PokeAccess
  # Party screen and PC storage navigation.
  module Party
    # PC boxes are 6 wide in Essentials: the fallback of box_columns.
    BOX_COLUMNS = 6

    # The two sex signs the screens draw, male then female: 0 and 1 are the engines' own gender numbers.
    SIGNS = ["\xE2\x99\x82", "\xE2\x99\x80"]

    # The sex sign the screens draw beside a pokemon's name, or nil for a genderless one; passed on as drawn,
    # since the screen reader says the sign itself.
    def self.gender_glyph(pk)
      sign((pk.gender rescue nil))
    end

    # The sign for an engine gender number, or nil for anything but male and female.
    def self.sign(g)
      g == 0 || g == 1 ? SIGNS[g] : nil
    end

    # The sex sign as a " sign" suffix (leading space) for a name, or "" when the screen draws none.
    def self.sign_phrase(pk)
      g = gender_glyph(pk)
      g ? " " + g : ""
    end

    # The ", fainted" suffix when a pokemon has no hp left, else "" (the single KO threshold for all readers).
    def self.fainted_suffix(pk)
      ((pk.hp rescue 1).to_i <= 0) ? ", " + PokeAccess::I18n.t(:pk_fainted) : ""
    end

    # A member's icon-only marks for the info key: shiny (shiny_word) and pokerus at stage 1. None for an egg,
    # whose panel draws neither.
    def self.icon_mark_list(pk)
      return [] if pk.nil? || PokeAccess::Summary.egg?(pk)
      marks = []
      marks.push(shiny_word(pk)) if shiny?(pk)
      marks.push(PokeAccess::I18n.t(:pk_pokerus)) if pokerus?(pk)
      marks
    rescue StandardError
      []
    end

    # The word for the shiny star a panel draws; a game with more than one star overrides it in its profile.
    def self.shiny_word(_pk)
      PokeAccess::I18n.t(:pk_shiny)
    end

    # The i18n key of a slot's line while a Pokemon is held over the slot's own (a swap); a profile may override it.
    def self.held_key(_scene, _pkmn = nil)
      :pc_swap
    end

    # Whether a pokemon is shiny, asked as shiny? (modern engines) and as isShiny? (gen-6).
    def self.shiny?(pk)
      v = (pk.shiny? rescue nil)
      v = (pk.isShiny? rescue nil) if v.nil?
      v ? true : false
    rescue StandardError
      false
    end

    # Whether a pokemon carries pokerus now: stage 1 only (0 never infected, 2 cured), the one the panel draws.
    # Without pokerusStage, a non-zero raw pokerus counter counts.
    def self.pokerus?(pk)
      v = (pk.pokerusStage rescue nil)
      return v.to_i == 1 unless v.nil?
      v = (pk.pokerus rescue nil)
      v.nil? ? false : v.to_i > 0
    rescue StandardError
      false
    end

    # The spoken line for a party slot (an egg as an egg), or the cancel label past the party; stashes the
    # pokemon for the info key.
    # param pokerus_slot true for a panel that shows pokerus in its state slot (member_line)
    def self.party_line(party, idx, annotation = nil, pokerus_slot = false)
      pk = (party && idx.is_a?(Integer) && idx >= 0 && idx < party.length) ? party[idx] : nil
      return PokeAccess::I18n.t(:pc_cancel) unless pk
      if PokeAccess::Summary.egg?(pk)
        ann = annotation.to_s.strip
        egg = ann.empty? ? PokeAccess::I18n.t(:pty_egg) : "#{PokeAccess::I18n.t(:pty_egg)}, #{ann}"
        PokeAccess::Info.set_info(:pokemon, pk, egg)
        return egg
      end
      opts = { :annotation => annotation, :pokerus_slot => pokerus_slot }
      PokeAccess::Info.set_info(:pokemon, pk, PokeAccess::Verbosity.whole { member_line(pk, opts) })
      member_line(pk, opts)
    end

    # A party member as its panel shows it: name, sex sign and level; HP and state slot unless an annotation
    # replaces them; shiny star, held item and marks; the annotation. Brief is name, HP, state and annotation;
    # medium adds the level; full the rest.
    # opts: :annotation the panel's text or nil; :pokerus_slot pokerus fills an empty state slot (v17+ panel);
    #   :status_always the slot stays under an annotation; :shiny false for no star; :panel_marks false to leave
    #   out panel_marks; :marks the panel's own icons
    def self.member_line(pk, opts = {})
      ann = opts[:annotation].to_s.strip
      vb = PokeAccess::Verbosity
      sex = vb.keep?(:party, :full) ? sign_phrase(pk) : ""
      vars = { :name => pk.name, :sex => sex, :level => pk.level, :hp => pk.hp, :tot => pk.totalhp }
      key = if panel_level? && vb.keep?(:party, :medium)
              ann.empty? ? :pty_member : :pty_head
            else
              ann.empty? ? :pty_member_nolv : :pty_head_nolv
            end
      parts = [[PokeAccess::I18n.t(key, vars), :brief]]
      if ann.empty? || opts[:status_always]
        st = status_slot(pk)
        parts.push([st, :brief])
        parts.push([PokeAccess::I18n.t(:pk_pokerus), :full]) if st.nil? && opts[:pokerus_slot] && pokerus?(pk)
      end
      parts.push([shiny_word(pk), :full]) if opts[:shiny] != false && shiny?(pk)
      parts.push([held_icon(pk), :full])
      panel_marks(pk).each { |m| parts.push([m, :full]) } unless opts[:panel_marks] == false
      (opts[:marks] || []).each { |m| parts.push([m, :full]) }
      parts.push([ann, :brief])
      vb.line(:party, parts)
    end

    # Whether this game's party panel writes the level; a profile whose panel leaves it out overrides this.
    def self.panel_level?
      true
    end

    # Whether this gen-6 game's party panel draws pokerus in its state slot (a v17 panel); a profile overrides this.
    def self.panel_pokerus?
      false
    end

    # A status ailment as a word: the gen-6 table answers with an i18n key, the modern data with its name.
    def self.status_word(st)
      return nil if st.nil? || st == 0 || st.to_s == "NONE"
      sn = PokeAccess::Data.status_name(st)
      w = sn.is_a?(Symbol) ? PokeAccess::I18n.t(sn) : sn.to_s
      w.empty? ? nil : w
    rescue StandardError
      nil
    end

    # The one icon slot a party panel keeps for a member's state: fainted before a status ailment, and on a
    # panel with a pokerus icon, pokerus when neither applies. nil when the slot is empty.
    def self.status_slot(pk, pokerus_slot = false)
      return PokeAccess::I18n.t(:pk_fainted) if (pk.hp rescue 1).to_i <= 0
      w = status_word((pk.status rescue nil))
      return w if w
      (pokerus_slot && pokerus?(pk)) ? PokeAccess::I18n.t(:pk_pokerus) : nil
    end

    # The held-item icon a party panel draws (mail has its own): that there is an item, not which.
    def self.held_icon(pk)
      it = (pk.item rescue nil)
      return nil if it.nil? || it == 0
      PokeAccess::I18n.t((pk.mail rescue nil) ? :pty_mail : :pty_item)
    end

    # Icons some games add to the party panel: the Exp. Share flag (pk.expshare), drawn for eggs too on gen-6
    # engines and for all but eggs on modern ones.
    def self.panel_marks(pk)
      on = (pk.expshare rescue false) ? true : false
      on = false if on && !PokeAccess::Engine.gen6? && PokeAccess::Summary.egg?(pk)
      on ? [PokeAccess::I18n.t(:pty_expshare)] : []
    end

    # The label of a button past the last party member, from its sprite rather than the index: multiselect turns
    # the single cancel into confirm plus cancel.
    def self.party_button(scene, idx)
      button_label((PokeAccess.ivar(scene, :@sprites)["pokemon#{idx}"] rescue nil))
    end

    # A button sprite's label: the word it was built with, else confirm or cancel by its class name; nil for any
    # other sprite.
    def self.button_label(sprite)
      cn = sprite.class.to_s
      return nil unless cn.include?("Cancel") || cn.include?("Confirm")
      painted = PokeAccess.clean(PokeAccess.ivar(sprite, :@access_label).to_s)
      return painted unless painted.empty?
      confirm = cn.include?("Confirm") && !cn.include?("ConfirmCancel")
      PokeAccess::I18n.t(confirm ? :pc_confirm : :pc_cancel)
    end

    # True when this slot holds a Pokemon rather than one of the trailing buttons.
    def self.party_slot?(party, idx)
      party && idx.is_a?(Integer) && idx >= 0 && idx < party.length && party[idx]
    end

    # A slot as read: its member with the panel's annotation (set as the info key's Pokemon), or the button past
    # the last member.
    def self.member_text(scene, party, idx)
      return plain_row(party_button(scene, idx) || PokeAccess::I18n.t(:pc_cancel)) unless party_slot?(party, idx)
      party_line(party, idx, slot_annotation(scene, idx), panel_pokerus?)
    end

    # A row with no Pokemon of its own (a button, an empty slot), set whole for the info key and Ctrl+T as it is said.
    def self.plain_row(line)
      PokeAccess::Info.set_info(:text, line, line)
      line
    end

    # Speaks the party slot the cursor just moved to, interrupting.
    def self.announce_party(scene, party, idx, oldidx)
      return if idx == oldidx
      PokeAccess.speak(member_text(scene, party, idx), true, :menu)
    end

    # Speaks the slot the cursor rests on without having moved there, queued: the list opening, or taking
    # the choice back after a sub-menu.
    def self.announce_member(scene, party, idx)
      return unless idx.is_a?(Integer) && idx >= 0
      PokeAccess.speak(member_text(scene, party, idx), false, :menu)
    end

    # The annotation a panel writes over its member ("able" or "not able" when teaching a machine or using an
    # item), or nil.
    def self.slot_annotation(scene, idx)
      panel = (PokeAccess.ivar(scene, :@sprites)["pokemon#{idx}"] rescue nil)
      a = PokeAccess.clean((PokeAccess.ivar(panel, :@text) rescue nil).to_s)
      a.empty? ? nil : a
    end

    # A stored pokemon as the box panel shows it: name, sex sign, level and place, then pc_details; an egg as an
    # egg. Brief is name, level and fainted; medium adds the place and item; full the rest.
    # param pos the position clause, ", row r column c", or "" in the party column
    # param variants how many states a mark has in this game's picture (Marking.variants of the PC scene)
    def self.pc_line(pk, pos = "", variants = nil)
      vb = PokeAccess::Verbosity
      where = vb.keep?(:pc_slot, :medium) ? pos : ""
      return PokeAccess::I18n.t(:pty_egg) + where if PokeAccess::Summary.egg?(pk)
      sex = vb.keep?(:pc_slot, :full) ? sign_phrase(pk) : ""
      head = PokeAccess::I18n.t(:pc_slot, :name => "#{pk.name}#{sex}", :level => pk.level) + fainted_suffix(pk) + where
      vb.line(:pc_slot, [[head, :brief]].concat(pc_details(pk, variants)))
    end

    # The box panel's details besides name and level (shiny, types, ability, item, marks), as [text, level] pairs
    # for the PC reading.
    def self.pc_details(pk, variants = nil)
      out = []
      out.push([shiny_word(pk), :full]) if shiny?(pk)
      types = PokeAccess::Data.pokemon_types(pk)
      out.push([PokeAccess::I18n.t(:pc_types, :t => types.join(" ")), :full]) unless types.empty?
      ab = ability_shown(pk)
      out.push([ab ? PokeAccess::I18n.t(:pc_ability, :a => ab) : PokeAccess::I18n.t(:pc_no_ability), :full])
      it = item_shown(pk)
      out.push([it ? PokeAccess::I18n.t(:pc_item, :i => it) : PokeAccess::I18n.t(:pc_no_item), :medium])
      marks = PokeAccess::Marking.shown(pk, variants)
      out.push([PokeAccess::I18n.t(:mk_list, :list => marks.join(", ")), :full]) unless marks.empty?
      out
    rescue StandardError
      []
    end

    # A Pokemon's ability as a panel writes it, or nil: an ability object names itself, a bare id (number or
    # symbol) goes through the data adapter.
    def self.ability_shown(pk)
      a = (pk.ability rescue nil)
      return nil if a.nil? || a == 0
      n = (a.is_a?(Symbol) || a.is_a?(Integer)) ? PokeAccess::Data.ability_name(a) : (a.name rescue nil)
      (n.nil? || n.to_s.empty?) ? nil : n.to_s
    end

    # The name of the item a Pokemon holds as a panel writes it, or nil when it holds none.
    def self.item_shown(pk)
      it = (pk.item rescue nil)
      return nil if it.nil? || it == 0
      n = (it.is_a?(Symbol) || it.is_a?(Integer)) ? PokeAccess::Data.item_name(it) : (it.name rescue nil)
      (n.nil? || n.to_s.empty?) ? nil : n.to_s
    end

    # The box row of a PC: the box's name and, while key hints are said, the keys that turn it.
    def self.box_row(name)
      hint = PokeAccess::Verbosity.hints? ? PokeAccess::I18n.t(:pc_box_hint) : nil
      [PokeAccess::I18n.t(:pc_box, :name => name), hint].compact.join(". ")
    end

    # A key hint a PC paints between its buttons (Royal's "[W]: Buscar"): it names a key, it is no button.
    PC_HINT = /\A\[[^\]]{1,16}\]/

    # What the modern PC writes under the box, left to right, as painted: the rows at the bottom right of the
    # overlay, apart from the Pokemon's panel.
    def self.pc_row(painted)
      rows = (painted || []).select { |r| r[2].is_a?(Numeric) && r[3].is_a?(Numeric) && r[2] > 200 && r[3] > 300 }
      rows.sort_by { |r| r[2] }.map { |r| PokeAccess.clean(r[0]) }.reject { |t| t.empty? }
    end

    # The two buttons of that row, party then exit; [] where they are pictures.
    def self.pc_buttons(painted)
      pc_row(painted).reject { |t| t =~ PC_HINT }
    end

    # The key hints of that row, with the key the player uses now; none while key hints are left out.
    def self.pc_hints(painted)
      return [] unless PokeAccess::Verbosity.hints?
      pc_row(painted).select { |t| t =~ PC_HINT }.map { |t| PokeAccess::KeyHints.localize(t) }
    end

    # How many party slots the PC's party column has (the stop past them is Back): the game's max_party_size
    # first, since a challenge mode can shrink the party, else Settings::MAX_PARTY_SIZE.
    def self.party_capacity
      n = (max_party_size rescue nil)
      return n.to_i if n.is_a?(Integer) && n > 0
      (Settings::MAX_PARTY_SIZE rescue 6).to_i
    end

    # Slots per box row, for the row and column said: PokemonBox::BOX_WIDTH, else BOX_COLUMNS; a profile may
    # override it.
    def self.box_columns
      w = (PokemonBox::BOX_WIDTH rescue nil)
      (w.is_a?(Integer) && w > 0) ? w : BOX_COLUMNS
    end

    # Speaks the PC cursor, a control or a slot; the box's name leads when a jump key turns the box under the
    # cursor, and on the first slot read unless the header said it.
    # param selection the cursor position, negative for the controls
    # param party the party array in the party column, else nil
    # param painted the overlay's capture (pc_buttons)
    def self.announce_pc(scene, selection, party, painted = nil)
      screen  = scene.instance_variable_get(:@screen)
      storage = PokeAccess.expect!("pc.storage", scene.instance_variable_get(:@storage))
      held    = (screen.pbHeldPokemon rescue nil)
      box     = (storage.currentBox rescue -9)
      slot_pk = nil
      if selection.is_a?(Integer) && selection >= 0
        slot_pk = party ? (party[selection] rescue nil) : (storage[box, selection] rescue nil)
      end
      key = [box, selection, (held ? held.object_id : nil), !party.nil?,
             (slot_pk ? slot_pk.object_id : nil)]
      prev = PokeAccess::Cursor.current(scene, :pc_key)
      return unless PokeAccess::Cursor.changed?(scene, :pc_key, key)
      in_box = !party && selection.is_a?(Integer) && selection >= 0
      turned = prev.is_a?(Array) && prev[0] != box && in_box
      unnamed = in_box && !PokeAccess.ivar(scene, :@access_pc_box_said)
      scene.instance_variable_set(:@access_pc_box_said, true) if in_box || selection == -1
      lead = (turned || unnamed) ? "#{PokeAccess.clean((storage[box].name rescue '').to_s)}. " : ""
      line = case selection
             when -1 then box_row((storage[box].name rescue ''))
             when -2 then PokeAccess.sentences([pc_buttons(painted)[0] || PokeAccess::I18n.t(:pc_team)].concat(pc_hints(painted)))
             when -3 then pc_buttons(painted)[1] || PokeAccess::I18n.t(:pc_close)
             when -4 then PokeAccess::I18n.t(:pc_prev)
             when -5 then PokeAccess::I18n.t(:pc_next)
             else slot_line(scene, selection, party, slot_pk, held, lead)
             end
      plain_row(line) unless selection.is_a?(Integer) && selection >= 0
      PokeAccess.speak(line, true, :menu)
      scene.instance_variable_set(:@access_pc_line, PokeAccess.last_spoken)
    rescue StandardError
      nil
    end

    # What a slot says: Back past the party, the Pokemon held over it, its own Pokemon (set for the info key, the
    # rest as plain rows, with what the box draws over the slot) or that it is empty, with where it sits in the box.
    def self.slot_line(scene, selection, party, pkmn, held, lead)
      return plain_row(PokeAccess::I18n.t(:pc_back)) if party && selection.is_a?(Integer) && selection >= party_capacity
      cols = box_columns
      pos = party ? "" : PokeAccess::I18n.t(:pc_pos, :row => selection / cols + 1, :col => selection % cols + 1)
      if held
        shown = PokeAccess::Summary.egg?(held) ? held.name.to_s : "#{held.name}#{sign_phrase(held)}"
        where = PokeAccess::Verbosity.keep?(:pc_slot, :medium) ? pos : ""
        return plain_row(lead + PokeAccess::I18n.t(held_key(scene, pkmn), :name => pkmn.name, :held => shown) + where) if pkmn
        return plain_row(lead + PokeAccess::I18n.t(:pc_place, :held => shown) + pos)
      end
      return plain_row(lead + PokeAccess::I18n.t(:pc_empty) + pos) unless pkmn
      variants = PokeAccess::Marking.variants(scene)
      marks = party ? [] : slot_marks(scene, selection)
      whole = ([PokeAccess::Verbosity.whole { pc_line(pkmn, pos, variants) }] + marks).join(", ")
      PokeAccess::Info.set_info(:pokemon, pkmn, whole)
      lead + ([pc_line(pkmn, pos, variants)] + marks).join(", ")
    end

    # What a box draws over a slot beyond its Pokemon (a PC that marks slots for a multiselection), as words; none on
    # a stock PC, and a profile whose PC draws more overrides it.
    def self.slot_marks(_scene, _index)
      []
    end

    # Whether the slot line this screen said last is still the last thing spoken, so re-entering the selection
    # loop need not say it again.
    def self.pc_still_heard?(scene)
      said = PokeAccess.ivar(scene, :@access_pc_line)
      !said.nil? && said == PokeAccess.last_spoken
    end
  end
end

# The scene hooks that use these helpers are in the version folders: party/gen6, party/v21 and party/v22.
