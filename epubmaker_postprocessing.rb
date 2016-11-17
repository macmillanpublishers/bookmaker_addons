require 'fileutils'
require 'net/smtp'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# ---------------------- VARIABLES

data_hash = Mcmlln::Tools.readjson(Metadata.configfile)

OEBPS_dir = File.join(Bkmkr::Paths.project_tmp_dir, "OEBPS")

zipepub_py = File.join(Bkmkr::Paths.core_dir, "epubmaker", "zipepub.py")

# path to fallback font file
font = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "epubmaker", "fonts", "NotoSansSymbols-Regular.ttf")

# path to epubcheck
epubcheck = File.join(Bkmkr::Paths.core_dir, "epubmaker", "epubcheck", "epubcheck.jar")

epubmakerpostprocessingjs = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "epubmaker_postprocessing.js")

testing_value_file = File.join(Bkmkr::Paths.resource_dir, "staging.txt")

# full path of epubcheck error file
epubcheck_errfile = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "EPUBCHECK_ERROR.txt")

# ---------------------- METHODS
# If an epubcheck_errfile exists, delete it
def checkErrorFile(file)
  if File.file?(file)
    Mcmlln::Tools.deleteFile(file)
  end
end

def listSpacebreakImages(file)
  # An array of all the image files referenced in the source html file
  imgarr = File.read(file).scan(/(figure class="Illustrationholderill customimage"><img src="images\/)(\S*)(")/)
  imgnames = []
  imgarr.each do |o|
    imgnames << o[1]
  end
  # remove duplicate image names from source array
  imgnames = imgnames.uniq
  imgnames
end

def convertSpacebreakImg(file, dir)
  path_to_i = File.join(dir, file)
  myres = `identify -format "%y" "#{path_to_i}"`
  myres = myres.to_f
  if File.file?(path_to_i)
    puts "RESIZING #{path_to_i} for EPUB"
    `convert "#{path_to_i}" -colorspace RGB -density #{myres} -resize "200x200>" -quality 100 "#{path_to_i}"`
  end
end

# ---------------------- PROCESSES

checkErrorFile(epubcheck_errfile)

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

# Add links back to TOC to preface heads
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

# adjust size of custom space break images
# run method: listImages
imgarr = listSpacebreakImages(Bkmkr::Paths.outputtmp_html)

if imgarr.any?
  imgarr.each do |i|
    convertSpacebreakImg(i, OEBPS_dir)
  end
end

csfilename = "#{Metadata.eisbn}_EPUB"

# copy fallback font to package
Mcmlln::Tools.copyFile(font, OEBPS_dir)

# zip epub
Bkmkr::Tools.runpython(zipepub_py, "#{csfilename}.epub #{Bkmkr::Paths.project_tmp_dir}")

FileUtils.cp("#{Bkmkr::Paths.project_tmp_dir}/#{csfilename}.epub", "#{Bkmkr::Paths.done_dir}/#{Metadata.pisbn}")

# Renames final epub for firstpass
if data_hash['stage'].include? "egalley" or data_hash['stage'].include? "galley" or data_hash['stage'].include? "firstpass"
  FileUtils.mv("#{Bkmkr::Paths.done_dir}/#{Metadata.pisbn}/#{Metadata.eisbn}_EPUB.epub", "#{Bkmkr::Paths.done_dir}/#{Metadata.pisbn}/#{Metadata.eisbn}_EPUBfirstpass.epub")
  csfilename = "#{Metadata.eisbn}_EPUBfirstpass"
end

# validate epub file
epubcheck_output = Bkmkr::Tools.runjar(epubcheck, "#{Bkmkr::Paths.done_dir}/#{Metadata.pisbn}/#{csfilename}.epub")
puts epubcheck_output  #for log (so warnings are still visible)

#if error in epubcheck, write file for user, and email workflows
if epubcheck_output =~ /ERROR/ || epubcheck_output =~ /Check finished with errors/
	File.open(epubcheck_errfile, 'w') do |output|
		output.puts "Epub validation via epubcheck encountered errors."
		output.puts "\n \n(Epubcheck detailed output:)\n "
		output.puts epubcheck_output
	end

message = <<MESSAGE_END
From: Workflows <workflows@macmillan.com>
To: Workflows <workflows@macmillan.com>
Subject: ERROR: epubcheck errors for #{csfilename}.epub

Epubcheck validation found errors for file:
#{Bkmkr::Paths.done_dir}/#{Metadata.pisbn}/#{csfilename}.epub

Epubcheck output:
#{epubcheck_output}
MESSAGE_END

	unless File.file?(testing_value_file)
	  Net::SMTP.start('10.249.0.12') do |smtp|
	    smtp.send_message message, 'workflows@macmillan.com',
	                               'workflows@macmillan.com'
	  end
	end
end
