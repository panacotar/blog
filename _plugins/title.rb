# frozen_string_literal: true

module Jekyll
  module Utils # :nodoc:
    def titleize_slug(slug)
      slug.split(/[_-]/).join(' ').capitalize
    end
  end
end
