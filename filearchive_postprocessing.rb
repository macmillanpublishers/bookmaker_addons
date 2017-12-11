require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# These commands should run immediately prior to filearchive

# ---------------------- VARIABLES
local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

# Find supplemental titlepages
finalimagedir = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "images")

required_version_for_jsconvert = '4.7.0'

helpurl = 'https://confluence.macmillan.com/display/PWG/Stylecheck+Help'

# full path to the version error file
version_error = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "TEMPLATE_VERSION_ERROR.txt")


# ---------------------- METHODS

def archivePodTitlePage(finalimagedir, logkey='')
	if File.file?(Metadata.podtitlepage)
		ptpfilename = Metadata.podtitlepage.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop
		podtitlepagearc = File.join(finalimagedir, ptpfilename)
		unless Metadata.podtitlepage == podtitlepagearc
			FileUtils.mv(Metadata.podtitlepage, podtitlepagearc)
		else
			logstring = "titlepage img is already in archival dir"
		end
	else
		logstring = "no file present"
	end
rescue => logstring
ensure
Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def archiveEpubTitlePage(finalimagedir, logkey='')
	if File.file?(Metadata.epubtitlepage)
		etpfilename = Metadata.epubtitlepage.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop
		epubtitlepagearc = File.join(finalimagedir, etpfilename)
		unless Metadata.epubtitlepage == epubtitlepagearc
			FileUtils.mv(Metadata.epubtitlepage, epubtitlepagearc)
		else
			logstring = "titlepage img is already in archival dir"
		end
	else
		logstring = "no file present"
	end
rescue => logstring
ensure
Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# If a version error file exists, delete it
## wrapping a Mcmlln::Tools method in a new method for this script; to return a result for json_logfile
def checkErrorFile(file, logkey='')
	if File.file?(file)
		Mcmlln::Tools.deleteFile(file)
	else
		logstring = 'n-a'
	end
rescue => logstring
ensure
	Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def readOutputHtml(logkey='')
	filecontents = File.read(Bkmkr::Paths.outputtmp_html)
	return filecontents
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def checkHTMLforTemplateVersion(filecontents)
  version = filecontents.scan(/<meta name="templateversion"/)
  unless version.nil? or version.empty? or !version
    templateversion = filecontents.match(/(<meta name="templateversion" content=")(.*)("\/>)/)[2]
  else
    templateversion = ''
  end
  return templateversion
rescue => logstring
  return ''
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

# returns true if v1 is nil, empty, or >= v2. Otherwise returns false
def versionCompare(v1, v2, logkey='')
  if v1.nil?
    logstring = "template_version is nil; htmlmaker_preprocessing.rb may have crashed?"
    return false
  elsif v1.empty?
    logstring = "template_version is empty; input file is html or this is a non-Macmillan bookmaker instance"
    return false
  elsif v1.match(/[^\d.]/) || v2.match(/[^\d.]/)
    logstring = "template_version string includes nondigit chars: returning false."
    return false
  elsif v1 == v2
    logstring = "template_version meets requirements for jsconvert"
    return true
  else
    v1long = v1.split('.').length
    v2long = v2.split('.').length
    maxlength = v1long > v2long ? v1long : v2long
    0.upto(maxlength-1) { |n|
      puts "n is #{n}"
      v1split = v1.split('.')[n].to_i
      v2split = v2.split('.')[n].to_i
      if v1split > v2split
        logstring = "template_version meets requirements for jsconvert"
        return true
      elsif v1split < v2split
        logstring = "template_version is older than required version for jsconvert: returning false, xsl conversion"
        return false
      elsif n == maxlength-1 && v1split == v2split
        logstring = "template_version meets requirements for jsconvert"
        return true
      end
    }
  end
rescue => logstring
  return true
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end

def writeVersionErrfile(htmlmaker_js_version_test, errfile, helpurl, logkey='')
  if htmlmaker_js_version_test == false
  	File.open(errfile, 'w') do |output|
  		output.puts "This document was styled using the old Macmillan style-template."
  		output.puts "\nThe bookmaker toolchain has been updated, to generate good PDF’s and ePubs you must attach the latest template, and add Section Start styles to your document as needed."
  		output.puts "\nFor more information please go to this page: #{helpurl}"
  	end
  else
    logstring = 'n-a'
  end
rescue => logstring
ensure
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end


# ---------------------- PROCESSES

# move podtitlepage to archival dir, if it exists & is not already there
archivePodTitlePage(finalimagedir, 'archive_podtitlepage')

# move epubtitlepage to archival dir, if it exists & is not already there
archiveEpubTitlePage(finalimagedir, 'archive_epubtitlepage')

# # # moving version template alert stiuff here from htmlmaker_postprocessing.rb, b/c that script pre-exists final_dir
# delete version error file if it exists
checkErrorFile(version_error, 'delete_version_errfile')

# get template_version value from json logfile (local_log_hash is a hash of the json logfile, read in at the beginning of each script)
if local_log_hash.key?('htmlmaker_preprocessing.rb')
  template_version = local_log_hash['htmlmaker_preprocessing.rb']['template_version']
else
  filecontents = readOutputHtml('read_output_html')
  # scan for version in outputtmp.html (will return '' if no templateversion value found in hrml):
  template_version = checkHTMLforTemplateVersion(filecontents, 'check_htlm_for_template_version')
end

# versionCompare returns false if:
#   template_version <= required_version_for_jsconvert, template_version has any non-digit chars (besides '.'), is nil, or is empty
htmlmaker_js_version_test = versionCompare(template_version, required_version_for_jsconvert, 'version_compare')
@log_hash['htmlmaker_js_version_test'] = htmlmaker_js_version_test

# if version error, write file for user (and email workflows?)
writeVersionErrfile(htmlmaker_js_version_test, version_error, helpurl, 'write_errfile_as_needed')


# ---------------------- LOGGING

# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
