require 'fileutils'
# require 'nokogiri'

require_relative '../bookmaker/core/header.rb'

# These commands should run immediately prior to htmlmaker

# ---------------------- VARIABLES
local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

filetype = Bkmkr::Project.filename_split.split(".").pop

configfile = File.join(Bkmkr::Paths.project_tmp_dir, "config.json")

get_template_version_py = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "getTemplateVersion.py")

sectionstart_template_version = Bkmkr::Tools.sectionstart_template_version

rsuite_template_version = Bkmkr::Tools.rsuite_template_version

replace_wsym_py = File.join(Bkmkr::Paths.scripts_dir, "bookmaker_addons", "replace_wsym.py")

# ---------------------- METHODS

def readConfigJson(configfile, logkey='')
  data_hash = Mcmlln::Tools.readjson(configfile)
  return data_hash
rescue => logstring
  return {}
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def convertDocToDocxPSscript(filetype, logkey='')
  unless filetype == "html"
    doctodocx = "S:\\resources\\bookmaker_scripts\\bookmaker_addons\\htmlmaker_preprocessing.ps1"
    `PowerShell -NoProfile -ExecutionPolicy Bypass -Command "#{doctodocx} '#{Bkmkr::Paths.project_tmp_file}'"`
  else
    logstring = 'input file is html, skipping'
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def readHtml(htmlfile, logkey='')
	filecontents = File.read(htmlfile)
	return filecontents
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# scan for version in outputtmp.html (will return '' if no templateversion value found in hrml):
#   (this could also be done with nokogiri, cleanly, but with added dependency.. see metadata_preprocessing for ex.)
def checkHTMLforTemplateVersion(filecontents, logkey='')
  version = filecontents.scan(/<meta name="templateversion"/)
  unless version.nil? or version.empty? or !version
    templateversion = filecontents.match(/(<meta name="templateversion" content=")(.*)(" \/>)/)[2]
  else
    templateversion = ''
  end
  return templateversion
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# def checktemplate_versionHTML(htmlfile, logkey='')
#   template_version = ''
#   page = Nokogiri::HTML(open(htmlfile))
#   # get meta info from html if it exists
#   meta_templateversion = page.xpath('//meta[@name="templateversion"]/@content')
#   if !meta_templateversion.empty?
#     logstring = "template-version from meta-tag: #{meta_templateversion}"
#     template_version = meta_templateversion #HTMLEntities.new.decode(metaimprint)
#   else
#     logstring = 'no meta-tag with templateversion (or no templateversion value)'
#   end
#   return template_version
# rescue => logstring
#   return ''
# ensure
#   Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
# end

def checkDocTemplateVersion(filetype, get_template_version_py, logkey='')
  doctemplate_version = ''
  unless filetype == "html"
    # the get_template_version_py script reads custom.xml inside the .docx to return custom doc property 'Version'
    doctemplate_version = Bkmkr::Tools.runpython(get_template_version_py, "#{Bkmkr::Paths.project_docx_file}").strip()
  else
    logstring = 'input file is html, skipping'
  end
  return doctemplate_version
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# returns false if v1 is empty, nil, has bad characters, or is less than v2
def versionCompare(v1, v2, logkey='')
  # eliminate leading 'v' if present
  if v1[0] == 'v'
    v1 = v1[1..-1]
  end
  if v1.nil?
    logstring = "false: doctemplate_version is nil"
    return false
  elsif v1.empty?
    logstring = "false: doctemplate_version is empty; input .docx/html has no version, or this is a non-Macmillan bookmaker instance"
    return false
  elsif v1.match(/[^\d.]/) || v2.match(/[^\d.]/)
    logstring = "false: doctemplate_version string includes nondigit chars"
    return false
  elsif v1 == v2
    logstring = "true: doctemplate_version meets requirements for jsconvert"
    return true
  else
    v1long = v1.split('.').length
    v2long = v2.split('.').length
    maxlength = v1long > v2long ? v1long : v2long
    0.upto(maxlength-1) { |n|
      # puts "n is #{n}"  ## < debug
      v1split = v1.split('.')[n].to_i
      v2split = v2.split('.')[n].to_i
      if v1split > v2split
        logstring = "true: v1 (doctemplate_version) is greater than v2 (static version)"
        return true
      elsif v1split < v2split
        logstring = "false: v1 (doctemplate_version) is less than v2 (static version)"
        return false
      elsif n == maxlength-1 && v1split == v2split
        logstring = "true: v1 (doctemplate_version) equals v2 (static version)"
        return true
      end
    }
  end
rescue => logstring
  return true
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def replace_wsym(filetype, replace_wsym_py, wsymcode, replacementcode, logkey='')
  unless filetype == "html"
    # the replace_wsym_py script checks document.xml without unzipping the .docx. If w:sym with wsymcode is found,
    #   the w:sym element is replaced with with the decoded replacementcode in the xml, the new xml is overwritten to file,
    #   the original file is backed up, and the .docx is overwritten with edits.
    logstring = Bkmkr::Tools.runpython(replace_wsym_py, "#{Bkmkr::Paths.project_docx_file} #{wsymcode} #{replacementcode}").strip()
  else
    logstring = 'input file is html, skipping'
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def writeConfigJson(hash, json, logkey='')
  Mcmlln::Tools.write_json(hash, json)
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# ---------------------- PROCESSES
# read in config.json if it exists
prev_cfg_hash = readConfigJson(configfile, 'read_config_json')

#convert .doc to .docx via powershell script, ignore html files
convertDocToDocxPSscript(filetype, 'convert_doc_to_docx')

# if filetype is html, check for version in metatag, else...
if filetype == "html"
  # doctemplate_version = checktemplate_versionHTML(Bkmkr::Paths.project_tmp_file, 'check_docx_template_version-HTML')
  filecontents = readHtml(Bkmkr::Paths.project_tmp_file, 'read_input_html')
  doctemplate_version = checkHTMLforTemplateVersion(filecontents, 'check_html_for_doctemplate_version')
# ...get document version template number if it from .dox xml with python
else
  doctemplate_version = checkDocTemplateVersion(filetype, get_template_version_py, 'check_docx_doctemplate_version')
end
@log_hash['doctemplate_version'] = doctemplate_version

# figure out what type of doctemplate we have
# versionCompare returns false if:
#   doctemplate_version < required_version_for_jsconvert, doctemplate_version has any non-digit chars (besides '.'), is nil, or is empty
rsuite_versioncompare = versionCompare(doctemplate_version, rsuite_template_version, 'rsuite_version_compare')
if rsuite_versioncompare == true
  doctemplatetype = "rsuite"
else
  sectionstart_versioncompare = versionCompare(doctemplate_version, sectionstart_template_version, 'sectionstart_version_compare')
  if sectionstart_versioncompare == true
    doctemplatetype = "sectionstart"
  else
    doctemplatetype = "pre-sectionstart"
  end
end
@log_hash['doctemplatetype'] = doctemplatetype

# run replacements on any w:sym elements in the word xml:
# Right now, just to catch a copyright symbol variant, but for additional replacements, just run the method again with codes
#   wsymcode values can be found in the xml (value of 'w:char attribute for the w:sym'), here is a large table of these codes:
#     https://gist.github.com/ptsefton/1ce30879e9cfef289356
#   replacement code should be unicode for desired replacement symbol: http://www.fileformat.info/info/unicode/char/search.htm
#     the desired format is the 'C/C++/Java source code' including the doublequotes
replace_wsym(filetype, replace_wsym_py, 'F0D3', "\u00A9", 'replace_w:sym_copyright_symbol')

# find out if this file came from (and its output returns to) rsuite
if File.exist?(Bkmkr::Paths.api_Metadata_json)
  from_rsuite = true
else
  from_rsuite = false
end
@log_hash['from_rsuite'] = from_rsuite

# Create a temp JSON file, keeping select values from submitted config.json if present
datahash = {}
if prev_cfg_hash["title"] and prev_cfg_hash["title"] != "TK" and !prev_cfg_hash["title"].empty?
  datahash.merge!(title: prev_cfg_hash["title"])
else
  datahash.merge!(title: "TK")
end
if prev_cfg_hash["subtitle"] and prev_cfg_hash["subtitle"] != "TK" and !prev_cfg_hash["subtitle"].empty?
  datahash.merge!(subtitle: prev_cfg_hash["subtitle"])
else
  datahash.merge!(subtitle: "TK")
end
if prev_cfg_hash["author"] and prev_cfg_hash["author"] != "TK" and !prev_cfg_hash["author"].empty?
  datahash.merge!(author: prev_cfg_hash["author"])
else
  datahash.merge!(author: "TK")
end
datahash.merge!(productid: "TK")
datahash.merge!(printid: "TK")
datahash.merge!(ebookid: "TK")
if prev_cfg_hash["imprint"] and prev_cfg_hash["imprint"] != "TK" and !prev_cfg_hash["imprint"].empty?
  datahash.merge!(imprint: prev_cfg_hash["imprint"])
else
  datahash.merge!(imprint: "TK")
end
if prev_cfg_hash["publisher"] and prev_cfg_hash["publisher"] != "TK" and !prev_cfg_hash["publisher"].empty?
  datahash.merge!(publisher: prev_cfg_hash["publisher"])
else
  datahash.merge!(publisher: "TK")
end
datahash.merge!(project: "TK")
datahash.merge!(stage: "TK")
datahash.merge!(printcss: "TK")
datahash.merge!(printjs: "TK")
datahash.merge!(ebookcss: "TK")
datahash.merge!(pod_toc: "TK")
datahash.merge!(frontcover: "TK")
datahash.merge!(epubtitlepage: "TK")
datahash.merge!(podtitlepage: "TK")
datahash.merge!(doctemplate_version: doctemplate_version)
datahash.merge!(doctemplatetype: doctemplatetype)
datahash.merge!(from_rsuite: from_rsuite)

# Printing the final JSON object
writeConfigJson(datahash, configfile, 'write_config_jsonfile')

# ---------------------- LOGGING
# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
