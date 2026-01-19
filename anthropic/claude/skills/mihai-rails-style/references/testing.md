# Testing - Mihai Rails Style

<minitest>
## Minitest, Not RSpec

Rails default is good enough. Don't add complexity.

```ruby
class ClientTest < ActiveSupport::TestCase
  test "client requires name" do
    client = Client.new(organization: organizations(:one))

    assert_not client.valid?
    assert_includes client.errors[:name], I18n.t("errors.messages.blank")
  end

  test "client requires unique slug within organization" do
    existing = clients(:one)
    client = Client.new(
      organization: existing.organization,
      name: "New Client",
      slug: existing.slug
    )

    assert_not client.valid?
    assert_includes client.errors[:slug], I18n.t("errors.messages.taken")
  end
end
```
</minitest>

<i18n_assertions>
## I18n in Error Assertions

Always use I18n for error message assertions. Never hardcode strings.

```ruby
# Good - locale independent
assert_includes errors[:name], I18n.t("errors.messages.blank")
assert_includes errors[:slug], I18n.t("errors.messages.taken")
assert_includes errors[:email], I18n.t("errors.messages.invalid")
assert_includes errors[:organization], I18n.t("activerecord.errors.messages.required")

# Bad - hardcoded (breaks with different locale)
assert_includes errors[:name], "can't be blank"
assert_includes errors[:name], "nu poate fi necompletat"
```

Common I18n keys:
- `errors.messages.blank` - presence validation
- `errors.messages.taken` - uniqueness validation
- `errors.messages.invalid` - format validation
- `activerecord.errors.messages.required` - association presence
</i18n_assertions>

<fixtures>
## Fixtures Over Factories

Use YAML fixtures. They're simple, fast, and Rails-native.

```yaml
# test/fixtures/clients.yml
one:
  organization: one
  name: Acme Corp
  slug: acme-corp
  email: contact@acme.com

two:
  organization: one
  name: Beta Inc
  slug: beta-inc
```

```yaml
# test/fixtures/organizations.yml
one:
  name: Test Organization
  slug: test-org
```

Access in tests:
```ruby
test "something with client" do
  client = clients(:one)
  organization = organizations(:one)

  assert_equal organization, client.organization
end
```
</fixtures>

<test_structure>
## Test Structure

Follow Arrange-Act-Assert pattern:

```ruby
test "client can be archived" do
  # Arrange
  client = clients(:one)

  # Act
  client.archive!

  # Assert
  assert client.archived?
  assert_not_nil client.archived_at
end
```

One assertion concept per test (multiple related asserts are fine):

```ruby
test "archiving sets archived_at and changes status" do
  client = clients(:one)

  client.archive!

  assert client.status_archived?
  assert_not_nil client.archived_at
end
```
</test_structure>

<controller_tests>
## Controller Tests

Test HTTP responses, redirects, and flash messages:

```ruby
class ClientsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = organizations(:one)
    @user = users(:one)
    sign_in(@user)
    set_organization(@organization)
  end

  test "should create client" do
    assert_difference("Client.count") do
      post clients_path, params: {
        client: { name: "New Client", email: "new@example.com" }
      }
    end

    assert_redirected_to client_path(Client.last)
    assert_equal I18n.t("clients.create.created"), flash[:notice]
  end

  test "should not create invalid client" do
    assert_no_difference("Client.count") do
      post clients_path, params: { client: { name: "" } }
    end

    assert_response :unprocessable_entity
  end
end
```
</controller_tests>

<testing_enums>
## Testing Enums

Test enum validation with ArgumentError:

```ruby
test "status must be valid enum value" do
  assert_raises(ArgumentError) do
    Client.new(status: "invalid_status")
  end
end

test "status_active scope returns only active clients" do
  active_clients = Client.status_active

  assert active_clients.all? { |c| c.status == "active" }
end
```
</testing_enums>

<setup_helpers>
## Setup and Helpers

Use setup for common test preparation:

```ruby
class ClientTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:one)
    @client = clients(:one)
  end

  test "something" do
    # @organization and @client available
  end
end
```

Extract common assertions to helpers:

```ruby
# test/test_helper.rb
class ActiveSupport::TestCase
  def assert_validation_error(record, attribute, message_key)
    assert_not record.valid?
    assert_includes record.errors[attribute], I18n.t(message_key)
  end
end
```
</setup_helpers>
