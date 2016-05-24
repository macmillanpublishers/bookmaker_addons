require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# ---------------------- VARIABLES

data_hash = Mcmlln::Tools.readjson(Metadata.configfile)

OEBPS_dir = File.join(Bkmkr::Paths.project_tmp_dir, "OEBPS")

zipepub_py = File.join(Bkmkr::Paths.core_dir, "epubmaker", "zipepub.py")

# path to epubcheck
epubcheck = File.join(Bkmkr::Paths.core_dir, "epubmaker", "epubcheck", "epubcheck.jar")

epubmakerpostprocessingjs = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "epubmaker_postprocessing.js")

# ---------------------- METHODS

# ---------------------- PROCESSES

# Add links back to TOC to chapter heads
searchdir = File.join(OEBPS_dir, "ch[0-9][0-9]*.html")
chapfiles = Dir.glob(searchdir)
chapfiles.each do |c|
  Bkmkr::Tools.runnode(epubmakerpostprocessingjs, c)
end

# Add links back to TOC to appendix heads
searchdir = File.join(OEBPS_dir, "app[0-9][0-9]*.html")
chapfiles = Dir.glob(searchdir)
chapfiles.each do |c|
  Bkmkr::Tools.runnode(epubmakerpostprocessingjs, c)
end

# Add links back to TOC to preface heads (explicitly, to exempt TOC & Title page)
searchdir = File.join(OEBPS_dir, "preface[0-9][0-9]*.html")
chapfiles = Dir.glob(searchdir)
chapfiles.each do |c|
  Bkmkr::Tools.runnode(epubmakerpostprocessingjs, c)
end

# Add links back to TOC to part heads
searchdir = File.join(OEBPS_dir, "part[0-9][0-9]*.html")
chapfiles = Dir.glob(searchdir)
chapfiles.each do |c|
  Bkmkr::Tools.runnode(epubmakerpostprocessingjs, c)
end

# fix toc entry in ncx
# fix title page text in ncx
ncxcontents = File.read("#{OEBPS_dir}/toc.ncx")
replace = ncxcontents.gsub(/<navLabel><text\/><\/navLabel><content src="toc/,"<navLabel><text>Contents</text><\/navLabel><content src=\"toc").gsub(/(<navLabel><text>)([a-zA-Z\s]*?)(<\/text><\/navLabel><content src="titlepage)/,"\\1Title Page\\3")
File.open("#{OEBPS_dir}/toc.ncx", "w") {|file| file.puts replace}

# hide toc entry in html toc
# fix title page text in html toc
htmlcontents = File.read("#{OEBPS_dir}/toc01.html")
copyright_li = htmlcontents.match(/<li data-type="copyright-page".*?<\/li>/)
replace = htmlcontents.gsub(/(titlepage01.html#.*?">)(.*?)(<\/a>)/,"\\1Title Page\\3").gsub(/(<li data-type="copyright-page">)/,"<li data-type=\"toc\" class=\"Nonprinting\"><a href=\"toc01.html\">Contents</a></li>\\1").gsub(/(<li data-type="preface")(><a href=".*">Newsletter Sign-up)/,"\\1 class=\"Nonprinting\"\\2").gsub(/<li data-type="cover"><a href="\#bookcover01"\/>/,"<li data-type=\"cover\" class=\"Nonprinting\"><a href=\"cover.html\">Cover</a>")
File.open("#{OEBPS_dir}/toc01.html", "w") {|file| file.puts replace}

# add toc to text flow
opfcontents = File.read("#{OEBPS_dir}/content.opf")
copyright_tag = opfcontents.scan(/<itemref idref="copyright-page/)
tocid = opfcontents.match(/(id=")(toc-.*?)(")/)[2]
toc_tag = opfcontents.match(/<itemref idref="toc-.*?"\/>/)
if copyright_tag.any?
	replace = opfcontents.gsub(/#{toc_tag}/,"").gsub(/(<itemref idref="copyright-page)/,"#{toc_tag}\\1")
else 
	replace = opfcontents.gsub(/#{toc_tag}/,"").gsub(/(<\/spine)/,"#{toc_tag}\\1")
end
File.open("#{OEBPS_dir}/content.opf", "w") {|file| file.puts replace}

# remove titlepage.jpg if exists
podtitlepagetmp = File.join(OEBPS_dir, "titlepage.jpg")
if File.file?(podtitlepagetmp)
	FileUtils.rm(podtitlepagetmp)
end

csfilename = "#{Metadata.eisbn}_EPUB"

# zip epub
Bkmkr::Tools.runpython(zipepub_py, "#{csfilename}.epub #{Bkmkr::Paths.project_tmp_dir}")

FileUtils.cp("#{Bkmkr::Paths.project_tmp_dir}/#{csfilename}.epub", "#{Bkmkr::Paths.done_dir}/#{Metadata.pisbn}")

# Renames final epub for firstpass
if data_hash['stage'].include? "egalley" or data_hash['stage'].include? "galley" or data_hash['stage'].include? "firstpass"
  FileUtils.mv("#{Bkmkr::Paths.done_dir}/#{Metadata.pisbn}/#{Metadata.eisbn}_EPUB.epub", "#{Bkmkr::Paths.done_dir}/#{Metadata.pisbn}/#{Metadata.eisbn}_EPUBfirstpass.epub")
  csfilename = "#{Metadata.eisbn}_EPUBfirstpass"
end

# validate epub file
Bkmkr::Tools.runjar(epubcheck, "#{Bkmkr::Paths.done_dir}/#{Metadata.pisbn}/#{csfilename}.epub")
