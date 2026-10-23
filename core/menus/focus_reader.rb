module PokeAccess
  # A declared reader for a screen whose cursor is an index (a scene ivar, :@index by default, or a @sprites window's
  # index, then left to this reader alone): after each hooked call it says the focused entry when the focus moves, the
  # first read queued and the next ones interrupting. The dedup lives on the scene, so a reopened screen starts fresh.
  module FocusReader
    # Declares the reader for class cname. opts: :on, the method hooked (:update); :index, an ivar symbol or a @sprites
    # key; :items, the ivar holding the list the index points into; :slot, the dedup slot; :queue false to let the first
    # read interrupt too; :key, a proc of scene, index and entry giving what has to change for a new read; :optional
    # and :hook_container, passed to the hook. The block gets the entry and the index with :items, else the index and
    # the scene, and returns the line; nil says nothing.
    def self.define(cname, opts = {}, &text)
      meth = opts[:on] || :update
      source = opts[:index] || :@index
      slot = opts[:slot] || :"focus_#{cname}"
      hook = { :optional => opts[:optional] ? true : false, :hook_container => opts[:hook_container] ? true : false }
      if source.is_a?(String)
        PokeAccess::Hooks.before_hook(cname, meth, :optional => hook[:optional]) do |scene, _a|
          PokeAccess.dedicate(PokeAccess.sprite(scene, source))
        end
      end
      PokeAccess::Hooks.after_hook(cname, meth, hook) do |scene, _r, _a|
        PokeAccess::FocusReader.read(scene, source, opts, slot, text)
      end
    end

    # Says scene's focused entry when its key changed.
    def self.read(scene, source, opts, slot, text)
      idx = source.is_a?(String) ? (PokeAccess.sprite(scene, source).index rescue nil) : PokeAccess.ivar(scene, source)
      return unless idx.is_a?(Integer) && idx >= 0
      args = [idx, scene]
      if opts[:items]
        list = PokeAccess.ivar(scene, opts[:items])
        return unless list.is_a?(Array) && idx < list.length
        args = [list[idx], idx, scene]
      end
      key = opts[:key] ? call_with(opts[:key], [scene, idx, args.length == 3 ? args[0] : nil]) : args[0..-2]
      first = opts[:queue] == false ? nil : false
      PokeAccess::Cursor.announce(scene, slot, key, true, first) { call_with(text, args) }
    rescue StandardError => e
      PokeAccess.swallowed(e)
    end

    # Calls blk with as many of values as it takes, never more: Ruby 1.8.7 hands a one-parameter block every value
    # it is called with, as one array.
    def self.call_with(blk, values)
      a = blk.arity
      blk.call(*values[0, a < 0 ? values.length : a])
    end
  end
end
