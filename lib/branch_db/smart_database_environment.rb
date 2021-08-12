module BranchDb
  class SmartDatabaseEnvironment
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

      exists_current_database = exists_database?(current_database_name)
      if !exists_current_database && ARGV.any? { |arg| arg&.start_with?('db:') }
        raise "현재 브랜치에 맞는 데이터베이스 #{current_database_name}가 필요합니다. rails branchdb:create를 실행해 주세요."
      end
      if !exists_current_database && !exists_database?(base_database_name)
        raise "기본 데이터베이스 #{base_database_name}가 필요합니다. #{base_database_name}를 만들고 실서버에서 데이터를 복사해 주세요."
      end

      @database_name = if exists_current_database
        puts "database_name: #{@database_name} (current)"
        current_database_name
      else
        puts "database_name: #{@database_name} (base)"
        base_database_name
      end

      @database_name
    end

    def current_database_name
      @current_database_name ||= branch_database_name(current_branch)
    end

    def base_database_name
      "#{database_name_prefix}_base"
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
      return @base_branch if @base_branch.present?

      @base_branch = if current_branch.start_with?('hotfix/') && all_base_branches.include?('production')
        'production'
      elsif all_base_branches.include?('main')
        'main'
      else
        'master'
      end
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

    def git_db_modification_count
      git_diffs_count(base_branch) + git_changes_count
    end

    def git_changes_count
      %x[git ls-files -mo --exclude-standard -- #{Rails.root}/db | wc -l].strip&.to_i || 0
    end

    def git_diffs_count(branch)
      %x[git diff --cached #{branch} --name-only -- #{Rails.root}/db | wc -l].strip&.to_i || 0
    end

    def exists_database?(database_name)
      0 < (%x[MYSQL_PWD=#{password} mysql -u#{user_name} -h #{host} --skip-column-names --batch -e "SHOW DATABASES LIKE '#{database_name}'" | wc -l].strip&.to_i || 0)
    end

    def all_base_branches
      @all_base_branches ||= %x[git for-each-ref --format='%(refname:short)' refs/heads/ | grep -v '/'].split.compact.select do |branch|
        exists_database?(branch_database_name(branch)) || %[main master].include?(branch)
      end.compact
      # 0 < %x[git show-ref refs/heads/#{branch} | wc -l"].strip&.to_i || 0
    end

    def git_all_branches
      %x[git for-each-ref --format='%(refname:short)' refs/heads].strip.split
    end
  end
end
