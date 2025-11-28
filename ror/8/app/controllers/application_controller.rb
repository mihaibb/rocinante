class ApplicationController < ActionController::Base
  include Authentication
  include Pagy::Method

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # allow_browser versions: :modern

  before_action :set_current_organization

  private

  def current_user
    Current.user
  end

  impersonates :user

  def set_current_organization
    Current.organization = Current.user.organizations.find_by!(slug: params.require(:org_slug))
  end
end
