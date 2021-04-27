module BranchDb
  class SmartDatabaseEnvironment
    def initialize
      Rails.logger.debug("Use database #{current_database_name}")
    end

    def user_name
      @username ||= config_env.dig('database', 'username')
    end

    def password
      @password ||= config_env.dig('database', 'password')
    end

    def host
      @host ||= config_env.dig('database', 'host').presence || 'localhost'
    end

    def current_database_name
      @current_database_name ||= "#{config['database_name_prefix']}_#{Rails.env}_#{normalize_to_database_name(current_branch)}"
    end
    alias_method :database_name, :current_database_name

    def base_database_name(base_branch)
      @base_database_name ||= "#{config['database_name_prefix']}_#{Rails.env}_#{normalize_to_database_name(base_branch)}"
    end

    def current_branch
      @current_branch ||= %x[git rev-parse --abbrev-ref HEAD].strip
    end

    #private

    def normalize_to_database_name(name)
      name.to_s.gsub(/[\/.]/, '_')&.strip
    end

    def config
      @config ||= YAML.load_file("#{Rails.root}/local_env.yml") || {}
    end

    def config_env
      @config_env ||= config.dig(Rails.env) || {}
    end

    def git_changes_count
      %x[git ls-files -mo --exclude-standard -- #{Rails.root}/db | wc -l].strip&.to_i || 0
    end

    def git_diffs_count(base_branch)
      %x[git diff --cached #{base_branch} --name-only -- #{Rails.root}/db | wc -l].strip&.to_i || 0
    end
  end
end
