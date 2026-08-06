# Pokedex search screen (PokemonPokedex_Scene#pbDexSearch and its per-parameter sub-screen). This is vanilla
# Essentials (verified against the v21.1 reference in 016_UI/003_UI_Pokedex_Main.rb), and every one of the
# supported fangames ships it, yet it was completely silent: the filter grid is painted straight onto the
# overlay bitmap and the focus is a bare cursor sprite, so no window reader ever sees it.
#
# Both redraw methods receive the cursor index as their last argument, so the reader takes it from there
# instead of introspecting the sprite -- one less thing to break when a game restyles the screen.
#   pbRefreshDexSearch(params, index): the main grid. index 0..6 are the seven filters (order, name, type,
#     height, weight, colour, shape) and 7/8/9 are the Clear / Search / Cancel buttons (verified in the
#     vanilla input loop, `when 7` clears, `when 8` searches, `when 9` cancels).
#   pbRefreshDexSearchParam(mode, cmds, sel, index): the sub-screen that picks one filter's value. mode is
#     the same 0..6 field, cmds the option list, and a negative index means the OK/Cancel buttons.
module PokeAccess
  module DexSearch
    FIELDS = [:dxs_order, :dxs_name, :dxs_type, :dxs_height, :dxs_weight, :dxs_color, :dxs_shape]
    BUTTONS = { 7 => :dxs_clear, 8 => :dxs_search, 9 => :dxs_cancel }

    # The spoken label of one of the seven filters, or of a button row.
    def self.field_label(idx)
      return PokeAccess::I18n.t(BUTTONS[idx]) if BUTTONS[idx]
      key = FIELDS[idx]
      key ? PokeAccess::I18n.t(key) : nil
    end

    # Whether a filter currently holds a value. Vanilla stores -1 for "no filter" in every slot but the sort
    # order, which is always set.
    def self.field_value(scene, idx, params)
      return nil unless params.is_a?(Array) && idx >= 0 && idx < FIELDS.length
      v = params[idx]
      return PokeAccess::I18n.t(:dxs_unset) if v.nil? || v.to_i < 0
      list = case idx
             when 0 then PokeAccess.ivar(scene, :@orderCommands)
             when 1 then PokeAccess.ivar(scene, :@nameCommands)
             end
      (list.is_a?(Array) && list[v.to_i]) ? list[v.to_i].to_s : PokeAccess::I18n.t(:dxs_set)
    rescue StandardError
      nil
    end

    # Voices the focused row of the main search grid: the filter and its current value, or the button.
    def self.main(scene, params, idx)
      i = idx.to_i
      label = field_label(i)
      return if label.nil?
      val = field_value(scene, i, params)
      PokeAccess::Cursor.announce(scene, :dex_search, [i, val], true) do
        val ? "#{label}, #{val}" : label
      end
    rescue StandardError
      nil
    end

    # Voices the focused option of the sub-screen that sets one filter, with the filter's name as context on
    # entering it. A negative index is the OK/Cancel pair the vanilla loop uses below the list.
    def self.param(scene, mode, cmds, idx)
      i = idx.to_i
      title = FIELDS[mode.to_i] ? PokeAccess::I18n.t(FIELDS[mode.to_i]) : nil
      opt = if i < 0
              PokeAccess::I18n.t(i <= -3 ? :dxs_cancel : :dxs_ok)
            elsif cmds.is_a?(Array) && cmds[i]
              PokeAccess.clean(cmds[i].to_s)
            end
      return if opt.nil? || opt.to_s.empty?
      PokeAccess::Cursor.announce(scene, :dex_search_param, [mode, i], true) do
        title ? "#{title}, #{opt}" : opt.to_s
      end
    rescue StandardError
      nil
    end

    # Six of the thirteen games ship an OLDER search screen behind the same method name, and its redraw takes
    # only the params: pbRefreshDexSearch(params). There is no grid and no index argument -- the screen is a
    # Window_ComplexCommandPokemon ("searchlist") whose rows already read "Nombre: X", "Color: Y". Reading
    # args[1] there yielded nil, nil.to_i is 0, so the sort row was announced once and the entire rest of the
    # screen was silent. The window owns its own cursor, so it is read straight off it.
    # The window is claimed: it is a Window_DrawableCommand and it is active, so the generic command reader
    # reads it too, and the game calls this refresh on every index change -- the same row spoken twice, the
    # second one interrupting the first mid-word, because the two readers key on different dedup slots and
    # neither can see the other.
    def self.list(scene)
      win = PokeAccess.dedicate(PokeAccess.sprite(scene, "searchlist"))
      return unless win
      txt = PokeAccess.clean(PokeAccess::Menus.focused_text(win).to_s)
      return if txt.empty?
      PokeAccess::Cursor.announce(scene, :dex_search, [(win.index rescue nil), txt], true) { txt }
    rescue StandardError
      nil
    end

    # Which of the two search screens this is, told by the arity the game shipped rather than by class name:
    # both eras carry both variants, so the signature is the only honest discriminator.
    def self.refresh(scene, args)
      return main(scene, args[0], args[1]) if args.length >= 2
      list(scene)
    end
  end
end

# A general Essentials window whose commands are grouped ("category", [rows], "category", [rows]), so the
# flat cursor index does not index the array: generic_focus found an Array at commands[i] and gave up. The
# window resolves it itself with getText, header rows included. Registered here because the Pokedex search is
# the screen that needed it, but it applies to any screen using this window class.
PokeAccess::Menus.def_extractor("Window_ComplexCommandPokemon") do |win, i|
  cmds = (win.commands rescue nil)
  cmds ? win.getText(cmds, i).to_s : ""
end

PokeAccess::Hooks.after_hook("PokemonPokedex_Scene", :pbRefreshDexSearch) do |scene, _r, args|
  PokeAccess::DexSearch.refresh(scene, args)
end
PokeAccess::Hooks.after_hook("PokemonPokedex_Scene", :pbRefreshDexSearchParam) do |scene, _r, args|
  PokeAccess::DexSearch.param(scene, args[0], args[1], args[3])
end
# The gen-6 era names the same scene without the underscore.
PokeAccess::Hooks.after_hook("PokemonPokedexScene", :pbRefreshDexSearch) do |scene, _r, args|
  PokeAccess::DexSearch.refresh(scene, args)
end
