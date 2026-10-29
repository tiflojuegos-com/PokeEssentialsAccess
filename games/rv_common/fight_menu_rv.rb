module PokeAccess
  # The fight menu of the engine Reborn, Rejuvenation and Desolation share (FightMenuDisplay): the buttons past core's
  # Mega Evolution and Ultra Burst ones, Z-Move (zButton) and Rejuvenation's Terastallization (teraButton), said as
  # they come up and as they toggle. With the Z-Move button on, Reborn's and Rejuvenation's buttons paint each Z-move in
  # its move's place (FightMenuButtons#refresh), and the move line says it there; every move line says the type its
  # button paints, which a field or an ability can change, the types the field adds and the field's boost or nerf.
  module FightRV
    # The type the fight buttons paint for the battler's move: Rejuvenation's pbMoveBattleSceneType (pbType for the
    # form a pressed Mega Evolution, Ultra Burst or Terastallization button brings), else the engine's pbType, else
    # the move's own.
    def self.painted_type(m, b)
      t = (respond_to?(:pbMoveBattleSceneType, true) ? pbMoveBattleSceneType(m, b) : m.pbType(b)) rescue nil
      t.nil? ? m.type : t
    end

    # A fight line's parts with what the buttons paint past core's: the types added after the move's own and the
    # field's mark at the end, both from medium.
    def self.with_field(disp, m, b, parts)
      parts.dup.insert(2, [second_type(m, b), :medium]).push([field_word(disp, m, b), :medium])
    end

    # The types the buttons paint beside the move's, or nil where they paint none (none added, or the move's own
    # among them): Rejuvenation's list, whose :RAINBOW and :CRYSTAL stand for a type the field rolls, or Desolation's
    # single type.
    def self.second_type(m, b)
      ty = painted_type(m, b)
      listed = (m.method(:getSecondaryType).arity.abs > 1) rescue false
      extra = (listed ? m.getSecondaryType(b, ty, :placeholders => true) : m.getSecondaryType(b)) rescue nil
      extra = [extra].flatten.compact
      return nil if extra.empty? || extra.include?(ty)
      names = extra.reject { |t| t == :RAINBOW || t == :CRYSTAL }.map { |t| PokeAccess::Data.type_name(t) }.compact
      said = names.empty? ? [] : [PokeAccess::I18n.t(:reb_move_also_type, :t => names.join(", "))]
      said.push(PokeAccess::I18n.t(:reb_move_random_type)) if extra.include?(:RAINBOW)
      said.push(PokeAccess::I18n.t(:reb_move_crystal_type)) if extra.include?(:CRYSTAL)
      said.empty? ? nil : said.join(", ")
    end

    # The field's mark on the move's button: Rejuvenation's pbFieldMoveHighlights (:buff, :nerf), else the buttons'
    # pbFieldNotesBattle (Desolation's: 1 boosted, 2 weakened); nil where it paints none.
    def self.field_word(disp, m, b)
      note = if respond_to?(:pbFieldMoveHighlights, true)
               { :buff => 1, :nerf => 2 }[(pbFieldMoveHighlights(m, b) rescue nil)]
             else
               (PokeAccess.ivar(disp, :@buttons).pbFieldNotesBattle(m) rescue nil)
             end
      case note
      when 1 then PokeAccess::I18n.t(:reb_move_boosted)
      when 2 then PokeAccess::I18n.t(:reb_move_weakened)
      end
    end

    # Whether the Z-Move button is on, as this opening of the menu set it (the menu reads its focused move before it
    # sets the buttons), and the focused move has a Z-move to become.
    def self.z_on?(disp, b, idx)
      return false unless disp.instance_variable_get(:@access_z) == 2
      (b.pbCompatibleZMoveFromMove?(idx, true) rescue false) ? true : false
    end

    # The Z-move the buttons paint in the focused slot, or nil where the move stays: the button off, no Z-move for it,
    # or a battler that keeps no Z-moves (Desolation's).
    def self.z_move(disp, b, idx)
      z_on?(disp, b, idx) ? (b.zmoves[idx] rescue nil) : nil
    end

    # Says the Z-move standing in the focused slot once per change, at the fight line's levels, and hands it to the
    # info key; false where no Z-move stands there.
    def self.read_z(disp, interrupt)
      b = PokeAccess.ivar(disp, :@battler)
      idx = PokeAccess.ivar(disp, :@index)
      m = b ? z_move(disp, b, idx) : nil
      return false unless m
      PokeAccess::Cursor.on_change(disp, :fight_move, [idx, :z]) do
        parts = z_parts(disp, m, b)
        PokeAccess.speak_clean(PokeAccess::Verbosity.line(:battle_move, parts, ". "), interrupt, :menu)
        PokeAccess::Info.set_info(:move, m, PokeAccess::Verbosity.full_line(parts, ". "))
      end
      true
    end

    # The Z-move's line as core's fight line parts it, with what its button paints past it: its name, the type its
    # button paints for the battler, and its category; no PP, as it has none of its own.
    def self.z_parts(disp, m, b)
      ty = (PokeAccess::Data.type_name(painted_type(m, b)) rescue nil)
      nm, ty = PokeAccess::MoveInfo.painted(m, m.name.to_s, ty)
      with_field(disp, m, b, PokeAccess::Battle.fight_parts(m, nm, ty, nil))
    end

    # A button set to v, its state kept in slot: available as it comes up, queued; on and off as it toggles, cutting
    # in, the Z-Move one then saying the focused slot again, which its Z-move takes or gives back.
    def self.button(disp, slot, mech, v)
      last = disp.instance_variable_get(slot)
      disp.instance_variable_set(slot, v) if v.is_a?(Integer)
      return PokeAccess.speak(PokeAccess::Battle.ready_text(mech), false) if PokeAccess::Battle.mega_reveal?(last, v)
      k = PokeAccess::Battle.mega_key(last, v, :bt_special_on, :bt_special_off)
      return unless k
      name = PokeAccess::I18n.t(PokeAccess::Battle::SPECIAL_NAMES[mech])
      PokeAccess.speak(PokeAccess::I18n.t(k, :name => name), true)
      PokeAccess::Battle.read_fight_move(disp, false) if mech == :zmove
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Hooks both buttons, clears the Z-Move state as the menu is set up for a battler, puts the Z-move in the line, and
    # the type and the field's types and mark each button paints in core's.
    def self.bind
      PokeAccess::Hooks.after_hook("FightMenuDisplay", :zButton=, :optional => true) do |disp, _r, args|
        PokeAccess::FightRV.button(disp, :@access_z, :zmove, args[0])
      end
      PokeAccess::Hooks.after_hook("FightMenuDisplay", :teraButton=, :optional => true) do |disp, _r, args|
        PokeAccess::FightRV.button(disp, :@access_tera, :tera, args[0])
      end
      PokeAccess::Hooks.after_hook("FightMenuDisplay", :battler=, :optional => true) do |disp, _r, _a|
        disp.instance_variable_set(:@access_z, nil)
      end
      PokeAccess::Hooks.override("PokeAccess::Battle", :read_fight_move, :tag => "rv_common") do |_mod, original, args|
        PokeAccess::FightRV.read_z(args[0], args.length > 1 ? args[1] : true) || original.call
      end
      PokeAccess::Hooks.override("PokeAccess::Battle", :fight_type, :tag => "rv_common") do |_mod, _original, args|
        PokeAccess::FightRV.painted_type(args[0], args[1])
      end
      PokeAccess::Hooks.override("PokeAccess::Battle", :fight_line, :tag => "rv_common") do |_mod, _original, args|
        PokeAccess::FightRV.with_field(args[0], args[1], args[2], args[3])
      end
      PokeAccess::Hooks.override("PokeAccess::Battle", :fight_row, :tag => "rv_common") do |_mod, _original, args|
        PokeAccess::Verbosity.full_line(args[0], ". ")
      end
    end
  end
end

PokeAccess::FightRV.bind if PokeAccess::DataRV.engine?
