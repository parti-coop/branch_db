module BranchDb
  class SmartDatabaseEnvironment
    attr_reader :all_base_branches

    def initialize
      @all_base_branches = all_base_branch
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

    def port
      @port ||= config_env.dig('database', 'port')
    end

    def database_name
      return @database_name if @database_name.present?

      @database_name = current_database_name

      if current_database_name == base_database_name || git_changes_count > 0 || exists_database?(current_database_name)
        return @database_name
      end

      if git_diffs_count(base_branch) <= 0
        @database_name = base_database_name
      end

      @database_name
    end

    def current_database_name
      @current_database_name ||= branch_database_name(current_branch)
    end

    def base_database_name
      @base_database_name ||= branch_database_name(base_branch)
    end

    def branch_database_name(branch)
      return if branch&.strip.blank?
      "#{database_name_prefix}_#{Rails.env}_#{normalize_to_database_name(branch)}"
    end

    def database_name_prefix
      (config['database_name_prefix'] || %x[basename -s .git `git config --get remote.origin.url`])&.strip
    end

    def current_branch
      @current_branch ||= %x[git rev-parse --abbrev-ref HEAD].strip
    end

    def base_branch
      @base_branch if @base_branch.present?

      if all_base_branches.include?(current_branch)
        @base_branch = current_branch
        return @base_branch
      end

      @base_branch = near_base_branch
      @base_branch
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

    def git_diffs_count(branch)
      %x[git diff --cached #{branch} --name-only -- #{Rails.root}/db | wc -l].strip&.to_i || 0
    end

    def exists_database?(database_name)
      0 < (%x[mysql -uroot -pzmKL4oue/6R4 --skip-column-names --batch -e "SHOW DATABASES LIKE '#{database_name}'" | wc -l].strip&.to_i || 0)
    end

    def all_base_branch
      %x[git for-each-ref --format='%(refname:short)' refs/heads/ | grep -v '/'].split.compact
      # 0 < %x[git show-ref refs/heads/#{branch} | wc -l"].strip&.to_i || 0
    end

    def git_all_branches
      %x[git for-each-ref --format='%(refname:short)' refs/heads].strip.split
    end

    def near_base_branch
      %x[git show-branch -a 2>/dev/null | grep '\*' | grep -E 'master|production|staging' | grep -v #{current_branch} | head -n1 | sed 's/.*\\[\\(.*\\)\\].*/\\1/' | sed 's/[\\^~].*//']&.strip
    end
  end
end
