require 'fileutils'
require 'unidecoder'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'
require_relative '../utilities/oraclequery.rb'

# These commands should run immediately prior to epubmaker

data_hash = Mcmlln::Tools.readjson(Metadata.configfile)

project_dir = data_hash['project']
resource_dir = data_hash['resourcedir']

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

filecontents = File.read(Bkmkr::Paths.outputtmp_html).gsub(/src="images\//,"src=\"").gsub(/(<p class="IllustrationSourceis">)(<a class="fig-link">)(.*?)(<\/a>)(<\/p>)/, "\\1\\3\\5")

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
logo_img = File.join(assets_dir, "images", resource_dir, "logo.jpg")

#copy logo image file to epub folder if no epubtitlepage found
if Metadata.epubtitlepage == "Unknown" and File.file?(logo_img)
  FileUtils.cp(logo_img, epub_img_dir)
end

# Make EBK hyperlinks
strip_span_xsl = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "strip-spans.xsl")

`java -jar "#{saxonpath}" -s:"#{epub_tmp_html}" -xsl:"#{strip_span_xsl}" -o:"#{epub_tmp_html}"`

# and strip manual breaks
filecontents = File.read(epub_tmp_html).gsub(/(<p class="EBKLinkSourceLa">)(.*?)(<\/p>)(<p class="EBKLinkDestinationLb">)(.*?)(<\/p>)/,"\\1<a href=\"\\5\">\\2</a>\\3").gsub(/<br\/>/," ")

# and combine contiguous span urls
filecontents = filecontents.gsub(/(<span class="spanhyperlinkurl">)([^<|^>]*)(<\/span><span class="spanhyperlinkurl">)/,"\\1\\2")

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

filecontents = File.read(epub_tmp_html)

# link author name to newsletter page - need to restrict this so it only works on appendix sections
# aulink = "http://us.macmillan.com/newslettersignup?utm_source=ebook&utm_medium=adcard&utm_term=ebookreaders&utm_content={{AUTHORNAME}}_newslettersignup_macdotcom&utm_campaign={{EISBN}}"
# auupcase = Metadata.bookauthor.upcase
# filecontents = filecontents.gsub(Metadata.bookauthor,"<!--AUTHORSIGNUPSTART<a href=\"#{aulink}\">AUTHORSIGNUPEND-->\\0<!--AUTHORSIGNUPSTART</a>AUTHORSIGNUPEND-->").gsub(auupcase,"<!--AUTHORSIGNUPSTART<a href=\"#{aulink}\">AUTHORSIGNUPEND-->\\0<!--AUTHORSIGNUPSTART</a>AUTHORSIGNUPEND-->")

# find the author ID
thissql = personSearchSingleKey(Metadata.eisbn, "EDITION_EAN", "Author")
myhash = runPeopleQuery(thissql)

unless myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book']
  puts "DB Connection SUCCESS: Found an author record"
else
  puts "No DB record found; removing author links for addons"
end

linkauthorarr = []
linkauthorid = []

if myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash['book']['PERSON_REALNAME'].nil? or myhash['book']['PERSON_REALNAME'].empty? or !myhash['book']['PERSON_REALNAME']
  linkauthorarr = File.read(Bkmkr::Paths.outputtmp_html).scan(/<p class="TitlepageAuthorNameau">.*?</)
  linkauthorarr.map! { |x| x.gsub(/<p class="TitlepageAuthorNameau">/,"").gsub(/<\//,"") }
else
  linkauthorarr = myhash['book']['PERSON_REALNAME']
  linkauthorid = myhash['book']['PERSON_PARTNERID']
end

if linkauthorarr.count > 1
  # insert new author links in newsletter
  # fix author links in ABA sections
  newslinkarr = []
  linkauthorarr.each do |a|
    linkauthorname = a
    linkauthorfirst = a.split(" ").shift
    linkauthorlast = a.split(" ").pop
    linkauthornametxt = a.downcase.gsub(/\s/,"").gsub(/\W/,"").to_ascii
    linkauthornameall = a.downcase.gsub(/\s/,"").to_ascii
    filecontents = filecontents.gsub(/(--><\/p><\/section><section data-type="appendix" class="abouttheauthor".*?#{linkauthorfirst}.*?#{linkauthorlast}.*?)(\{\{AUTHORNAME\}\})(.*?>here<\/a>)/,"\\1#{linkauthornameall}\\3")
  end
  # another loop to fix the first ABA
  # and prepare the newsletter links
  linkauthorarr.each do |a|
    linkauthorname = a
    linkauthorfirst = a.split(" ").shift
    linkauthorlast = a.split(" ").pop
    linkauthornametxt = a.downcase.gsub(/\s/,"").gsub(/\W/,"").to_ascii
    linkauthornameall = a.downcase.gsub(/\s/,"").to_ascii
    filecontents = filecontents.gsub(/(<section data-type="appendix" class="abouttheauthor".*?#{linkauthorfirst}.*?#{linkauthorlast}.*?)(\{\{AUTHORNAME\}\})(.*?>here<\/a>)/,"\\1#{linkauthornameall}\\3")
    thislink = "<p style=\"text-align: center; text-indent: 0;\">For email updates on #{a}, click <a href=\"http:\/\/us.macmillan.com\/authoralerts?authorName=#{linkauthornametxt}&amp;authorRefId=AUTHORID&amp;utm_source=ebook&amp;utm_medium=adcard&amp;utm_term=ebookreaders&amp;utm_content=#{linkauthornameall}_authoralertsignup_macdotcom&amp;utm_campaign=\{\{EISBN\}\}\">here.<\/a><\/p>"
    newslinkarr << thislink
  end
  # replace author ID in newsletter links
  linkauthorid.each_with_index do |b, i|
    newslinkarr.collect!.with_index { |e, n|
      (n == i) ? e.gsub(/AUTHORID/, b) : e
    }
  end
  newsletterlink = newslinkarr.join(" ")
  # remove old link
  oldlink = "<p style=\"text-align: center; text-indent: 0;\">For email updates on the author, click <a href=\"http://us.macmillan.com/authoralerts?authorName=\{\{AUTHORNAMETXT\}\}&amp;authorRefId=\{\{AUTHORID\}\}&amp;utm_source=ebook&amp;utm_medium=adcard&amp;utm_term=ebookreaders&amp;utm_content=\{\{AUTHORNAME\}\}_authoralertsignup_macdotcom&amp;utm_campaign=\{\{EISBN\}\}\">here.</a></p>"
  mytest = filecontents.scan(/#{oldlink}/)
  puts mytest
  filecontents = filecontents.gsub(/#{oldlink}/, newsletterlink)
else
  linkauthornametxt = linkauthorarr.to_s.downcase.gsub(/\s/,"").gsub(/\W/,"").to_ascii
  linkauthornameall = linkauthorarr.to_s.downcase.gsub(/\s/,"").to_ascii
  if myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash['book']['PERSON_PARTNERID'].nil? or myhash['book']['PERSON_PARTNERID'].empty? or !myhash['book']['PERSON_PARTNERID']
    filecontents = filecontents.gsub(/\{\{AUTHORNAMETXT\}\}/,"#{linkauthornametxt}").gsub(/\{\{AUTHORNAME\}\}/,"#{linkauthornameall}")
  else
    filecontents = filecontents.gsub(/\{\{AUTHORNAMETXT\}\}/,"#{linkauthornametxt}").gsub(/\{\{AUTHORNAME\}\}/,"#{linkauthornameall}").gsub(/\{\{AUTHORID\}\}/,"#{myhash['book']['PERSON_PARTNERID']}")
  end
end

if myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash['book']['PERSON_PARTNERID'].nil? or myhash['book']['PERSON_PARTNERID'].empty? or !myhash['book']['PERSON_PARTNERID']
  filecontents = filecontents.gsub(/(data-displayheader="no")/,"class=\"ChapTitleNonprintingctnp\" \\1").gsub(/\{\{IMPRINT\}\}/,"#{Metadata.imprint}").gsub(/\{\{EISBN\}\}/,"#{Metadata.eisbn}")
else
  filecontents = filecontents.gsub(/(data-displayheader="no")/,"class=\"ChapTitleNonprintingctnp\" \\1").gsub(/\{\{IMPRINT\}\}/,"#{Metadata.imprint}").gsub(/\{\{EISBN\}\}/,"#{Metadata.eisbn}").gsub(/<!--AUTHORSIGNUPSTART/,"").gsub(/AUTHORSIGNUPEND-->/,"")
end

File.open(epub_tmp_html, 'w') do |output| 
  output.write filecontents
end
