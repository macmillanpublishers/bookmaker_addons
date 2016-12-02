require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# These commands should run immediately prior to filearchive

# ---------------------- VARIABLES
json_log_hash = Bkmkr::Paths.jsonlog_hash
json_log_hash[Bkmkr::Paths.thisscript] = {}
@log_hash = json_log_hash[Bkmkr::Paths.thisscript]

# Find supplemental titlepages
finalimagedir = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "images")


# ---------------------- METHODS
def archiveTitlepageImg(titlepage, finalimagedir, logkey, logstring=true)
	if File.file?(titlepage)
		tpfilename = titlepage.split(Regexp.union(*[File::SEPARATOR, File::ALT_SEPARATOR].compact)).pop
		titlepagearc = File.join(finalimagedir, tpfilename)
		unless titlepage == titlepagearc
			FileUtils.mv(titlepage, titlepagearc)
		else
			logstring = "titlepage img is already in archival dir"
		end
	else
		logstring = "no file present"
	end
rescue => logstring
ensure
	@log_hash[logkey] = logstring
end


# ---------------------- PROCESSES

# move podtitlepage to archival dir, if it exists & is not already there
archiveTitlepageImg(Metadata.podtitlepage, finalimagedir, 'archive_podtitlepage')

# move epubtitlepage to archival dir, if it exists & is not already there
archiveTitlepageImg(Metadata.epubtitlepage, finalimagedir, 'archive_epubtitlepage')


# ---------------------- LOGGING

# Write json log:
@log_hash['completed'] = Time.now
Mcmlln::Tools.write_json(json_log_hash, Bkmkr::Paths.json_log)
