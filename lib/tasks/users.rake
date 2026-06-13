namespace :users do
  desc "Create a user: rake 'users:create[username,password]'"
  task :create, %i[username password] => :environment do |_t, args|
    user = User.create!(username: args[:username], password: args[:password])
    puts "Created user ##{user.id} (#{user.username})"
  end

  desc "Set a user's password: rake 'users:set_password[username,password]'"
  task :set_password, %i[username password] => :environment do |_t, args|
    user = User.find_by!(username: User.new(username: args[:username]).username)
    user.update!(password: args[:password])
    puts "Updated password for #{user.username}"
  end
end
