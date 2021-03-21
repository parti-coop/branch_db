require 'branch_db'
require 'rails'

if defined?(Rails)
  module MyGem
    class Railtie < Rails::Railtie
      railtie_name :branch_db

      rake_tasks do
        path = File.expand_path(__dir__)
        Dir.glob("#{path}/tasks/**/*.rake").each { |f| load f }
      end
    end
  end
end