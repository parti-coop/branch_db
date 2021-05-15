require_relative '../smart_database_environment'

namespace :branchdb do
  desc "베이스 브랜치 DB를 복사하여 현재 브랜치DB를 만듭니다."
  task 'create' do
    database_environment = BranchDb::SmartDatabaseEnvironment.new

    puts "#{database_environment.base_database_name}를 #{database_environment.current_database_name}에 복사합니다."

    if database_environment.exists_database?(database_environment.current_database_name)
      puts "#{database_environment.current_database_name}가 이미 존재합니다."
      next
    end

    create_cmd = <<-HEREDOC.squish
      mysql
        -u#{database_environment.user_name}
        -p#{database_environment.password}
        -e 'create database `#{database_environment.current_database_name}`
        CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci';
    HEREDOC
    puts create_cmd
    created_result = system(create_cmd)

    unless created_result
      raise "DB 생성에 실패했습니다. : #{$CHILD_STATUS}"
    end
    puts "DB 생성했습니다. : #{database_environment.current_database_name}"

    copy_cmd = <<-HEREDOC.squish
      mysqldump
      -u#{database_environment.user_name}
      -p#{database_environment.password}
      --max_allowed_packet=512M
      #{database_environment.base_database_name} |
      mysql
      -u#{database_environment.user_name}
      -p#{database_environment.password}
      --max_allowed_packet=512M
      #{database_environment.current_database_name}
    HEREDOC
    puts copy_cmd
    copy_result = system(copy_cmd)

    puts(copy_result ? "DB를 복사했습니다. : #{$CHILD_STATUS}" : "DB를 복사하지 못했습니다. : #{$CHILD_STATUS}")
  end

  desc '특정 브랜치DB를 삭제합니다'
  task 'drop', [:target_branch] => :environment do |_, args|
    database_environment = BranchDb::SmartDatabaseEnvironment.new

    target_database_name = if args[:target_branch].blank?
      database_environment.current_database_name
    else
      database_environment.branch_database_name(args[:target_branch])
    end

    unless database_environment.exists_database?(target_database_name)
      puts "#{database_environment.current_database_name}가 이미 존재하지 않습니다."
      next
    end

    drop_branch(database_environment, target_database_name)
  end

  desc '모든 브랜치DB를 표시하고 존재하지 않는 브랜치는 삭제합니다'
  task 'prune' => :environment do
    database_environment = BranchDb::SmartDatabaseEnvironment.new

    git_all_branches = database_environment.git_all_branches

    list_cmd = <<-HEREDOC.squish
      mysql
        -u#{database_environment.user_name}
        -p#{database_environment.password}
        -e "show databases like '#{database_environment.branch_database_name('%')}'" -N -B
    HEREDOC
    puts list_cmd

    %x[#{list_cmd}].split.compact.select do |current_database_name|
      !git_all_branches.any? do |branche_name|
        database_environment.branch_database_name(branche_name) == current_database_name
      end
    end.each do |target_database_name|
      drop_branch(database_environment, target_database_name)
    end
  end

  def drop_branch(database_environment, target_database_name)
    puts "#{target_database_name} 데이터베이스를 삭제하시겠습니까? 삭제하려면 '#{target_database_name}'를 입력해 주세요: "
    input = STDIN.gets.chomp
    raise "삭제를 취소합니다. 입력하신 값은 #{input} 입니다." unless input == target_database_name

    drop_cmd = <<-HEREDOC.squish
      mysql
        -u#{database_environment.user_name}
        -p#{database_environment.password}
        -e 'drop database `#{target_database_name}`'
    HEREDOC
    drop_result = system(drop_cmd)

    if drop_result
      puts "DB 삭제했습니다. : #{target_database_name}"
    else
      raise "DB 삭제에 실패했습니다. : #{$CHILD_STATUS}"
    end
  end
end