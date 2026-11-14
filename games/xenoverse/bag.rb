module PokeAccess
  module XenoverseBag
    def self.open(scene)
      @scene, @modal, @pocket = scene, nil, nil
      PokeAccess::Cursor.reset(scene, :xenoverse_bag)
      poll(scene)
    end

    def self.capture_name(scene, rows)
      items = PokeAccess.ivar(scene, :@curPocket)
      index = PokeAccess.ivar(scene, :@index)
      return unless items.is_a?(Array) && index.is_a?(Integer) && index >= 0 && items[index].is_a?(Array)
      text = PokeAccess::PaintCapture.text(PokeAccess::PaintCapture.laid_out(rows))
      scene.instance_variable_set(:@access_xenoverse_bag_name, [items[index][0], text]) unless text.empty?
    end

    # This screen paints a quantity even on key items and machines.
    def self.poll(scene)
      return unless @scene.equal?(scene) && !@modal
      names = PokeAccess.ivar(scene, :@pocketNames)
      pocket = PokeAccess.ivar(scene, :@curPocketIndex)
      items = PokeAccess.ivar(scene, :@curPocket)
      index = PokeAccess.ivar(scene, :@index)
      return unless names.is_a?(Array) && pocket.is_a?(Integer) && pocket >= 0 && pocket < names.length && items.is_a?(Array)
      label = names[pocket]
      return unless label.is_a?(String) && !label.empty?
      row = index.is_a?(Integer) && index >= 0 ? items[index] : nil
      return unless items.empty? || (row.is_a?(Array) && row.length >= 2 && row[1].is_a?(Numeric))
      bag = PokeAccess.ivar(scene, :@bag)
      registered = row && PokeAccess::Menus.bag_registered?(bag, row[0])
      moving = !!PokeAccess.ivar(scene, :@switching)
      key = [pocket, index, row && row.dup, registered, moving]
      return if PokeAccess::Cursor.current(scene, :xenoverse_bag) == key
      PokeAccess::Cursor.announce(scene, :xenoverse_bag, key, true, false) do
        prefix = @pocket == pocket ? '' : PokeAccess::I18n.t(:bag_pocket, :name => label) + '. '
        @pocket = pocket
        if items.empty?
          text = PokeAccess::I18n.t(:vitro_bag_empty)
          PokeAccess::Info.set_info(:text, text, text)
          prefix + text
        else
          id, quantity = row
          painted = PokeAccess.ivar(scene, :@access_xenoverse_bag_name)
          name = painted && painted[0] == id ? painted[1] : PokeAccess::Data.item_name(id).to_s
          parts = [[PokeAccess::I18n.t(:bag_item, :name => name, :qty => quantity), :brief]]
          parts.push([PokeAccess::I18n.t(:bag_registered), :medium]) if registered
          parts.push([PokeAccess::I18n.t(:bag_moving), :brief]) if moving
          PokeAccess::Info.set_info(:item, id, PokeAccess::Verbosity.whole { PokeAccess::Menus.bag_line(parts, index, items.length) })
          prefix + PokeAccess::Menus.bag_line(parts, index, items.length)
        end
      end
    end

    # The caller applies an item action after the modal returns. Read on its
    # real refresh/next Bag update, when that action's quantity is final.
    def self.modal(scene, kind, args)
      previous = @modal
      @modal = { :scene => scene, :kind => kind, :commands => args[1], :quantity => nil }
      text = PokeAccess.clean(args[0].to_s)
      PokeAccess.say_dialogue(text) unless text.empty?
      yield
    ensure
      PokeAccess::Cursor.reset(@modal, :xenoverse_bag_modal) if @modal
      @modal = previous
      if @scene.equal?(scene) && !@modal
        PokeAccess::Cursor.reset(scene, :xenoverse_bag)
      end
    end

    def self.capture_modal_paint(args)
      return unless @modal && args[1].is_a?(Array)
      sprites = PokeAccess.ivar(@modal[:scene], :@s)
      return unless sprites.is_a?(Hash)
      row = args[1][0]
      text = row.is_a?(Array) ? row[0].to_s : ''
      if @modal[:kind] == :pbChooseNumber
        sprite = sprites['qtbg']
        return unless sprite && args[0].equal?(sprite.bitmap)
        @modal[:quantity] = $1.to_i if text =~ /\Ax(\d+)\z/
      elsif @modal[:kind] == :pbConfirm
        ['yes', 'no'].each do |key|
          sprite = sprites[key]
          @modal[key] = PokeAccess.clean(text) if sprite && args[0].equal?(sprite.bitmap)
        end
      end
    end

    def self.modal_poll
      modal = @modal
      return unless modal && @scene.equal?(modal[:scene])
      scene, kind = modal[:scene], modal[:kind]
      key, text = nil, nil
      if kind == :pbShowCommands
        index = PokeAccess.ivar(scene, :@cmdid)
        commands = modal[:commands]
        return unless commands.is_a?(Array) && index.is_a?(Integer) && index >= 0 && index < commands.length
        key, text = index, commands[index]
      elsif kind == :pbConfirm
        sprites = PokeAccess.ivar(scene, :@s)
        yes, no = sprites.is_a?(Hash) ? [sprites['yes'], sprites['no']] : [nil, nil]
        return unless yes && no && !yes.disposed? && !no.disposed?
        return unless [yes.opacity, no.opacity].max >= 250 && yes.opacity != no.opacity
        key = yes.opacity > no.opacity
        text = modal[key ? 'yes' : 'no']
      elsif kind == :pbChooseNumber
        key = modal[:quantity]
        text = PokeAccess::I18n.t(:sv_pb_quantity, :n => key) unless key.nil?
      end
      return unless text.is_a?(String) && !text.empty?
      PokeAccess::Cursor.announce(modal, :xenoverse_bag_modal, key, true, false) { text }
    end

    def self.close(scene)
      return unless @scene.equal?(scene)
      PokeAccess::Info.clear_text
      PokeAccess::Cursor.reset(@modal, :xenoverse_bag_modal) if @modal
      @scene, @modal, @pocket = nil, nil, nil
    end
  end
end

PokeAccess::Game.define("xenoverse") do
  after("NewBagScreen", :pbStartScene, :hook_container => true) { |scene, _result, _args| PokeAccess::XenoverseBag.open(scene) }
  on_paint("NewBagScreen", :drawItemInfo) { |scene, rows, _args| PokeAccess::XenoverseBag.capture_name(scene, rows) }
  [:update, :updatePocket, :pbChangeSelection, :pbRefresh].each do |method|
    after("NewBagScreen", method, :hook_container => true) { |scene, _result, _args| PokeAccess::XenoverseBag.poll(scene) }
  end
  [:pbDisplay, :pbConfirm, :pbChooseNumber, :pbShowCommands].each do |method|
    around("NewBagScreen", method) do |scene, call_next, args|
      PokeAccess::XenoverseBag.modal(scene, method, args) { call_next.call }
    end
  end
  before("NewBagScreen", :pbEndScene) { |scene, _args| PokeAccess::XenoverseBag.close(scene) }
  kernel("pbDrawTextPositions", :after) { |args, _result| PokeAccess::XenoverseBag.capture_modal_paint(args) }
end
PokeAccess::Frame.each_pulse { PokeAccess::XenoverseBag.modal_poll }
