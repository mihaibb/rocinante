class MarketingController < ApplicationController
  allow_unauthenticated_access

  skip_before_action :set_current_organization

  layout "marketing"

  def index
    redirect_to home_path(org_slug: Current.user.organizations.first.slug) if authenticated?
  end
end
