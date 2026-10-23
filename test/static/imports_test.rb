# A reader two games share lives once, in a common (games/<name>_common) both import: every import names a common with
# a manifest, a common is never a game (no catalog entry, no imports of its own, someone imports it), and no file is
# left copied between two playable profiles (compared with each file's own profile name blanked out, so a copy that
# differs only in its Game.define still counts).
require "json"
require File.expand_path("imports", File.dirname(__FILE__))

class ImportsTest < PokeAccessTest
  # A profile importing a common that imports another, and a common nobody imports.
  CHAIN = { "alpha" => ["one_common"], "one_common" => ["two_common"], "two_common" => [], "lone_common" => [] }

  test "every import names a common folder that has its manifest" do
    assert_equal [], bad_imports(imports, Imports.folders)
  end

  test "an import of a folder that is no common, or of one without a manifest, is reported" do
    imports = { "alpha" => ["beta", "gamma_common", "shared_common"], "beta" => ["delta"], "shared_common" => [] }
    assert_equal ["alpha imports beta, which does not end in _common",
                  "alpha imports gamma_common, with no games/gamma_common/manifest.rb",
                  "beta imports delta, which does not end in _common",
                  "beta imports delta, with no games/delta/manifest.rb"],
                 bad_imports(imports, ["alpha", "beta", "shared_common"])
  end

  test "no common imports another" do
    assert_equal [], nested_commons(imports)
  end

  test "no common has a catalog entry, so none is ever detected as a game" do
    assert_equal [], cataloged_commons(imports, catalog_keys)
  end

  test "every common is imported by some playable profile" do
    assert_equal [], orphan_commons(imports)
  end

  test "a common that imports another is reported" do
    assert_equal ["one_common"], nested_commons(CHAIN)
  end

  test "a common the catalog lists is reported" do
    assert_equal ["two_common"], cataloged_commons(CHAIN, ["alpha", "two_common"])
  end

  test "a common no playable profile imports is reported, one only another common imports included" do
    assert_equal ["lone_common", "two_common"], orphan_commons(CHAIN)
  end

  test "no file is copied between two playable profiles" do
    sources = profile_sources
    strays = sources.map { |p, files| files.keys.reject { |rel| rel.start_with?("games/#{p}/") } }.flatten
    assert_equal [], strays, "each profile's files are read under games/<profile>/"
    assert_equal [], twins(sources), "what two games share goes to a common"
  end

  test "two profiles' files that differ only in their own profile names are twins" do
    sources = {
      "alpha" => { "games/alpha/menu.rb" => "Game.define(:alpha)\nread\n", "games/alpha/own.rb" => "alpha only\n" },
      "beta" => { "games/beta/menu.rb" => "Game.define(:beta)\nread\n", "games/beta/own.rb" => "beta, other\n" }
    }
    assert_equal [["games/alpha/menu.rb", "games/beta/menu.rb"]], twins(sources)
  end

  test "a file repeated inside one profile is no twin" do
    assert_equal [], twins("alpha" => { "games/alpha/a.rb" => "read\n", "games/alpha/sub/a.rb" => "read\n" })
  end

  test "two profiles' manifests that list the same modules are no twins" do
    manifest = "{ :modules => %w[\n  menus\n] }\n"
    assert_equal [], twins("alpha" => { "games/alpha/manifest.rb" => manifest },
                           "beta" => { "games/beta/manifest.rb" => manifest })
  end

  private

  # { folder => [names its manifest imports] } for every folder under games/ with a manifest.
  def imports
    Imports.folders.each_with_object({}) { |f, out| out[f] = Imports.of(f) }
  end

  # The keys of the catalog's profiles.
  def catalog_keys
    JSON.parse(File.read(File.join(Imports::ROOT, "games", "catalog.json")))["profiles"].map { |e| e["key"] }
  end

  # The imports of playable profiles that name no common, or a folder absent from folders.
  def bad_imports(imports, folders)
    out = []
    imports.reject { |f, _| Imports.common?(f) }.each do |p, names|
      names.each do |c|
        out.push("#{p} imports #{c}, which does not end in _common") unless Imports.common?(c)
        out.push("#{p} imports #{c}, with no games/#{c}/manifest.rb") unless folders.include?(c)
      end
    end
    out
  end

  # The commons that import something.
  def nested_commons(imports)
    imports.select { |f, names| Imports.common?(f) && !names.empty? }.keys.sort
  end

  # The commons the catalog lists as profiles.
  def cataloged_commons(imports, keys)
    imports.keys.select { |f| Imports.common?(f) && keys.include?(f) }.sort
  end

  # The commons no playable profile imports.
  def orphan_commons(imports)
    used = imports.reject { |f, _| Imports.common?(f) }.values.flatten
    imports.keys.select { |f| Imports.common?(f) && !used.include?(f) }.sort
  end

  # { profile => { path from the repo root => text } } of every playable profile's files.
  def profile_sources
    Imports.folders.reject { |f| Imports.common?(f) }.each_with_object({}) do |p, out|
      out[p] = {}
      Dir.glob(File.join(Imports::ROOT, "games", p, "**", "*.rb")).sort.each do |f|
        out[p][f[(Imports::ROOT.length + 1)..-1].tr("\\", "/")] = File.read(f)
      end
    end
  end

  # The sorted groups of paths, from two profiles or more, whose texts match once each profile's own name is blanked;
  # a manifest, which only lists its own folder's files, never counts.
  def twins(sources)
    copies = {}
    sources.each do |p, files|
      files.each do |rel, text|
        (copies[text.gsub(p, "<PROFILE>")] ||= []).push(rel) unless File.basename(rel) == "manifest.rb"
      end
    end
    copies.values.select { |rels| rels.map { |r| r.split("/")[1] }.uniq.length > 1 }.map { |rels| rels.sort }.sort
  end
end
