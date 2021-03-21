module BranchDb
  class SmartDatabaseEnvironment
    def initialize
      Rails.logger.debug("Use database #{database_name}")
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

    def database_name
      @database_name ||= "#{config['database_name_prefix']}_#{Rails.env}_#{normalize_to_database_name(database_branch)}"
    end

    def base_database_name
      @base_database_name ||= "#{config['database_name_prefix']}_#{Rails.env}_#{normalize_to_database_name(base_branch)}"
    end

    def creatable?
      !untouchable?
    end

    def dropable?
      !untouchable?
    end

    def current_branch
      @current_branch ||= %x[git rev-parse --abbrev-ref HEAD].strip
    end

    #private

    def untouchable?
      predefined_base_branch?(current_branch) || !predefined_base_branch?(base_branch)
    end

    def normalize_to_database_name(name)
      name.to_s.gsub(/[\/.]/, '_')&.strip
    end

    def config
      @config ||= YAML.load_file("#{Rails.root}/local_env.yml") || {}
    end

    def config_env
      @config_env ||= config.dig(Rails.env) || {}
    end

    def predefined_base_branch_map
      return @predefined_base_branch_map if @predefined_base_branch_map

      @predefined_base_branch_map = {
        production: /hotfix\//,
        master: /feature\//,
        main: /feature\//,
        staging: nil,
      }.merge(config['base_branch_map'].presence || {})
    end

    def predefined_base_branch_candidates
      @predefined_base_branch_candidates ||= predefined_base_branch_map.select do |_, regx|
        current_branch =~ regx
      end.keys || []
    end

    def base_branch
      return @base_branch if @base_branch.present?

      @base_branch = current_branch
      return @base_branch if predefined_base_branch?(current_branch)

      predefined_base_branch_candidates.each do |base_branch_candidate|
        base_branch_candidate_count = %x[git branch --list #{base_branch_candidate} | wc -l].strip&.to_i || 0
        if base_branch_candidate_count > 0
          @base_branch = base_branch_candidate
          return @base_branch
        end
      end

      @base_branch
    end

    def predefined_base_branch?(branch)
      predefined_base_branch_map.keys.include?(branch)
    end

    def database_branch
      return @database_branch if @database_branch.present?

      @database_branch = current_branch
      return @base_branch if predefined_base_branch?(current_branch)

      if git_changes_count <= 0 && git_diffs_count(base_branch) <= 0
        @database_branch = base_branch
      end
      @database_branch
    end

    def git_changes_count
      %x[git ls-files -mo --exclude-standard -- #{Rails.root}/db | wc -l].strip&.to_i || 0
    end

    def git_diffs_count(base_branch)
      %x[git diff --cached #{base_branch} --name-only -- #{Rails.root}/db | wc -l].strip&.to_i || 0
    end
  end
end
