require 'fileutils'
require 'unidecoder'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'
require_relative '../utilities/oraclequery.rb'

# These commands should run immediately prior to epubmaker

# ---------------------- VARIABLES
local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

epub_tmp_html = File.join(Bkmkr::Paths.project_tmp_dir, "epub_tmp.html")
saxonpath = File.join(Bkmkr::Paths.resource_dir, "saxon", "#{Bkmkr::Tools.xslprocessor}.jar")
assets_dir = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "epubmaker")
epub_img_dir = File.join(Bkmkr::Paths.project_tmp_dir, "epubimg")
finalimagedir = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "images")

# ---------------------- METHODS

def readConfigJson(logkey='')
  data_hash = Mcmlln::Tools.readjson(Metadata.configfile)
  return data_hash
rescue => logstring
  return {}
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping a Mcmlln::Tools method in a new method for this script; to return a result for json_logfile
def makeFolder(path, logkey='')
  unless File.exist?(path)
    Dir.mkdir(path)
  else
    logstring = 'n-a'
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# get copyright page
def getCopyrightPage(logkey='')
  # an array of all occurances of chapters in the manuscript
  copyrightpage = File.read(Bkmkr::Paths.outputtmp_html).match(/(<section data-type=\"copyright-page\" .*?\">)((.|\n)*?)(<\/section>)/)
  return copyrightpage
rescue => logstring
  return []
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# Removing images subdir from src attr
# remove links from illo sources
def fixImgSrcs(logkey='')
  filecontents = File.read(Bkmkr::Paths.outputtmp_html).gsub(/src="images\//,"src=\"").gsub(/(<p class="IllustrationSourceis">)(<a class="fig-link">)(.*?)(<\/a>)(<\/p>)/, "\\1\\3\\5")
  return filecontents
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# insert 'Begin Reading' link for books with only 1 chapter
def addBeginReading(filecontents, logkey='')
  # an array of all occurances of chapters in the manuscript
  chapterheads = File.read(Bkmkr::Paths.outputtmp_html).scan(/section data-type="chapter"/)
  # insert 'Begin Reading' link for books with only 1 chapter
  unless chapterheads.count > 1
    filecontents = filecontents.gsub(/(<section data-type="chapter" .*?><h1 class=".*?">)(.*?)(<\/h1>)/,"\\1Begin Reading\\3")
    logstring = '1 chapter only, fix applied'
  else
    logstring = "n-a (#{chapterheads.count} chapters found)"
  end
  return filecontents
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def setSpacebreakText(filecontents, logkey='')
  filecontents = filecontents.gsub(/(<p class=\"SpaceBreak[^\/]*?>)(.*?)(<\/p>)/,'\1* * *\3')
  filecontents = filecontents.gsub(/(<p class=\"SpaceBreak.*?)( \/>)/,'\1>* * *</p>')
  return filecontents
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# Update several copyright elements for epub
def fixCopyrightforEpub(filecontents, logkey='')
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
  else
    logstring = 'no copyright section in html'
  end
  return filecontents
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping a Mcmlln::Tools method in a new method for this script; to return a result for json_logfile
def overwriteFile(path, filecontents, logkey='')
	Mcmlln::Tools.overwriteFile(path, filecontents)
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# prep for titlepage image if needed
# convert image to jpg
# copy to image dir
def prepTitlePageImage(epub_tmp_html, finalimagedir, epub_img_dir, logkey='')
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
    filecontents = readHtml(epub_tmp_html, 'read-in_epub_tmp_html--for_tpimage')
    filecontents = filecontents.gsub(/(<section data-type="titlepage")/,"\\1 data-titlepage=\"yes\"")
    overwriteFile(epub_tmp_html, filecontents, 'overwrite_epubhtml--for_tpimage')
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def copyLogofile(logo_img, epub_img_dir, logkey='')
  if Metadata.epubtitlepage == "Unknown" and File.file?(logo_img)
    FileUtils.cp(logo_img, epub_img_dir)
  else
    logstring = 'n-a'
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping Bkmkr::Tools.processxsl in a new method for this script; to return a result for json_logfile
def addEBKhyperlinks(saxonpath, epub_tmp_html, strip_span_xsl, logkey='')
  `java -jar "#{saxonpath}" -s:"#{epub_tmp_html}" -xsl:"#{strip_span_xsl}" -o:"#{epub_tmp_html}"`
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping a Mcmlln::Tools method in a new method for this script; to return a result for json_logfile
def readHtml(file, logkey='')
  filecontents = File.read(file)
  return filecontents
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def stripManualBreaks(filecontents, logkey='')
  filecontents = filecontents.gsub(/(<p class="EBKLinkSourceLa">)(.*?)(<\/p>)(<p class="EBKLinkDestinationLb">)(.*?)(<\/p>)/,"\\1<a href=\"\\5\">\\2</a>\\3").gsub(/<br\/>/," ")
  return filecontents
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def combineContiguousSpanUrls(filecontents, logkey='')
  filecontents = filecontents.gsub(/(<span class="spanhyperlinkurl">)([^<|^>]*)(<\/span><span class="spanhyperlinkurl">)/,"\\1\\2")
  return filecontents
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping Bkmkr::Tools.runnode in a new method for this script; to return a result for json_logfile
def localRunNode(jsfile, args, logkey='')
  Bkmkr::Tools.runnode(jsfile, args)
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping Bkmkr::Tools.movesection in a new method for this script; to return a result for json_logfile
def localMoveSection(inputfile, sectionparams, src, srcseq, dest, destseq, logkey='')
  Bkmkr::Tools.movesection(inputfile, sectionparams, src, srcseq, dest, destseq)
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping Bkmkr::Tools.insertaddons in a new method for this script; to return a result for json_logfile
def localInsertAddons(inputfile, sectionparams, addonparams, logkey='')
  Bkmkr::Tools.insertaddons(inputfile, sectionparams, addonparams)
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

## wrapping Bkmkr::Tools.compileJS in a new method for this script; to return a result for json_logfile
def localCompileJS(file, logkey='')
  Bkmkr::Tools.compileJS(file)
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def databaseLookup(logkey='')
  thissql = personSearchSingleKey(Metadata.eisbn, "EDITION_EAN", "Author")
  myhash = runPeopleQuery(thissql)
  return myhash
rescue => logstring
  return {}
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def getlinkAuthorInfo(myhash, logkey='')
  linkauthorarr = []
  linkauthorid = []
  if myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash['book']['PERSON_REALNAME'].nil? or myhash['book']['PERSON_REALNAME'].empty? or !myhash['book']['PERSON_REALNAME']
    linkauthorarr = File.read(Bkmkr::Paths.outputtmp_html).scan(/<p class="TitlepageAuthorNameau">.*?</)
    linkauthorarr.map! { |x| x.gsub(/<p class="TitlepageAuthorNameau">/,"").gsub(/<\//,"") }
  else
    linkauthorarr = myhash['book']['PERSON_REALNAME'].clone
    linkauthorid = myhash['book']['PERSON_PARTNERID'].clone
  end
  return linkauthorarr, linkauthorid
rescue => logstring
  return [],[]
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def setNewsletterAuthorLinks(linkauthorarr, linkauthorid, filecontents, myhash, logkey='')
  if linkauthorarr.count > 1
    # make mini toc entry plural
    filecontents = filecontents.gsub(/(<a class="spanhyperlink" id="abouttheauthor" href="\S*?">About the Author)(<\/a>)/,"\\1s\\2")
    # insert new author links in newsletter
    # fix author links in ABA sections
    newslinkarr = []
    linkauthorarr.each_with_index do |a, i|
      linkauthorname = a
      linkauthorfirst = a.split(" ").shift
      linkauthorlast = a.split(" ").pop
      linkauthornametxt = a.downcase.gsub(/\s/,"").gsub(/\W/,"").to_ascii
      linkauthornameall = a.downcase.gsub(/\s/,"").to_ascii
      thisauthorid = linkauthorid[i]
      filecontents = filecontents.gsub(/(<section data-type="appendix" class="abouttheauthor".*?#{linkauthorfirst}.*?#{linkauthorlast}.*?)(\{\{AUTHORNAMETXT\}\})(.*?)(\{\{AUTHORID\}\})(.*?)(\{\{AUTHORNAME\}\})(.*?>here<\/a>)/,"\\1#{linkauthornametxt}\\3#{thisauthorid}\\5#{linkauthornameall}\\7")
    end
    # another loop to fix the first ABA
    # and prepare the newsletter links
    linkauthorarr.each_with_index do |a, i|
      linkauthorname = a
      linkauthorfirst = a.split(" ").shift
      linkauthorlast = a.split(" ").pop
      linkauthornametxt = a.downcase.gsub(/\s/,"").gsub(/\W/,"").to_ascii
      linkauthornameall = a.downcase.gsub(/\s/,"").to_ascii
      thisauthorid = linkauthorid[i]
      filecontents = filecontents.gsub(/(<section data-type="appendix" class="abouttheauthor".*?#{linkauthorfirst}.*?#{linkauthorlast}.*?)(\{\{AUTHORNAMETXT\}\})(.*?)(\{\{AUTHORID\}\})(.*?)(\{\{AUTHORNAME\}\})(.*?>here<\/a>)/,"\\1#{linkauthornametxt}\\3#{thisauthorid}\\5#{linkauthornameall}\\7")
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
    filecontents = filecontents.gsub(/<p style=\"text-align: center; text-indent: 0;\">For email updates on the author, click <a href=\"\S*?\">here.<\/a><\/p>/, newsletterlink)
    # set newsletter button link to use first author
    linkauthornametxt = linkauthorarr[0].downcase.gsub(/\s/,"").gsub(/\W/,"").to_ascii
    linkauthornameall = linkauthorarr[0].downcase.gsub(/\s/,"").to_ascii
    authorid = linkauthorid[0]
    filecontents = filecontents.gsub(/\{\{AUTHORNAMETXT\}\}/,"#{linkauthornametxt}").gsub(/\{\{AUTHORNAME\}\}/,"#{linkauthornameall}").gsub(/\{\{AUTHORID\}\}/,"#{authorid}")
  else
    linkauthornametxt = Metadata.bookauthor.downcase.gsub(/\s/,"").gsub(/\W/,"").to_ascii
    linkauthornameall = Metadata.bookauthor.downcase.gsub(/\s/,"").to_ascii
    if myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash['book']['PERSON_PARTNERID'].nil? or myhash['book']['PERSON_PARTNERID'].empty? or !myhash['book']['PERSON_PARTNERID']
      filecontents = filecontents.gsub(/\{\{AUTHORNAMETXT\}\}/,"#{linkauthornametxt}").gsub(/\{\{AUTHORNAME\}\}/,"#{linkauthornameall}")
    else
      authorid = linkauthorid.pop
      filecontents = filecontents.gsub(/\{\{AUTHORNAMETXT\}\}/,"#{linkauthornametxt}").gsub(/\{\{AUTHORNAME\}\}/,"#{linkauthornameall}").gsub(/\{\{AUTHORID\}\}/,"#{authorid}")
    end
  end
  return filecontents
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def updateImprintandEisbnPlaceholders(myhash, filecontents, logkey='')
  if myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash['book']['PERSON_PARTNERID'].nil? or myhash['book']['PERSON_PARTNERID'].empty? or !myhash['book']['PERSON_PARTNERID']
    filecontents = filecontents.gsub(/(data-displayheader="no")/,"class=\"ChapTitleNonprintingctnp\" \\1").gsub(/\{\{IMPRINT\}\}/,"#{Metadata.imprint}").gsub(/\{\{EISBN\}\}/,"#{Metadata.eisbn}")
  else
    filecontents = filecontents.gsub(/(data-displayheader="no")/,"class=\"ChapTitleNonprintingctnp\" \\1").gsub(/\{\{IMPRINT\}\}/,"#{Metadata.imprint}").gsub(/\{\{EISBN\}\}/,"#{Metadata.eisbn}").gsub(/<!--AUTHORSIGNUPSTART/,"").gsub(/AUTHORSIGNUPEND-->/,"")
  end
  return filecontents
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def addHtmlLineBreaks(filecontents, logkey='')
  filecontents = filecontents.gsub(/(<p)/,"\n\\1")
  return filecontents
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# ---------------------- PROCESSES

data_hash = readConfigJson('read_config_json')
#local definition(s) based on config.json
resource_dir = data_hash['resourcedir']

makeFolder(epub_img_dir, 'make_epub_img_dir')

# get copyrightpage html
copyrightpage = getCopyrightPage('get_copyright_page')

# Removing images subdir from src attr
# remove links from illo sources
filecontents = fixImgSrcs('fix_img_src_html')

# insert 'Begin Reading' link for books with only 1 chapter
filecontents = addBeginReading(filecontents, 'add_begin_reading_link')

#set text node contents of all Space Break paras to "* * *"
filecontents = setSpacebreakText(filecontents, 'set_spacebreak_para_text')

# Update several copyright elements for epub
filecontents = fixCopyrightforEpub(filecontents, 'fix_copyright_for_epub')

overwriteFile(epub_tmp_html, filecontents, 'overwrite_epubhtml_1')

# prep for titlepage image if needed
# convert image to jpg
# copy to image dir
prepTitlePageImage(epub_tmp_html, finalimagedir, epub_img_dir, 'prep_titlepage_image')

#set logo image based on project directory
logo_img = File.join(assets_dir, "images", resource_dir, "logo.jpg")
#copy logo image file to epub folder if no epubtitlepage found
copyLogofile(logo_img, epub_img_dir, 'copy_logo_file_if_no_epubtitlepage')

# Make EBK hyperlinks
strip_span_xsl = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "strip-spans.xsl")
addEBKhyperlinks(saxonpath, epub_tmp_html, strip_span_xsl, 'xsl-make_ebk_hyperlinks')

filecontents = readHtml(epub_tmp_html, 'read-in_epub_tmp_html_1')

# and strip manual breaks
filecontents = stripManualBreaks(filecontents, 'strip_manual_breaks')

# and combine contiguous span urls
filecontents = combineContiguousSpanUrls(filecontents, 'combine_contiguous_span_urls')

overwriteFile(epub_tmp_html, filecontents, 'overwrite_epubhtml_2')

# do content conversions
epubmakerpreprocessingjs = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "epubmaker_preprocessing.js")
localRunNode(epubmakerpreprocessingjs, epub_tmp_html, 'epubmaker_preprocessing_js')

# replace titlepage info with image IF image exists in submission dir
# js: replace titlepage innerhtml, prepend h1 w class nonprinting

# copy backad file to epub dir
# if File.file?(backad_file)
#   FileUtils.cp(backad_file, epub_img_dir)
# end

sectionjson = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "sections.json")
addonjson = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "epubmaker", "addons", "addons.json")

# move about the author to back
localMoveSection(epub_tmp_html, sectionjson, "abouttheauthor", "", "endofbook", "1", 'move_ata_to_back')

# move bobad to back
localMoveSection(epub_tmp_html, sectionjson, "bobad", "", "endofbook", "1", 'move_bobad_to_back')

# move adcard to back
localMoveSection(epub_tmp_html, sectionjson, "adcard", "", "endofbook", "1", 'move_adcard_to_back')

# move front sales to back
localMoveSection(epub_tmp_html, sectionjson, "frontsales", "", "endofbook", "1", 'move_frontsales_to_back')

# move toc to back
localMoveSection(epub_tmp_html, sectionjson, "toc", "1", "endofbook", "1", 'move_toc_to_back')

# move copyright page to back
localMoveSection(epub_tmp_html, sectionjson, "copyrightpage", "1", "endofbook", "1", 'move_copyright_to_back')

# insert extra epub content
localInsertAddons(epub_tmp_html, sectionjson, addonjson, 'insert_extra_epub_content')

# evaluate templates
localCompileJS(epub_tmp_html, 'evaluate_templates')

filecontents = readHtml(epub_tmp_html, 'read-in_epub_tmp_html_2')

# link author name to author updates webpage - need to restrict this so it only works on appendix sections
# aulink = "http://us.macmillan.com/authoralerts?authorName=#{linkauthornametxt}&amp;authorRefId=AUTHORID&amp;utm_source=ebook&amp;utm_medium=adcard&amp;utm_term=ebookreaders&amp;utm_content=#{linkauthornameall}_authoralertsignup_macdotcom&amp;utm_campaign={{EISBN}}"
# auupcase = Metadata.bookauthor.upcase
# filecontents = filecontents.gsub(Metadata.bookauthor,"<!--AUTHORSIGNUPSTART<a href=\"#{aulink}\">AUTHORSIGNUPEND-->\\0<!--AUTHORSIGNUPSTART</a>AUTHORSIGNUPEND-->").gsub(auupcase,"<!--AUTHORSIGNUPSTART<a href=\"#{aulink}\">AUTHORSIGNUPEND-->\\0<!--AUTHORSIGNUPSTART</a>AUTHORSIGNUPEND-->")

# find the author ID
myhash = databaseLookup('biblio_sql_queries')

unless myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book']
  logstring = "DB Connection SUCCESS: Found an author record"
else
  logstring = "No DB record found; removing author links for addons"
end
puts logstring
@log_hash['query_status'] = logstring

# get author info from sql if available, else scan outputtmp_html
linkauthorarr, linkauthorid = getlinkAuthorInfo(myhash, 'get_link_author_info')
@log_hash['linkauthorarr'] = linkauthorarr
@log_hash['linkauthorid'] = linkauthorid

# update newsletter author links, for single or multiple authors
filecontents = setNewsletterAuthorLinks(linkauthorarr, linkauthorid, filecontents, myhash, 'set_newsletter_auth_links')

#replace imprint, eisbn placeholders
filecontents = updateImprintandEisbnPlaceholders(myhash, filecontents, 'update_eisbn_&_imprint_placeholders')

# add some line breaks to make the html easier to deal with
filecontents = addHtmlLineBreaks(filecontents, 'add_html_line_breaks')

# write epub-ready html to file
overwriteFile(epub_tmp_html, filecontents, 'overwrite_epubhtml_final')

# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
