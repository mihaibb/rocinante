module Pagination
  extend ActiveSupport::Concern

  included do
    include Pagy::Method
  end
end
