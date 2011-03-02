require_dependency 'application_controller'

class TagsExtension < Radiant::Extension
  version "2.0.beta1"
  description "This extension enhances the page model with tagging capabilities, tagging as in \"2.0\" and tagclouds."
  url "http://gorilla-webdesign.be"  
  
  DEFAULT_RESULTS_URL = '/t'
 
  def activate
    config = Radiant::Config
    if config.table_exists?
      config['tags.results_page_url'] = config['tags.results_page_url'].presence || DEFAULT_RESULTS_URL
      config['tags.complex_strings'] = config['tags.complex_strings'].presence || false
    end
    
    Page.class_eval do
      acts_as_taggable_on :categories if respond_to? :acts_as_taggable_on

      def category_names
        categories.map &:name
      end

      alias :tag_list :category_list
      alias :tag_list= :category_list=
      
    end
    
    TagSearchPage
    Page.send :include, RadiusTags
    admin.page.edit.add :extended_metadata, 'tag_field'

    

    # HELP
    if admin.respond_to?(:help)
      admin.help.index.add :page_details, 'using_tags', :after => 'breadcrumbs'
    end
  end
  
  def deactivate
  end
end
