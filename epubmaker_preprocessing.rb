require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# These commands should run immediately prior to epubmaker

configfile = File.join(Bkmkr::Paths.project_tmp_dir, "config.json")
file = File.read(configfile)
data_hash = JSON.parse(file)

project_dir = data_hash['project']

epub_tmp_html = File.join(Bkmkr::Paths.project_tmp_dir, "epub_tmp.html")
saxonpath = File.join(Bkmkr::Paths.resource_dir, "saxon", "#{Bkmkr::Tools.xslprocessor}.jar")
assets_dir = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "epubmaker")

# Adding imprint logo to title page
# Removing images subdir from src attr
# inserting imprint backad, if it exists
# remove links from illo sources

copyrightpage = File.read(Bkmkr::Paths.outputtmp_html).match(/(<section data-type=\"copyright-page\" .*?\">)((.|\n)*?)(<\/section>)/)

filecontents = File.read(Bkmkr::Paths.outputtmp_html).gsub(/<p class="TitlepageImprintLineimp">/,"<p class=\"TitlepageLogoHolder\"><img src=\"logo.jpg\"/></p><p class=\"TitlepageImprintLineimp\">").gsub(/src="images\//,"src=\"").gsub(/(<p class="IllustrationSourceis">)(<a class="fig-link">)(.*?)(<\/a>)(<\/p>)/, "\\1\\3\\5")#.gsub(/<\/body>/,"#{backad}</body>").gsub(/(<section data-type=\"copyright-page\" .*?\">)((.|\n)*?)(<\/section>)/,"").gsub(/(<\/body>)/, "#{copyrightpage}\\1")

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

# prep for titlepage image if needed
# convert image to jpg
# copy to image dir

images = Dir.entries(Bkmkr::Paths.submitted_images)
finalimagedir = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "images")
imgstring = images.join(",")
etpfilename = imgstring.match(/epubtitlepage.[a-zA-Z]*?/)

unless etpfilename.nil?
  epubtitlepage = File.join(Bkmkr::Paths.submitted_images, etpfilename)
  puts epubtitlepage
  epubtitlepagearc = File.join(finalimagedir, etpfilename)
  epubtitlepagejpg = File.join(Bkmkr::Paths.submitted_images, "epubtitlepage.jpg")
  etpfiletype = etpfilename.split(".").pop
  filecontents = filecontents.gsub(/(<section data-type="titlepage")/,"\\1 data-titlepage=\"yes\"")
  unless etpfiletype == "jpg"
    `convert "#{epubtitlepage}" "#{epubtitlepagejpg}"`
  end
  FileUtils.mv(epubtitlepagejpg, finalimagedir)
  FileUtils.mv(epubtitlepage, epubtitlepagearc)
end

File.open(epub_tmp_html, 'w') do |output| 
  output.write filecontents
end

# insert titlepage image
epubmakerpreprocessingjs = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "epubmaker_preprocessing.js")

Bkmkr::Tools.runnode(epubmakerpreprocessingjs, epub_tmp_html)

# Make EBK hyperlinks
strip_span_xsl = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "strip-spans.xsl")

`java -jar "#{saxonpath}" -s:"#{epub_tmp_html}" -xsl:"#{strip_span_xsl}" -o:"#{epub_tmp_html}"`

# and strip manual breaks
filecontents = File.read(epub_tmp_html).gsub(/(<p class="EBKLinkSourceLa">)(.*?)(<\/p>)(<p class="EBKLinkDestinationLb">)(.*?)(<\/p>)/,"\\1<a href=\"\\5\">\\2</a>\\3").gsub(/<br\/>/,"")

File.open(epub_tmp_html, 'w') do |output| 
  output.write filecontents
end

# strip halftitlepage from html
strip_halftitle_xsl = File.join(Bkmkr::Paths.core_dir, "epubmaker", "strip-halftitle.xsl")
# insert DRM copyright notice in HTML
drm_xsl = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "drm.xsl")

copyright_xsl = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "copyrightpagenotice.xsl")

`java -jar "#{saxonpath}" -s:"#{epub_tmp_html}" -xsl:"#{strip_halftitle_xsl}" -o:"#{epub_tmp_html}"`

#`java -jar "#{saxonpath}" -s:"#{epub_tmp_html}" -xsl:"#{drm_xsl}" -o:"#{epub_tmp_html}"`

`java -jar "#{saxonpath}" -s:"#{epub_tmp_html}" -xsl:"#{copyright_xsl}" -o:"#{epub_tmp_html}"`

# replace titlepage info with image IF image exists in submission dir
# js: replace titlepage innerhtml, prepend h1 w class nonprinting

#set logo image based on project directory
logo_img = File.join(assets_dir, "images", project_dir, "logo.jpg")
epub_img_dir = File.join(Bkmkr::Paths.project_tmp_dir, "epubimg")

unless File.exist?(epub_img_dir)
    Dir.mkdir(epub_img_dir)
end

#copy logo image file to epub folder
FileUtils.cp(logo_img, epub_img_dir)

#copy addon images to epub folder
addon_imgs = File.join(assets_dir, "addons", "images", ".")
FileUtils.cp_r(addon_imgs, epub_img_dir)

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

# suppress addon headers as needed
linkauthorname = "#{Metadata.bookauthor}".downcase.gsub(/\s/,"")
filecontents = File.read(epub_tmp_html).gsub(/(data-displayheader="no")/,"class=\"ChapTitleNonprintingctnp\" \\1").gsub(/\{\{IMPRINT\}\}/,"#{Metadata.imprint}").gsub(/\{\{AUTHORNAME\}\}/,"#{linkauthorname}").gsub(/\{\{EISBN\}\}/,"#{Metadata.eisbn}")

File.open(epub_tmp_html, 'w') do |output| 
  output.write filecontents
end
