require "test_helper"
require "rake"

class ManagementTaskTest < ActiveSupport::TestCase
  setup do
    Whizwheel::Application.load_tasks if Rake::Task.tasks.empty?
    RoleType.find_or_create_by!(permalink: "ADMIN") { |rt| rt.display_name = "Admin" }
  end

  def run_task(name, *args)
    task = Rake::Task[name]
    task.reenable
    task.invoke(*args)
  end

  test "users:create makes a user with a password" do
    run_task("users:create", "carol", "secret123")
    assert User.authenticate_by(username: "carol", password: "secret123")
  end

  test "users:set_password changes the digest" do
    User.create!(username: "dave", password: "oldpass12")
    run_task("users:set_password", "dave", "newpass12")
    assert User.authenticate_by(username: "dave", password: "newpass12")
  end

  test "admins:grant then admins:revoke toggles admin?" do
    User.create!(username: "erin", password: "secret123")
    run_task("admins:grant", "erin")
    assert User.find_by(username: "erin").admin?
    run_task("admins:revoke", "erin")
    assert_not User.find_by(username: "erin").admin?
  end
end
