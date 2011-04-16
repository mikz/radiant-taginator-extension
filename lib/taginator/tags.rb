module Taginator::Tags
  include Radiant::Taggable
  include ActionView::Helpers::TextHelper
  
  class TagError < StandardError; end
  
  desc %{
    Expands if a <pre><r:tagged with="" /></pre> call would return items. Takes the same options as the 'tagged' tag.
    The <pre><r:unless_tagged with="" /></pre> is also available.
  }
  tag 'if_tagged' do |tag|
    if tag.attr[:with]
      tag.locals.tagged_results = find_with_tag_options(tag)
      tag.expand unless tag.locals.tagged_results.empty?
    else
      tag.expand unless tag.locals.page.tag_list.empty?
    end
  end
  
  tag 'unless_tagged' do |tag|
    if tag.attr[:with]
      tag.expand if find_with_tag_options(tag).empty?
    else
      tag.expand if tag.locals.page.tag_list.empty?
    end
  end
  
  desc %{
    Find all pages with certain tags, within in an optional scope. Additionally, you may set with_any to true to select pages that have any of the listed tags (opposed to all listed tags which is the provided default).
    
    *Usage:*
    <pre><code><r:tagged with="shoes diesel" [scope="/fashion/cult-update"] [with_any="true"] [offset="number"] [limit="number"] [by="attribute"] [order="asc|desc"]>...</r:tagged></code></pre>
  }
  tag 'tagged' do |tag|
    tag.attr[:exclude_id] ||= tag.locals.page.id
    tag.locals.tagged_results ||= find_with_tag_options(tag)

    tag.locals.tagged_results.map do |page|
      tag.locals.page = page
      tag.expand
    end
  end
  
  desc %{
    Find all pages related to the current page, based on all or any of the current page's tags. A scope attribute may be given to limit results to a certain site area.
    
    *Usage:*
    <pre><code><r:related_by_tags [scope="/fashion/cult-update"] [offset="number"] [limit="number"] [by="attribute"] [order="asc|desc"]>...</r:related_by_tags></code></pre>
  }
  tag "related_by_tags" do |tag|
    options = tag.attr.slice(:offset, :limit, :order).symbolize_keys
    results = tag.locals.page.find_related_on_categories(options).to_a
    return if results.size < 1
    
    if scope = tag.attr[:scope].presence
      results.reject! {|page| not page.url.starts_with?(scope) }
    end

    results.map do |page|
      tag.locals.page = page
      tag.locals.first = results.first == page
      tag.expand
    end
  end
  
  tag "if_has_related_by_tags" do |tag|
    options = tag.attr.slice(:offset, :limit, :order).symbolize_keys
    results = tag.locals.page.find_related_on_categories(options)
    tag.expand if results.size > 0
  end
  
  tag "related_by_tags:if_first" do |tag|
    tag.expand if tag.locals.first
  end
  
  desc %{
    Render a Tag cloud
    The results_page attribute will default to #{Radiant::Config['tags.results_page_url']}
     * :start_at   - Restrict the tags to those created after a certain time
     * :end_at     - Restrict the tags to those created before a certain time
     * :conditions - A piece of SQL conditions to add to the query
     * :limit      - The maximum number of tags to return
     * :order      - A piece of SQL to order by. Eg 'tags.count desc' or 'taggings.created_at desc'
     * :at_least   - Exclude tags with a frequency less than the given value
     * :at_most    - Exclude tags with a frequency greater than the given value
    *Usage:*
    <pre><code><r:tag_cloud_list [limit="number"] [results_page="/some/url"] [scope="/some/url"]/></code></pre>
  }
  tag "tag_cloud" do |tag|
    options = tag.attr.except(:scope, :results_page).symbolize_keys
    tags = tag.locals.page.class.tag_counts_on(:categories, options)
    
    tags = filter_tags_to_url_scope(tags, tag.attr['scope']) unless tag.attr['scope'].nil?
    
    content_tag :ol, :class => :tag_cloud do
      if tags.length > 0
        build_tag_cloud(tags, %w(size1 size2 size3 size4 size5 size6 size7 size8 size9)) do |t, cloud_class, amount|
          puts t, cloud_class, amount
          content_tag :li, :class => cloud_class do 
            content_tag(:span, pluralize(amount, 'page is', 'pages are') << ' tagged with ') +
            link_to(t, results_page(tag) << t, :class => :tag)
          end
        end
      else
        return "<p>No tags found.</p>"
      end
    end
  end
 
  desc %{
    Render a Tag list, more for 'categories'-ish usage, i.e.: Cats (2) Logs (1) ...
    The results_page attribute will default to #{Radiant::Config['tags.results_page_url']}
    
    *Usage:*
    <pre><code><r:tag_cloud_list [results_page="/some/url"] [scope="/some/url"]/></code></pre>
  }
  tag "tag_cloud_list" do |tag|
    options = {}
    tags = tag.locals.page.class.all_tag_counts(options).order('count desc')
    tags = filter_tags_to_url_scope(tags, tag.attr[:scope]) unless tag.attr[:scope].nil?
    
    results_page = tag.attr[:results_page] || Radiant::Config['tags.results_page_url']

    content_tag :ul, :class => :tag_list do
      if tags.length > 0
        build_tag_cloud(tags, %w(size1 size2 size3 size4 size5 size6 size7 size8 size9)) do |t, cloud_class, amount|
          content_tag :li, :class => cloud_class do
            link_to("#{t} (#{amount})", results_page(tag) << t, :class => :tag)
          end
        end
      else
        return "<p>No tags found.</p>"
      end
    end
  end
 
  desc "List the current page's tags"
  tag "tag_list" do |tag|
    tag.locals.page.tag_list.map{|t| link_to(t, results_page(tag) << t, :class => :tag)}.join(", ")
  end
  
  desc "List the current page's tagsi as technorati tags. this should be included in the body of a post or in your rss feed"
  tag "tag_list_technorati" do |tag|
    tag.locals.page.tag_list.map{|t| link_to(t, 'http://technorati.com/tag/' << t, :rel => :tag)}.join(", ")
  end
  
  tag "tags" do |tag|
    tag.expand
  end
  
  #desc "Iterates over the tags of the current page"
  tag "tags:each" do |tag|
    tag.locals.page.categories.map do |category|
      tag.locals.category = category
      tag.expand
    end
  end
  
  tag "tags:each:name" do |tag|
    tag.locals.category.name
  end
  
  tag "tags:each:link" do |tag|
    name = tag.locals.category.name
    link_to name, results_page(tag) << name, :class => 'tag'
  end

  #desc "Set the scope for all tags in the database"
  tag "all_tags" do |tag|
    tag.expand
  end
  
  desc %{
    Iterates through each tag and allows you to specify the order: by popularity or by name.
    The default is by name. You may also limit the search; the default is 5 results.
    
    Usage: <pre><code><r:all_tags:each order="popularity" limit="5">...</r:all_tags:each></code></pre>
  }
  tag "all_tags:each" do |tag|
    options = tag.attr.slice(:order, :limit).symbolize_keys
    
    if names = tag.attr[:names]
      names = names.split(",").map{|t| t.strip } 
      options[:conditions] = ["name IN (?)", names] if names.length > 0
    end
    
    Page.all_tag_counts(options).map do |t|
      tag.locals.tag = t
      tag.expand
    end
  end
  
  desc "Renders the tag's name"
  tag "all_tags:each:name" do |tag|
    tag.locals.tag.name
  end
  
  tag "all_tags:each:link" do |tag|
    name = tag.locals.tag.name
    link_to tag.expand.presence || name,
            results_page(tag) << name,
            tag.attr.reverse_merge(:class => 'tag')
  end
  
  desc "Set the scope for the tag's pages"
  tag "all_tags:each:pages" do |tag|
    tag.expand
  end
  
  desc "Iterates through each page"
  tag "all_tags:each:pages:each" do |tag|
    Page.tagged_with(tag.locals.tag.name, tag.attr.symbolize_keys).map do |page|
      tag.locals.page = page
      tag.expand
    end
  end
  
  private
  
  def build_tag_cloud(tag_cloud, style_list)
    max, min = 0, 0
    counts = tag_cloud.map(&:count)
    min, max = counts.min, counts.max
    
    divisor = ((max - min) / style_list.size) + 1

    tag_cloud.map do |tag|
      yield tag.name, style_list[(tag.count - min) / divisor], tag.count
    end
  end

  def tag_item_url(name)
    "#{Radiant::Config['tags.results_page_url']}/#{name}"
  end
  
  def find_with_tag_options(tag)
    options = tagged_with_options(tag)
    with_any = tag.attr[:with_any] || false
    scope_attr = tag.attr[:scope] || '/'

    raise TagError, "`tagged' tag must contain a `with' attribute." unless (tag.attr['with'] || tag.locals.page.class_name = TagSearchPage)
    ttag = tag.attr['with'] || @request.parameters[:tag]
    
    scope = scope_attr == 'current_page' ? Page.find_by_url(@request.request_uri) : Page.find_by_url(scope_attr)
    return "The scope attribute must be a valid url to an existing page." if scope.nil? || scope.class_name.eql?('FileNotFoundPage')

    
    page_ids = Page.tagged_with(ttag, options.merge(:any => with_any)).map do |page|
        page.id if page.ancestors.include?(scope) || page == scope
    end.compact
    
    Page.find_all_by_id page_ids, options
  end
  
  def tagged_with_options(tag)
    
    options = {}
    
    [:limit, :offset].each do |symbol|
      if number = tag.attr[symbol]
        if number =~ /^\d{1,4}$/
          options[symbol] = number.to_i
        else
          raise TagError.new("`#{symbol}' attribute of `each' tag must be a positive number between 1 and 4 digits")
        end
      end
    end
    
    by = (tag.attr[:by] || 'published_at').strip
    order = (tag.attr[:order] || 'desc').strip
    order_string = ''
    
    if self.attributes.keys.include?(by)
      order_string << by
    else
      raise TagError.new("`by' attribute of `each' tag must be set to a valid field name")
    end
    
    if order =~ /^(asc|desc)$/i
      order_string << " #{$1.upcase}"
    else
      raise TagError.new(%{`order' attribute of `each' tag must be set to either "asc" or "desc"})
    end
    
    options[:order] = order_string
    
    status = (tag.attr[:status] || 'published').downcase
    exclude = tag.attr[:exclude_id] ? "AND pages.id != #{tag.attr[:exclude_id]}" : ""
    
    unless status == 'all'
      stat = Status[status]
      unless stat.nil?
        options[:conditions] = ["(virtual = ?) and (status_id = ?) #{exclude} and (published_at <= ?)", false, stat.id, Time.current]
      else
        raise TagError.new(%{`status' attribute of `each' tag must be set to a valid status})
      end
    else
      options[:conditions] = ["virtual = ? #{exclude}", false]
    end
    
    options
  end

  def filter_tags_to_url_scope(tags, scope)
    tags.select{ |tag|
      tag.taggings.any?{ |tagging|
        tagging.taggable.url.starts_with? scope
      }
    }
  end
  
  delegate :template, :to => :response
#  delegate :link_to, :to => :template, :allow_nil => true
  delegate :content_tag, :to => :template
  
  def link_to *args
    args.second.gsub!(' ', '+') if args.second.respond_to?(:gsub)
    template.send(:link_to, *args)
  end
  
  def results_page(tag)
    (tag.attr['results_page'] || Radiant::Config['tags.results_page_url']).dup << "/"
  end
end
