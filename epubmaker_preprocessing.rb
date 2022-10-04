require 'fileutils'
require 'unidecoder'
require 'htmlentities'
require 'nokogiri'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'
require_relative '../utilities/oraclequery.rb'

# These commands should run immediately prior to epubmaker

# ---------------------- VARIABLES
local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

epub_tmp_html = File.join(Bkmkr::Paths.project_tmp_dir, "epub_tmp.xhtml")
saxonpath = File.join(Bkmkr::Paths.resource_dir, "saxon", "#{Bkmkr::Tools.xslprocessor}.jar")
assets_dir = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "epubmaker")
epub_img_dir = File.join(Bkmkr::Paths.project_tmp_dir, "epubimg")
finalimagedir = File.join(Metadata.final_dir, "images")
titlepagejs = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "epubmaker_preprocessing-titlepage.js")
newsletterjs = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "epubmaker_preprocessing-newsletterlinks.js")
newslettersinglejs = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "epubmaker_preprocessing-newsletterlinkssingle.js")
add_metatag_js = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "add_metatag.js")

# full path of lookup error file
dw_lookup_errfile = File.join(Metadata.final_dir, "ISBN_LOOKUP_ERROR.txt")
testing_value_file = File.join(Bkmkr::Paths.resource_dir, "staging.txt")

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
def localCompileJS(file, link_stylename, logkey='')
  Bkmkr::Tools.compileJS(file, link_stylename)
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def isAnthology(htmlfile, logkey='')
  # get the page tree via nokogiri
  page = Nokogiri::HTML(open(htmlfile))
  # get meta info from html if it exists
  metabookformat = page.xpath('//meta[@name="template"]/@content')
  metabookformat = HTMLEntities.new.decode(metabookformat)
  if metabookformat == "anthology"
    value = true
  else
    value = false
  end
  return value
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def databaseLookup(logkey='')
  thissql = personSearchSingleKey(Metadata.eisbn, "EDITION_EAN", "Author")
  myhash, querystatus = runPeopleQuery(thissql)
  logstring = querystatus
  if querystatus == 'success' and (myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book'])
    logstring = "No DB record found; removing author links for addons"
  elsif querystatus == 'success'
    logstring = "DB Connection SUCCESS: Found an author record"
  end
  return myhash, querystatus
rescue => logstring
  return {}
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def getlinkAuthorInfo(confighash, myhash, logkey='')
  linkauthorarr = []
  linkauthorid = []
  if myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash['book']['PERSON_REALNAME'].nil? or myhash['book']['PERSON_REALNAME'].empty? or !myhash['book']['PERSON_REALNAME']
    if !confighash['author'].nil?
      linkauthorarr = confighash['author'].split(", ")
    end
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

def setNewsletterAuthorLinksSingle(linkauthorarr, linkauthorid, myhash, jsfile, htmlfile, newsletter_pstyle, logkey='')
  # for books with just one author
  # add author link to ATA section
  filecontents = File.read(htmlfile)
  linkauthornametxt = Metadata.bookauthor.downcase.gsub(/\s/,"").gsub(/\W/,"").to_ascii
  linkauthornameall = Metadata.bookauthor.downcase.gsub(/\s/,"").to_ascii
  Bkmkr::Tools.runnode(jsfile, "#{htmlfile} #{newsletter_pstyle}")
  if myhash.nil? or myhash.empty? or !myhash or myhash['book'].nil? or myhash['book'].empty? or !myhash['book'] or myhash['book']['PERSON_PARTNERID'].nil? or myhash['book']['PERSON_PARTNERID'].empty? or !myhash['book']['PERSON_PARTNERID']
    # in this case, a newsletter link with the AUTHORID is not updated and epubcheck errors. (preferableto a unwittint dead link..)
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

def setNewsletterAuthorLinksMultiple(linkauthorarr, linkauthorid, myhash, jsfile, htmlfile, newsletter_pstyle,logkey='')
  # for books with multiple authors,
  # make mini toc entry plural,
  # insert new author links in newsletter,
  # add author links to ATA sections
  filecontents = File.read(htmlfile)
  newslinkarr = []
  # fix any unhandleable characters from other encodings
  linkauthorarr.map! { |name| name.encode('UTF-8', invald: :replace, undef: :replace).to_ascii }
  linkauthorarr.each_with_index do |a, i|
    linkauthorname = a
    linkauthorfirst = a.split(" ").shift
    linkauthorlast = a.split(" ").pop
    linkauthornametxt = a.downcase.gsub(/\s/,"").gsub(/\W/,"")
    linkauthornameall = a.downcase.gsub(/\s/,"")
    thisauthorid = linkauthorid[i]
    Bkmkr::Tools.runnode(jsfile, "\"#{htmlfile}\" \"#{linkauthorname}\" \"#{linkauthorfirst}\" \"#{linkauthorlast}\" \"#{linkauthornameall}\" \"#{linkauthornametxt}\" \"#{thisauthorid}\" \"#{newsletter_pstyle}\"")
  end
  # set newsletter button link to use first author
  linkauthornametxt = linkauthorarr[0].downcase.gsub(/\s/,"").gsub(/\W/,"")
  linkauthornameall = linkauthorarr[0].downcase.gsub(/\s/,"")
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

def handleSqlQueryError(querystatus, data_hash, dw_lookup_errfile, testing_value_file, logkey='')
  # write errfile
  msg = "Data warehouse lookup for ISBN encountered errors. \n"
  msg += "Customizations based on imprint may be missing (logo(s), custom formatting from CSS, newsletter links, etc)"
  msg += "\n \n(detailed output:)\n "
  msg += querystatus
  Mcmlln::Tools.overwriteFile(dw_lookup_errfile, msg)
  logstring = "not the first sql err this run, (re)wrote err textfile"

  # if this is the first dw lookup failure on this run, write to cfg.json & send email alert
  if !data_hash.has_key?('dw_sql_err')
    data_hash['dw_sql_err'] = querystatus
    Mcmlln::Tools.write_json(data_hash, Metadata.configfile)
    # send mail
    Mcmlln::Tools.sendAlertMailtoWF('dw_isbn_lookup', msg, testing_value_file, Bkmkr::Project.filename_normalized, Bkmkr::Keys.smtp_address)
    logstring = "sql err, first this run; logging to cfg.json and sending alert-mail"
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# ---------------------- PROCESSES

data_hash = readConfigJson('read_config_json')
#local definition(s) based on config.json
resource_dir = data_hash['resourcedir']
doctemplatetype = data_hash['doctemplatetype']
stage_dir = data_hash['stage']
project_name = data_hash['project']
if stage_dir.include?("egalley") || stage_dir.include?("galley") || stage_dir.include?("firstpass") || \
  (project_name == 'validator' && stage_dir == 'direct')
  galley_run = true
else
  galley_run = false
end
# set bookmaker_assets path based on presence of rsuite styles
if doctemplatetype == "rsuite"
  hyperlink_cs = "Hyperlink"
  newsletter_pstyle = "Body-TextTx"
else
  hyperlink_cs = "spanhyperlinkurl"
  newsletter_pstyle = "BMTextbmtx"
end


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
localRunNode(epubmakerpreprocessingjs, "#{epub_tmp_html} #{doctemplatetype}", 'epubmaker_preprocessing_js')

# replace titlepage info with image IF image exists in submission dir
# js: replace titlepage innerhtml, prepend h1 w class nonprinting

# copy backad file to epub dir
# if File.file?(backad_file)
#   FileUtils.cp(backad_file, epub_img_dir)
# end

sectionjson = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_assets", "sections.json")
addonjson = File.join(assets_dir, "addons", "addons.json")

# anthologies need some custom handling
anthology = isAnthology(epub_tmp_html, 'isAnthology')

# move sections to the back, per ebooks SOP
# note that the order in which these moves occur is IMPORTANT

# New note: 5/5/20: preserving existing frontmatter ordering for galley runs (except TOC & copyright)
if galley_run == false
  unless anthology == true
    # move about the author to back
    localMoveSection(epub_tmp_html, sectionjson, "abouttheauthor", "", "endofbook", "1", 'move_ata_to_back')
  end

  unless anthology == true
    # move bobad to back
    localMoveSection(epub_tmp_html, sectionjson, "bobad", "", "endofbook", "1", 'move_bobad_to_back')
  end

  unless anthology == true
    # move adcard to back
    localMoveSection(epub_tmp_html, sectionjson, "adcard", "", "endofbook", "1", 'move_adcard_to_back')
  end

  # move front sales to back
  localMoveSection(epub_tmp_html, sectionjson, "frontsales", "", "endofbook", "1", 'move_frontsales_to_back')
end

# move toc to back
localMoveSection(epub_tmp_html, sectionjson, "toc", "1", "endofbook", "1", 'move_toc_to_back')

# move copyright page to back
localMoveSection(epub_tmp_html, sectionjson, "copyrightpage", "1", "endofbook", "1", 'move_copyright_to_back')

# insert extra epub content
localInsertAddons(epub_tmp_html, sectionjson, addonjson, 'insert_extra_epub_content')

# evaluate templates
localCompileJS(epub_tmp_html, hyperlink_cs, 'evaluate_templates')

# do content conversions
addonstransformationsjs = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "epubmaker_preprocessing-addonstransformations.js")
localRunNode(addonstransformationsjs, epub_tmp_html, 'running_post-addons_js_transformations')

filecontents = readHtml(epub_tmp_html, 'read_updated_epub_tmp_html')

# link author name to author updates webpage - need to restrict this so it only works on appendix sections
# aulink = "http://us.macmillan.com/authoralerts?authorName=#{linkauthornametxt}&amp;authorRefId=AUTHORID&amp;utm_source=ebook&amp;utm_medium=adcard&amp;utm_term=ebookreaders&amp;utm_content=#{linkauthornameall}_authoralertsignup_macdotcom&amp;utm_campaign={{EISBN}}"
# auupcase = Metadata.bookauthor.upcase
# filecontents = filecontents.gsub(Metadata.bookauthor,"<!--AUTHORSIGNUPSTART<a href=\"#{aulink}\">AUTHORSIGNUPEND-->\\0<!--AUTHORSIGNUPSTART</a>AUTHORSIGNUPEND-->").gsub(auupcase,"<!--AUTHORSIGNUPSTART<a href=\"#{aulink}\">AUTHORSIGNUPEND-->\\0<!--AUTHORSIGNUPSTART</a>AUTHORSIGNUPEND-->")

# find the author ID
myhash, querystatus = databaseLookup('biblio_sql_queries')

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
  filecontents = setNewsletterAuthorLinksMultiple(linkauthorarr, linkauthorid, myhash, newsletterjs, epub_tmp_html, newsletter_pstyle, 'set_newsletter_auth_links_multiple')
else
  filecontents = setNewsletterAuthorLinksSingle(linkauthorarr, linkauthorid, myhash, newslettersinglejs, epub_tmp_html, newsletter_pstyle, 'set_newsletter_auth_links_single')
end

#replace imprint, eisbn placeholders
filecontents = updateImprintandEISBNPlaceholders(myhash, filecontents, 'update_eisbn_&_imprint_placeholders')

# add some line breaks to make the html easier to deal with
filecontents = addHtmlLineBreaks(filecontents, 'add_html_line_breaks')

# write epub-ready html to file
overwriteFile(epub_tmp_html, filecontents, 'overwrite_epubhtml_final')

# write pub-indentifier metatag
if galley_run == true
  localRunNode(add_metatag_js, "#{epub_tmp_html} \"pub-identifier\" \"#{Metadata.pisbn}\"", "add_pub-identifier_meta_tag")
else
  localRunNode(add_metatag_js, "#{epub_tmp_html} \"pub-identifier\" \"#{Metadata.eisbn}\"", "add_pub-identifier_meta_tag")
end
# write rights metatag
localRunNode(add_metatag_js, "#{epub_tmp_html} \"rights\" \"All rights reserved\"", "add_rights_meta_tag")

if querystatus != 'success'
  handleSqlQueryError(querystatus, data_hash, dw_lookup_errfile, testing_value_file, 'handle_sql_query_err')
end

# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
