# The EV allocator of the Level Based Mixed EV System, a mode of the summary's stats page while $evalloc is up: the
# poll says where the selector sprite's index went, the page repaint a value or pool change. In the mixed mode the
# Sp. Atk row edits Attack, hence MIXED's fourth entry.
module PokeAccess
  module EVAllocator
    FULL = [:HP, :ATTACK, :DEFENSE, :SPECIAL_ATTACK, :SPECIAL_DEFENSE, :SPEED] unless const_defined?(:FULL)
    MIXED = [:HP, :ATTACK, :DEFENSE, :ATTACK, :SPECIAL_DEFENSE, :SPEED] unless const_defined?(:MIXED)
    # The label the plugin paints over the ability's place while allocating, in its own untranslated
    # English: the positions rows from it on are the allocation block.
    POOL_LABEL = "EV Pool:" unless const_defined?(:POOL_LABEL)

    def self.active?
      (defined?($evalloc) && $evalloc) ? true : false
    end

    # The stats page while allocating: on opening, the allocation block (and its key hints) once, queued; then a
    # repaint that changed the focused stat's value or the pool, interrupting.
    # param pairs the page's painted rows as [text, source]
    def self.page(scene, pairs)
      pos = pairs.select { |r| r[1] == :positions }.map { |r| PokeAccess.clean(r[0].to_s) }
      i = pos.index(POOL_LABEL)
      return unless i
      pool = pos[i + 1]
      focus = focused(scene)
      value = focus ? [focus[0], focus[2], pool] : nil
      unless PokeAccess.ivar(scene, :@access_ev_open)
        scene.instance_variable_set(:@access_ev_open, true)
        PokeAccess::Cursor.reset(scene, :ev_alloc)
        PokeAccess::Cursor.store(scene, :ev_value, value)
        block = PokeAccess::KeyHints.gate(pos[i..-1]).map { |r| PokeAccess::KeyHints.localize(r.to_s) }
        notes = PokeAccess::Verbosity.hints? ? pairs.reject { |r| r[1] == :positions }.map { |r| PokeAccess::KeyHints.localize(PokeAccess.clean(r[0].to_s)) } : []
        PokeAccess.speak(PokeAccess::PaintCapture.pair_labels(block.concat(notes)).join(", "), false)
        return
      end
      return unless focus && PokeAccess::Cursor.changed?(scene, :ev_value, value)
      PokeAccess.speak("#{row(focus)}, #{PokeAccess::I18n.t(:ev_pool_left, :n => pool)}", true)
    end

    # The stat under the selector and its effort value, as [row, stat, value], or nil.
    def self.focused(scene)
      idx = (PokeAccess.sprite(scene, "EVsel").index rescue nil)
      stat = idx ? stats[idx.to_i] : nil
      return nil unless stat
      ev = (PokeAccess.ivar(scene, :@pokemon).ev[stat] rescue nil)
      ev.nil? ? nil : [idx, stat, ev]
    end

    # A row as painted: the label of its place and the EVs of the stat it edits. In the mixed mode Attack and Sp. Atk
    # share Attack's EVs and the page lights both rows (EVsel3), so each names the other.
    def self.row(focus)
      name = PokeAccess::Data.stat_name(FULL[focus[0]] || focus[1])
      partner = shared_with(focus[0])
      name = PokeAccess::I18n.t(:ev_shared, :stat => name, :with => PokeAccess::Data.stat_name(partner)) if partner
      PokeAccess::I18n.t(:ev_row, :stat => name, :n => focus[2])
    end

    # The stat of the row the mixed mode lights along with row idx, or nil.
    def self.shared_with(idx)
      return nil unless stats == MIXED
      { 1 => :SPECIAL_ATTACK, 3 => :ATTACK }[idx]
    end

    # The stat list this game is playing with.
    def self.stats
      (::Settings::PURIST_MODE rescue false) ? FULL : MIXED
    rescue StandardError
      MIXED
    end

    # Says where the selector went (the stat and its EVs) while the allocator is up, the first one queued behind the
    # block; leaving the mode rearms the block.
    def self.poll(scene)
      unless active?
        scene.instance_variable_set(:@access_ev_open, nil)
        return
      end
      focus = focused(scene)
      return unless focus
      prev = PokeAccess::Cursor.current(scene, :ev_alloc)
      return unless PokeAccess::Cursor.changed?(scene, :ev_alloc, focus[0])
      PokeAccess.speak(row(focus), !prev.nil?)
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("PokemonSummary_Scene", :pbUpdate, :optional => true) do |scene, _r, _a|
  PokeAccess::EVAllocator.poll(scene)
end

if defined?(PokeAccess::SummaryV21)
  PokeAccess::Hooks.override(PokeAccess::SummaryV21, :speak_page, :tag => "ev_allocator") do |_mod, original, args|
    if PokeAccess::EVAllocator.active?
      PokeAccess::Summary.forget_page(args[0])
      PokeAccess::EVAllocator.page(args[0], PokeAccess::PaintCapture.take_pairs(:summary_egg))
    else
      original.call
    end
  end
end

# The plugin's pbFullAbilityWindow, the full text of an ability or move, read on the way in like any modal panel.
PokeAccess::ModalPanel.watch("pbFullAbilityWindow")
