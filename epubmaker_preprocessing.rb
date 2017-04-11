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
titlepagejs = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "epubmaker_preprocessing-titlepage.js")
newsletterjs = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "epubmaker_preprocessing-newsletterlinks.js")
newslettersinglejs = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "epubmaker_preprocessing-newsletterlinkssingle.js")

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
def fixImgSrcs(logkey='')
  filecontents = File.read(Bkmkr::Paths.outputtmp_html).gsub(/src="images\//,"src=\"")
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
def prepTitlePageImage(jsfile, htmlfile, finalimagedir, epub_img_dir, logkey='')
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
    localRunNode(jsfile, htmlfile, 'add_titlepage_attr_to_titlepage')
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

## wrapping a Mcmlln::Tools method in a new method for this script; to return a result for json_logfile
def readHtml(file, logkey='')
  filecontents = File.read(file)
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

def getlinkAuthorInfo(confighash, myhash, logkey='')
  linkauthorarr = []
  linkauthorid = []
  if myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash['book']['PERSON_REALNAME'].nil? or myhash['book']['PERSON_REALNAME'].empty? or !myhash['book']['PERSON_REALNAME']
    linkauthorarr = confighash['author'].split(", ")
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

def activateAuthorLinks(myhash, filecontents, logkey='')
  unless myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash['book']['PERSON_PARTNERID'].nil? or myhash['book']['PERSON_PARTNERID'].empty? or !myhash['book']['PERSON_PARTNERID']
    filecontents = filecontents.gsub(/<!--AUTHORSIGNUPSTART/,"").gsub(/AUTHORSIGNUPEND-->/,"")
  end
  return filecontents
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def setNewsletterAuthorLinksSingle(linkauthorarr, linkauthorid, myhash, jsfile, htmlfile, logkey='')
  # for books with just one author
  # add author link to ATA section
  filecontents = File.read(htmlfile)
  linkauthornametxt = Metadata.bookauthor.downcase.gsub(/\s/,"").gsub(/\W/,"").to_ascii
  linkauthornameall = Metadata.bookauthor.downcase.gsub(/\s/,"").to_ascii
  Bkmkr::Tools.runnode(jsfile, htmlfile)
  if myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash['book']['PERSON_PARTNERID'].nil? or myhash['book']['PERSON_PARTNERID'].empty? or !myhash['book']['PERSON_PARTNERID']
    filecontents = File.read(htmlfile).gsub(/\{\{AUTHORNAMETXT\}\}/,"#{linkauthornametxt}").gsub(/\{\{AUTHORNAME\}\}/,"#{linkauthornameall}")
  else
    authorid = linkauthorid.pop
    filecontents = File.read(htmlfile).gsub(/\{\{AUTHORNAMETXT\}\}/,"#{linkauthornametxt}").gsub(/\{\{AUTHORNAME\}\}/,"#{linkauthornameall}").gsub(/\{\{AUTHORID\}\}/,"#{authorid}")
  end
  return filecontents
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def setNewsletterAuthorLinksMultiple(linkauthorarr, linkauthorid, myhash, jsfile, htmlfile, logkey='')
  # for books with multiple authors,
  # make mini toc entry plural,
  # insert new author links in newsletter,
  # add author links to ATA sections
  filecontents = File.read(htmlfile)
  newslinkarr = []
  linkauthorarr.each_with_index do |a, i|
    linkauthorname = a
    linkauthorfirst = a.split(" ").shift
    linkauthorlast = a.split(" ").pop
    linkauthornametxt = a.downcase.gsub(/\s/,"").gsub(/\W/,"").to_ascii
    linkauthornameall = a.downcase.gsub(/\s/,"").to_ascii
    thisauthorid = linkauthorid[i]
    Bkmkr::Tools.runnode(jsfile, "\"#{htmlfile}\" \"#{linkauthorname}\" \"#{linkauthorfirst}\" \"#{linkauthorlast}\" \"#{linkauthornameall}\" \"#{linkauthornametxt}\" \"#{thisauthorid}\"")
  end
  # set newsletter button link to use first author
  linkauthornametxt = linkauthorarr[0].downcase.gsub(/\s/,"").gsub(/\W/,"").to_ascii
  linkauthornameall = linkauthorarr[0].downcase.gsub(/\s/,"").to_ascii
  authorid = linkauthorid[0]
  # we have to read the html file again to get the post-js updates
  filecontents = File.read(htmlfile).gsub(/\{\{AUTHORNAMETXT\}\}/,"#{linkauthornametxt}").gsub(/\{\{AUTHORNAME\}\}/,"#{linkauthornameall}").gsub(/\{\{AUTHORID\}\}/,"#{authorid}")
  return filecontents
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def updateImprintandEISBNPlaceholders(myhash, filecontents, logkey='')
  filecontents = filecontents.gsub(/\{\{IMPRINT\}\}/,"#{Metadata.imprint}").gsub(/\{\{EISBN\}\}/,"#{Metadata.eisbn}")
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
filecontents = fixImgSrcs('fix_img_src_html')

# prep for titlepage image if needed
# convert image to jpg
# copy to image dir

overwriteFile(epub_tmp_html, filecontents, 'overwrite_epubhtml_1')

prepTitlePageImage(titlepagejs, epub_tmp_html, finalimagedir, epub_img_dir, 'prep_titlepage_image')

#set logo image based on project directory
logo_img = File.join(assets_dir, "images", resource_dir, "logo.jpg")
#copy logo image file to epub folder if no epubtitlepage found
copyLogofile(logo_img, epub_img_dir, 'copy_logo_file_if_no_epubtitlepage')

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

# do content conversions
addonstransformationsjs = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "epubmaker_preprocessing-addonstransformations.js")
localRunNode(addonstransformationsjs, epub_tmp_html, 'running_post-addons_js_transformations')

filecontents = readHtml(epub_tmp_html, 'read_updated_epub_tmp_html')

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
linkauthorarr, linkauthorid = getlinkAuthorInfo(data_hash, myhash, 'get_author_link_info')
@log_hash['linkauthorarr'] = linkauthorarr
@log_hash['linkauthorid'] = linkauthorid

# uncomment newsletter link placeholders
filecontents = activateAuthorLinks(myhash, filecontents, 'uncomment_newsletter_links')

# write epub-ready html to file
overwriteFile(epub_tmp_html, filecontents, 'overwrite_epubhtml_final')

# update newsletter author links, for single or multiple authors
if linkauthorarr.count > 1
  filecontents = setNewsletterAuthorLinksMultiple(linkauthorarr, linkauthorid, myhash, newsletterjs, epub_tmp_html, 'set_newsletter_auth_links_multiple')
else
  filecontents = setNewsletterAuthorLinksSingle(linkauthorarr, linkauthorid, myhash, newslettersinglejs, epub_tmp_html, 'set_newsletter_auth_links_single')
end

#replace imprint, eisbn placeholders
filecontents = updateImprintandEISBNPlaceholders(myhash, filecontents, 'update_eisbn_&_imprint_placeholders')

# add some line breaks to make the html easier to deal with
filecontents = addHtmlLineBreaks(filecontents, 'add_html_line_breaks')

# write epub-ready html to file
overwriteFile(epub_tmp_html, filecontents, 'overwrite_epubhtml_final')

# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
