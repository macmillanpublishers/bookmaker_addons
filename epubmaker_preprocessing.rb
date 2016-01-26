require 'fileutils'
require 'unidecoder'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'
require_relative '../utilities/oraclequery.rb'

# These commands should run immediately prior to epubmaker

configfile = File.join(Bkmkr::Paths.project_tmp_dir, "config.json")
file = File.read(configfile)
data_hash = JSON.parse(file)

project_dir = data_hash['project']

epub_tmp_html = File.join(Bkmkr::Paths.project_tmp_dir, "epub_tmp.html")
saxonpath = File.join(Bkmkr::Paths.resource_dir, "saxon", "#{Bkmkr::Tools.xslprocessor}.jar")
assets_dir = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "epubmaker")
epub_img_dir = File.join(Bkmkr::Paths.project_tmp_dir, "epubimg")
finalimagedir = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "images")

unless File.exist?(epub_img_dir)
    Dir.mkdir(epub_img_dir)
end

# Adding imprint logo to title page
# Removing images subdir from src attr
# inserting imprint backad, if it exists
# remove links from illo sources

copyrightpage = File.read(Bkmkr::Paths.outputtmp_html).match(/(<section data-type=\"copyright-page\" .*?\">)((.|\n)*?)(<\/section>)/)

filecontents = File.read(Bkmkr::Paths.outputtmp_html).gsub(/<p class="TitlepageImprintLineimp">/,"<p class=\"TitlepageLogoHolder\"><img src=\"logo.jpg\"/></p><p class=\"TitlepageImprintLineimp\">").gsub(/src="images\//,"src=\"").gsub(/(<p class="IllustrationSourceis">)(<a class="fig-link">)(.*?)(<\/a>)(<\/p>)/, "\\1\\3\\5")

chapterheads = File.read(Bkmkr::Paths.outputtmp_html).scan(/section data-type="chapter"/)

unless chapterheads.count > 1
  filecontents = filecontents.gsub(/(<section data-type="chapter" .*?><h1 class=".*?">)(.*?)(<\/h1>)/,"\\1Begin Reading\\3")
end

#set text node contents of all Space Break paras to "* * *"
filecontents = filecontents.gsub(/(<p class=\"SpaceBreak[^\/]*?>)(.*?)(<\/p>)/,'\1* * *\3').gsub(/(<p class=\"SpaceBreak.*?)( \/>)/,'\1>* * *</p>')

# Update several copyright elements for epub
if filecontents.include?('data-type="copyright-page"')
  copyright_txt = filecontents.match(/(<section data-type=\"copyright-page\" .*?\">)((.|\n)*?)(<\/section>)/)[2]
  # Note: last gsub here presumes Printer's key is the only copyright item that might be a <p>with just a number, eg <p class="xxx">13</p>
  new_copyright = copyright_txt.to_s.gsub(/(ISBN )([0-9\-]{13,20})( \(e-book\))/, "e\\1\\2").gsub(/ Printed in the United States of America./, "").gsub(/ Copyright( |\D|&.*?;)+/, " Copyright &#169; ").gsub(/<p class="\w*?">(\d+|(\d+\s){1,9}\d)<\/p>/, "")
  # Note: this gsub block presumes that these urls do not already have <a href> tags.
  new_copyright = new_copyright.gsub(/([^\s>]+.(com|org|net)[^\s<]*)/) do |m|
    url_prefix = "http:\/\/"
    if m.match(/@/)
      url_prefix = "mailto:"
    elsif m.match(/http/)
      url_prefix = ""
    end
    "<a href=\"#{url_prefix}#{m}\">#{m}<\/a>"
  end
  filecontents = filecontents.gsub(/(^(.|\n)*?<section data-type="copyright-page" id=".*?">)((.|\n)*?)(<\/section>(.|\n)*$)/, "\\1#{new_copyright}\\5")
end

File.open(epub_tmp_html, 'w') do |output| 
  output.write filecontents
end

# prep for titlepage image if needed
# convert image to jpg
# copy to image dir

unless Metadata.epubtitlepage == "Unknown"
  puts "found an epub titlepage image"
  etpfilename = Metadata.epubtitlepage.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop
  etpfiletype = etpfilename.split(".").pop
  epubtitlepagearc = File.join(finalimagedir, etpfilename)
  epubtitlepagetmp = File.join(epub_img_dir, "epubtitlepage.jpg")
  if etpfiletype == "jpg"
    FileUtils.cp(epubtitlepagearc, epubtitlepagetmp)
  else
    `convert "#{epubtitlepagearc}" "#{epubtitlepagetmp}"`
  end
  # insert titlepage image
  filecontents = File.read(epub_tmp_html).gsub(/(<section data-type="titlepage")/,"\\1 data-titlepage=\"yes\"")
  File.open(epub_tmp_html, 'w') do |output| 
    output.write filecontents
  end
end

#set logo image based on project directory
logo_img = File.join(assets_dir, "images", project_dir, "logo.jpg")

#copy logo image file to epub folder if no epubtitlepage found
if Metadata.epubtitlepage == "Unknown" and File.file?(logo_img)
  FileUtils.cp(logo_img, epub_img_dir)
end

# Make EBK hyperlinks
strip_span_xsl = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "strip-spans.xsl")

`java -jar "#{saxonpath}" -s:"#{epub_tmp_html}" -xsl:"#{strip_span_xsl}" -o:"#{epub_tmp_html}"`

# and strip manual breaks
filecontents = File.read(epub_tmp_html).gsub(/(<p class="EBKLinkSourceLa">)(.*?)(<\/p>)(<p class="EBKLinkDestinationLb">)(.*?)(<\/p>)/,"\\1<a href=\"\\5\">\\2</a>\\3").gsub(/<br\/>/,"")

File.open(epub_tmp_html, 'w') do |output| 
  output.write filecontents
end

# do content conversions
epubmakerpreprocessingjs = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "epubmaker_preprocessing.js")
Bkmkr::Tools.runnode(epubmakerpreprocessingjs, epub_tmp_html)

# replace titlepage info with image IF image exists in submission dir
# js: replace titlepage innerhtml, prepend h1 w class nonprinting

# copy backad file to epub dir
# if File.file?(backad_file)
#   FileUtils.cp(backad_file, epub_img_dir)
# end

sectionjson = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "sections.json")
addonjson = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "epubmaker", "addons", "addons.json")

# move abouttheauthor to back
Bkmkr::Tools.movesection(epub_tmp_html, sectionjson, "abouttheauthor", "1", "endofbook", "1")

# move adcard to back
Bkmkr::Tools.movesection(epub_tmp_html, sectionjson, "adcard", "1", "endofbook", "1")

# move front sales to back
Bkmkr::Tools.movesection(epub_tmp_html, sectionjson, "frontsales", "1", "endofbook", "1")

# move toc to back
Bkmkr::Tools.movesection(epub_tmp_html, sectionjson, "toc", "1", "endofbook", "1")

# move copyright page to back
Bkmkr::Tools.movesection(epub_tmp_html, sectionjson, "copyrightpage", "1", "endofbook", "1")

# insert extra epub content
Bkmkr::Tools.insertaddons(epub_tmp_html, sectionjson, addonjson)

# evaluate templates
Bkmkr::Tools.compileJS(epub_tmp_html)

# find the author ID
thissql = personSearchSingleKey(Metadata.eisbn, "EDITION_EAN", "Author")
myhash = runQuery(thissql)

unless myhash['book'].nil? or myhash['book'].empty? or !myhash['book']
  puts "DB Connection SUCCESS: Found an author record"
else
  puts "No DB record found; removing author links for addons"
end

# suppress addon headers as needed
if myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash['book']['PERSON_REALNAME'].nil? or myhash['book']['PERSON_REALNAME'].empty? or !myhash['book']['PERSON_REALNAME']
  linkauthorname = Metadata.bookauthor.downcase.gsub(/\s/,"")
else
  linkauthorname = myhash['book']['PERSON_REALNAME'].downcase.gsub(/\s/,"")
end

linkauthorname = linkauthorname.to_ascii

if myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash['book']['PERSON_PARTNERID'].nil? or myhash['book']['PERSON_PARTNERID'].empty? or !myhash['book']['PERSON_PARTNERID']
  filecontents = File.read(epub_tmp_html).gsub(/(data-displayheader="no")/,"class=\"ChapTitleNonprintingctnp\" \\1").gsub(/\{\{IMPRINT\}\}/,"#{Metadata.imprint}").gsub(/\{\{AUTHORNAME\}\}/,"#{linkauthorname}").gsub(/\{\{EISBN\}\}/,"#{Metadata.eisbn}")
else
  filecontents = File.read(epub_tmp_html).gsub(/(data-displayheader="no")/,"class=\"ChapTitleNonprintingctnp\" \\1").gsub(/\{\{IMPRINT\}\}/,"#{Metadata.imprint}").gsub(/\{\{AUTHORNAME\}\}/,"#{linkauthorname}").gsub(/\{\{AUTHORID\}\}/,"#{myhash['book']['PERSON_PARTNERID']}").gsub(/\{\{EISBN\}\}/,"#{Metadata.eisbn}").gsub(/<!--AUTHORSIGNUPSTART/,"").gsub(/AUTHORSIGNUPEND-->/,"")
end

File.open(epub_tmp_html, 'w') do |output| 
  output.write filecontents
end
