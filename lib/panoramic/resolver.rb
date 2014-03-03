module Panoramic
  class Resolver < ActionView::Resolver
    require "singleton"
    include Singleton

    def sql_template_partials=(partials)
      @sql_template_partials = partials
    end

    # if `cached` is called, multi-tenancy will be broken because another tenant's view is referenced via cache.
    def find_all(name, prefix=nil, partial=false, details={}, key=nil, locals=[])
      return [] unless @sql_template_partials.include? "#{prefix}/#{name}/#{partial ? "partial" : "non_partial"}"
      # key is ctionView::LookupContext::DetailsKey, so string can not be added to it.
      #key = "#{key}.Thread.current[:domain]"
      #cached(key, [name, prefix, partial], details, locals) do
      #return [] unless @sql_template_partials.include? "#{prefix}/#{name}/#{partial ? "partial" : "non_partial"}"
      find_templates(name, prefix, partial, details)
      #end
    end

    # this method is mandatory to implement a Resolver
    def find_templates(name, prefix, partial, details)
      return [] if @@resolver_options[:only] && !@@resolver_options[:only].include?(prefix)

      conditions = {
        :path    => build_path(name, prefix),
        :locale  => normalize_array(details[:locale]).first,
        :format  => normalize_array(details[:formats]).first,
        :handler => normalize_array(details[:handlers]),
        :partial => partial || false
      }

      @@model.find_model_templates(conditions).map do |record|
        initialize_template(record)
      end
    end

    # Instantiate Resolver by passing a model (decoupled from ORMs)
    def self.using(model, options={})
      @@model = model
      @@resolver_options = options
      self.instance
      # http://stackoverflow.com/questions/6391855/rails-cache-error-in-rails-3-1-typeerror-cant-dump-hash-with-default-proc
      # for multi-tenancy, it needs multiple instance.
      #Rails.cache.fetch(options[:cache_key]) do
        #self.new
      #end
    end

    private

    # Initialize an ActionView::Template object based on the record found.
    def initialize_template(record)
      source = record.body
      identifier = "#{record.class} - #{record.id} - #{record.path.inspect}"
      handler = ActionView::Template.registered_template_handler(record.handler)

      details = {
        :format => Mime[record.format],
        :updated_at => record.updated_at,
        :virtual_path => virtual_path(record.path, record.partial)
      }

      ActionView::Template.new(source, identifier, handler, details)
    end

    # Build path with eventual prefix
    def build_path(name, prefix)
      prefix.present? ? "#{prefix}/#{name}" : name
    end

    # Normalize array by converting all symbols to strings.
    def normalize_array(array)
      array.map(&:to_s)
    end

    # returns a path depending if its a partial or template
    def virtual_path(path, partial)
      return path unless partial
      if index = path.rindex("/")
        path.insert(index + 1, "_")
      else
        "_#{path}"
      end
    end
  end
end
