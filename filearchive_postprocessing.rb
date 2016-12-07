require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# These commands should run immediately prior to filearchive

# ---------------------- VARIABLES
local_log_hash, @log_hash = Bkmkr::Paths.setLocalLoghash

# Find supplemental titlepages
finalimagedir = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "images")


# ---------------------- METHODS
def archiveTitlepageImg(titlepage, finalimagedir, logkey='')
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
  Mcmlln::Tools.logtoJson(@log_hash, logkey, logstring)
end


# ---------------------- PROCESSES

# move podtitlepage to archival dir, if it exists & is not already there
archiveTitlepageImg(Metadata.podtitlepage, finalimagedir, 'archive_podtitlepage')

# move epubtitlepage to archival dir, if it exists & is not already there
archiveTitlepageImg(Metadata.epubtitlepage, finalimagedir, 'archive_epubtitlepage')


# ---------------------- LOGGING

# Write json log:
Mcmlln::Tools.logtoJson(@log_hash, 'completed', Time.now)
Mcmlln::Tools.write_json(local_log_hash, Bkmkr::Paths.json_log)
