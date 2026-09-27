# Opalo's photographs used from the bag (the locket, the torn photo and the whole one): each fills the screen in a
# loop that only C leaves, with no text until then. Said as they open, with the key that goes on.
module PokeAccess
  module OpaloPhotos
    # Item constant => what its picture shows.
    PHOTOS = [[:Guardapelo, :op_photo_locket], [:FOTOGATLING, :op_photo_torn], [:FOTOGATLING2, :op_photo_whole]]

    # The description key of an item that opens a photograph, or nil.
    def self.photo_key(item)
      pair = PHOTOS.find { |sym, _key| (PBItems.const_get(sym) rescue nil) == item }
      pair ? pair[1] : nil
    end

    # Says, before its loop starts, what a photograph shows and, while key hints are said, the key that goes on.
    def self.opening(item)
      key = photo_key(item)
      return unless key
      hint = PokeAccess::I18n.t(:title_press, :key => PokeAccess::KeyHints.key(:c, "C"))
      PokeAccess.speak(PokeAccess::Verbosity.with_hint(PokeAccess::I18n.t(key), hint, " "), true)
    end
  end
end

PokeAccess::Hooks.wrap_singleton("ItemHandlers", :triggerUseFromBag, "game_opalo_photos", :before) do |args, _r|
  PokeAccess::OpaloPhotos.opening(args[0])
end
