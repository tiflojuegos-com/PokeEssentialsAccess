# Pokedex search screen (PokemonPokedex_Scene#pbDexSearch and its per-parameter sub-screen). Vanilla
# Essentials, verified against the v21.1 reference, and shipped by every supported fangame, yet invisible to
# every window reader: the filter grid is painted straight onto the overlay bitmap and the focus is a bare
# cursor sprite. Both redraw methods receive the cursor index as their last argument, so the reader takes it
# from there rather than introspecting the sprite.
#   pbRefreshDexSearch(params, index): the main grid. index 0..6 are the seven filters (order, name, type,
#     height, weight, colour, shape) and 7/8/9 are the Clear / Search / Cancel buttons.
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

    # Las ranuras de params que pinta cada FILA de la rejilla, y la lista de la que sale cada valor. La fila
    # NO es el indice de params: tipo, altura y peso ocupan DOS ranuras cada una (dos tipos, y el minimo y
    # el maximo de un rango), asi que de la fila 3 en adelante params[fila] es el filtro de al lado --
    # "Altura" leyendo el segundo tipo, "Color" leyendo la altura maxima. params[8] y params[9], que son el
    # color y la forma de verdad, no los leia nadie.
    SLOTS = [[0], [1], [2, 3], [4, 5], [6, 7], [8], [9]]
    LISTS = [:@orderCommands, :@nameCommands, :@typeCommands, :@heightCommands,
             :@weightCommands, :@colorCommands, :@shapeCommands]

    # Un elemento de una lista de comandos como lo dice la pantalla: los tipos, los colores y las formas son
    # objetos de GameData y su to_s es el volcado del objeto; las alturas y los pesos son numeros crudos.
    def self.option_text(item)
      return nil if item.nil?
      n = (item.name rescue nil)
      return PokeAccess.clean(n.to_s) if n && !n.to_s.empty?
      PokeAccess.clean(item.to_s)
    end

    # Whether a filter currently holds a value. Vanilla stores -1 for "no filter" in every slot but the sort
    # order, which is always set.
    def self.field_value(scene, idx, params)
      return nil unless params.is_a?(Array) && idx >= 0 && idx < FIELDS.length
      slots = SLOTS[idx]
      list = PokeAccess.ivar(scene, LISTS[idx])
      vals = slots.map do |s|
        v = params[s]
        next nil if v.nil? || v.to_i < 0
        (list.is_a?(Array) && list[v.to_i]) ? option_text(list[v.to_i]) : PokeAccess::I18n.t(:dxs_set)
      end
      vals = vals.compact.reject { |v| v.to_s.empty? }
      vals.empty? ? PokeAccess::I18n.t(:dxs_unset) : vals.join(" - ")
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
              option_text(cmds[i])
            end
      return if opt.nil? || opt.to_s.empty?
      PokeAccess::Cursor.announce(scene, :dex_search_param, [mode, i], true) do
        title ? "#{title}, #{opt}" : opt.to_s
      end
    rescue StandardError
      nil
    end

    # Six of the thirteen games ship an OLDER search screen behind the same method name, whose redraw takes
    # only the params: pbRefreshDexSearch(params). There is no grid and no index argument -- the screen is a
    # Window_ComplexCommandPokemon ("searchlist") whose rows already read "Nombre: X", "Color: Y" -- so it is
    # read straight off the window's own cursor. That window is CLAIMED, because it is an active
    # Window_DrawableCommand the generic command reader also reads and the game calls this refresh on every
    # index change: two readers on different dedup slots would speak the same row twice.
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
