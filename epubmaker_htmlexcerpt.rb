require 'fileutils'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# ---------------------- VARIABLES

data_hash = Mcmlln::Tools.readjson(Metadata.configfile)

OEBPS_dir = File.join(Bkmkr::Paths.project_tmp_dir, "OEBPS")

firstchap = File.join(OEBPS_dir, "ch01.html")

excerptfile = File.join(Bkmkr::Paths.done_dir, Metadata.pisbn, "#{Metadata.pisbn}_ExcerptFirstPassHTML.html")

# ---------------------- METHODS

# ---------------------- PROCESSES

if Mcmlln::Tools.checkFileExist(firstchap)
  Mcmlln::Tools.copyFile(firstchap, excerptfile)
end