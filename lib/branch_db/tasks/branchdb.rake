require_relative '../smart_database_environment'

namespace :branchdb do
  desc "베이스 브랜치 DB를 복사하여 현재 브랜치DB를 만듭니다."
  task 'create' => :environment do
    database_environment = BranchDb::SmartDatabaseEnvironment.new
    puts "#{database_environment.current_branch} 브랜치에 대해 작업합니다."
    unless database_environment.creatable?
      puts "#{database_environment.database_name} 데이터베이스는 생성할 수 없습니다. 베이스 브랜치이거나 알 수 없는 패턴의 이름을 가진 브랜치입니다."
      next
    end

    create_cmd = <<-HEREDOC.squish
      mysql
        -u#{database_environment.user_name}
        -p#{database_environment.password}
        -e 'create database `#{database_environment.database_name}`
        CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci';
    HEREDOC
    puts create_cmd
    created_result = system(create_cmd)

    unless created_result
      puts "DB 생성에 실패했습니다. : #{$CHILD_STATUS}"
      next
    end
    puts "DB 생성했습니다. : #{database_environment.database_name}"

    copy_cmd = <<-HEREDOC.squish
      mysqldump
      -u#{database_environment.user_name}
      -p#{database_environment.password}
      #{database_environment.base_database_name} |
      mysql
      -u#{database_environment.user_name}
      -p#{database_environment.password}
      #{database_environment.database_name}
    HEREDOC
    puts copy_cmd
    copy_result = system(copy_cmd)

    puts(copy_result ? "DB를 복사했습니다. : #{$CHILD_STATUS}" : "DB를 복사하지 못했습니다. : #{$CHILD_STATUS}")
  end

  desc '현재 브랜치DB를 삭제합니다'
  task 'drop' => :environment do
    database_environment = BranchDb::SmartDatabaseEnvironment.new
    puts "#{database_environment.current_branch} 브랜치에 대해 작업합니다."
    unless database_environment.dropable?
      puts "#{database_environment.database_name} 데이터베이스는 삭제할 수 없습니다. 베이스 브랜치이거나 알 수 없는 패턴의 이름을 가진 브랜치입니다."
      next
    end

    drop_cmd = <<-HEREDOC.squish
      mysql
        -u#{database_environment.user_name}
        -p#{database_environment.password}
        -e 'drop database `#{database_environment.database_name}`'
    HEREDOC
    created_result = system(drop_cmd)

    unless created_result
      puts "DB 삭제에 실패했습니다. : #{$CHILD_STATUS}"
      next
    end
    puts "DB 삭제했습니다. : #{database_environment.database_name}"
  end
end