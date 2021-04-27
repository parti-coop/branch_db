require_relative '../smart_database_environment'

namespace :branchdb do
  desc "베이스 브랜치 DB를 복사하여 현재 브랜치DB를 만듭니다."
  task 'create', [:base_branch] => :environment do |_, args|
    database_environment = BranchDb::SmartDatabaseEnvironment.new
    raise "생성를 취소합니다. base_branch를 입력해 주세요." if args[:base_branch]&.strip.blank?

    puts "#{database_environment.base_database_name(args[:base_branch])}를 #{database_environment.current_database_name}에 복사합니다."

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
      puts "DB 생성에 실패했습니다. : #{$CHILD_STATUS}"
      next
    end
    puts "DB 생성했습니다. : #{database_environment.current_database_name}"

    copy_cmd = <<-HEREDOC.squish
      mysqldump
      -u#{database_environment.user_name}
      -p#{database_environment.password}
      #{database_environment.base_database_name(args[:base_branch])} |
      mysql
      -u#{database_environment.user_name}
      -p#{database_environment.password}
      #{database_environment.current_database_name}
    HEREDOC
    puts copy_cmd
    copy_result = system(copy_cmd)

    puts(copy_result ? "DB를 복사했습니다. : #{$CHILD_STATUS}" : "DB를 복사하지 못했습니다. : #{$CHILD_STATUS}")
  end

  desc '현재 브랜치DB를 삭제합니다'
  task 'drop' => :environment do
    database_environment = BranchDb::SmartDatabaseEnvironment.new
    puts "#{database_environment.current_database_name} 데이터베이스를 삭제하시겠습니까? 삭제하려면 '#{database_environment.current_database_name}'를 입력해 주세요: "
    input = STDIN.gets.chomp
    raise "삭제를 취소합니다. 입력하신 값은 #{input} 입니다." unless input == database_environment.current_database_name

    drop_cmd = <<-HEREDOC.squish
      mysql
        -u#{database_environment.user_name}
        -p#{database_environment.password}
        -e 'drop database `#{database_environment.current_database_name}`'
    HEREDOC
    created_result = system(drop_cmd)

    unless created_result
      puts "DB 삭제에 실패했습니다. : #{$CHILD_STATUS}"
      next
    end
    puts "DB 삭제했습니다. : #{database_environment.current_database_name}"
  end
end