# Commons: the games/<name>_common folders a profile's manifest imports (:imports), whose modules the loader evaluates
# after the plugins and before the profile's own. Shared by the static specs that map a file or a plugin to the games
# it runs in.
module Imports
  ROOT = File.expand_path("../..", File.dirname(__FILE__))

  # True for a common's folder name.
  def self.common?(name)
    name.to_s =~ /_common\z/ ? true : false
  end

  # The evaluated games/<name>/manifest.rb, or nil when there is none.
  def self.manifest(name)
    mf = File.join(ROOT, "games", name.to_s, "manifest.rb")
    File.file?(mf) ? eval(File.read(mf), TOPLEVEL_BINDING, mf) : nil
  end

  # The folders under games/ with a manifest, commons included, sorted.
  def self.folders
    Dir.glob(File.join(ROOT, "games", "*", "manifest.rb")).sort.map { |mf| File.basename(File.dirname(mf)) }
  end

  # The names a folder's manifest imports, as written.
  def self.of(name)
    value = manifest(name)
    (value.is_a?(Hash) && value[:imports].is_a?(Array)) ? value[:imports].map { |n| n.to_s } : []
  end

  # { common => [profile, ...] }: the playable profiles that import each common.
  def self.importers
    out = {}
    folders.reject { |f| common?(f) }.each { |p| of(p).each { |c| (out[c] ||= []).push(p) } }
    out
  end

  # The plugins a profile loads, its own :plugins joined by its commons' as loader/boot.rb joins them: :auto stays
  # :auto, and nil when neither declares a list.
  def self.plugins(name)
    lists = ([name] + of(name)).map { |n| v = manifest(n); v.is_a?(Hash) ? v[:plugins] : nil }
    return :auto if lists.first == :auto
    arrays = lists.select { |l| l.is_a?(Array) }
    arrays.empty? ? nil : arrays.inject([]) { |all, l| all | l.map { |n| n.to_s } }
  end
end
