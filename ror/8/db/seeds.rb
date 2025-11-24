user = User.find_or_create_by!(email: "mihai@frombase.com") do |u|
  u.first_name = "Mihai"
  u.password = "123123"
  u.password_confirmation = "123123"
end

org = Organization.find_or_create_by!(name: "FromBase") do |o|
  o.owner = user
end

org.user_organizations.create!(user: user, role: :owner ) if org.users.exclude?(user)
