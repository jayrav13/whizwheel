namespace :admins do
  desc "Grant ADMIN to a user: rake 'admins:grant[username]'"
  task :grant, %i[username] => :environment do |_t, args|
    user = User.find_by!(username: User.new(username: args[:username]).username)
    admin = RoleType.find_or_create_by!(permalink: "ADMIN") { |rt| rt.display_name = "Admin" }
    user.roles.kept.find_or_create_by!(role_type: admin)
    puts "#{user.username} is now an admin"
  end

  desc "Revoke ADMIN from a user: rake 'admins:revoke[username]'"
  task :revoke, %i[username] => :environment do |_t, args|
    user = User.find_by!(username: User.new(username: args[:username]).username)
    user.roles.kept.joins(:role_type).where(role_types: { permalink: "ADMIN" }).each(&:discard)
    puts "#{user.username} is no longer an admin"
  end
end
