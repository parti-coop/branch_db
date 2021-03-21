# frozen_string_literal: true

require_relative "branch_db/version"
require_relative "branch_db/smart_database_environment.rb"

if defined?(Rails)
  module BranchDb
    require 'branch_db/railtie'

    def version
      Gem::Specification.find_by_name('translation').version.to_s
    end
  end
end