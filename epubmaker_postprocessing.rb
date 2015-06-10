require 'FileUtils'

require_relative '../bookmaker/header.rb'
require_relative '../bookmaker/metadata.rb'

# These commands should run immediately after to epubmaker

configfile = File.join(Bkmkr::Paths.project_tmp_dir, "config.json")
file = File.read(configfile)
data_hash = JSON.parse(file)

# Renames final epub for firstpass
if data_hash['stage_dir'].include? "egalley" or data_hash['stage_dir'].include? "firstpass"
  FileUtils.cp("#{Bkmkr::Paths.done_dir}/#{Metadata.pisbn}/#{Metadata.eisbn}_EPUB.epub", "#{Bkmkr::Paths.done_dir}/#{Metadata.pisbn}/#{Metadata.eisbn}_EPUBfirstpass.epub")
end