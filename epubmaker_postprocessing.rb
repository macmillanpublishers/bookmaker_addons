require 'FileUtils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# These commands should run immediately after to epubmaker

configfile = File.join(Bkmkr::Paths.project_tmp_dir, "config.json")
file = File.read(configfile)
data_hash = JSON.parse(file)

OEBPS_dir = File.join(Bkmkr::Paths.project_tmp_dir, "OEBPS")
zipepub_py = File.join(Bkmkr::Paths.core_dir, "epubmaker", "zipepub.py")

# Add links back to TOC to chapter heads
searchdir = File.join(OEBPS_dir, "ch[0-9][0-9]*.html")
chapfiles = Dir.glob(searchdir)

chapfiles.each do |c|
	replace = File.read(c).gsub(/(<section data-type="chapter".*?><h1.*?>)(.*?)(<\/h1>)/, "\\1<a href=\"toc01.html\">\\2</a>\\3")
	File.open(c, "w") {|file| file.puts replace}
end

csfilename = "#{Metadata.eisbn}_EPUB"

# zip epub
Bkmkr::Tools.runpython(zipepub_py, "#{csfilename}.epub #{Bkmkr::Paths.project_tmp_dir}")

FileUtils.cp("#{Bkmkr::Paths.project_tmp_dir}/#{csfilename}.epub", "#{Bkmkr::Paths.done_dir}/#{Metadata.pisbn}")

# Renames final epub for firstpass
if data_hash['stage'].include? "egalley" or data_hash['stage'].include? "firstpass"
  FileUtils.mv("#{Bkmkr::Paths.done_dir}/#{Metadata.pisbn}/#{Metadata.eisbn}_EPUB.epub", "#{Bkmkr::Paths.done_dir}/#{Metadata.pisbn}/#{Metadata.eisbn}_EPUBfirstpass.epub")
end