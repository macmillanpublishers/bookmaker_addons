require 'fileutils'
require 'json'

require_relative '../bookmaker/core/header.rb'
require_relative '../bookmaker/core/metadata.rb'

# ---------------------- VARIABLES
json_log_hash = Bkmkr::Paths.jsonlog_hash
json_log_hash[Bkmkr::Paths.thisscript] = {}
@log_hash = json_log_hash[Bkmkr::Paths.thisscript]

project_dir = Metadata.project_dir

stage_dir = Metadata.stage_dir

# ---------------------- METHODS


# ---------------------- PROCESSES



# ---------------------- LOGGING

# Write json log:
@log_hash['completed'] = Time.now
Mcmlln::Tools.write_json(json_log_hash, Bkmkr::Paths.json_log)
