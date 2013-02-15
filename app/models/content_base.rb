module ContentBase
  def self.included base
    base.extend ClassMethods
  end

  def blog
    @blog ||= Blog.default
  end

  attr_accessor :just_changed_published_status
  alias_method :just_changed_published_status?, :just_changed_published_status

  # Grab the text filter for this object.  It's either the filter specified by
  # self.text_filter_id, or the default specified in the default blog object.
  def text_filter
    if self[:text_filter_id] && !self[:text_filter_id].zero?
      TextFilter.find(self[:text_filter_id])
    else
      default_text_filter
    end
  end

  # Set the text filter for this object.
  def text_filter= filter
    filter_object = filter.to_text_filter
    if filter_object
      self.text_filter_id = filter_object.id
    else
      self.text_filter_id = filter.to_i
    end
  end

  def really_send_notifications
    interested_users.each do |value|
      send_notification_to_user(value)
    end
    return true
  end

  def send_notification_to_user(user)
    notify_user_via_email(user)
  end

  # Return HTML for some part of this object.
  def html(field = :all)
    if field == :all
      generate_html(:all, content_fields.map{|f| self[f].to_s}.join("\n\n"))
    elsif html_map(field)
      generate_html(field)
    else
      raise "Unknown field: #{field.inspect} in content.html"
    end
  end

  # Generate HTML for a specific field using the text_filter in use for this
  # object.
  def generate_html(field, text = nil)
    text ||= self[field].to_s
    html = text_filter.filter_text_for_content(blog, text, self) || text
    html_postprocess(field,html).to_s
  end

  # Post-process the HTML.  This is a noop by default, but Comment overrides it
  # to enforce HTML sanity.
  def html_postprocess(field, html)
    html
  end

  def html_map field
    content_fields.include? field
  end

  def invalidates_cache?(on_destruction = false)
    @invalidates_cache ||= if on_destruction
      just_changed_published_status? || published?
    else
      (changed? && published?) || just_changed_published_status?
    end
  end

  def publish!
    self.published = true
    self.save!
  end

  # The default text filter.  Generally, this is the filter specified by blog.text_filter,
  # but comments may use a different default.
  def default_text_filter
    blog.text_filter_object
  end


  module ClassMethods
    def content_fields *attribs
      class_eval "def content_fields; #{attribs.inspect}; end"
    end

    def find_published(what = :all, options = {})
      with_scope(:find => where(:published => true).order(default_order)) do
        find what, options
      end
    end

    def default_order
      'published_at DESC'
    end
  end
end
