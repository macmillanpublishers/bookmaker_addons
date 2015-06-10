require 'FileUtils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# These commands should run immediately after to epubmaker

configfile = File.join(Bkmkr::Paths.project_tmp_dir, "config.json")
file = File.read(configfile)
data_hash = JSON.parse(file)

# Renames final epub for firstpass
if data_hash['stage'].include? "egalley" or data_hash['stage'].include? "firstpass"
  FileUtils.mv("#{Bkmkr::Paths.done_dir}/#{Metadata.pisbn}/#{Metadata.eisbn}_EPUB.epub", "#{Bkmkr::Paths.done_dir}/#{Metadata.pisbn}/#{Metadata.eisbn}_EPUBfirstpass.epub")
end