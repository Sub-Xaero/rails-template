module LayoutHelper

  def standard_page_layout
    content_tag('div', class: 'container') do
      yield
    end
  end

  def page_title(title, meta_title: nil)
    content_for(:title, meta_title.present? ? meta_title : title)
    content_tag('h1', title)
  end

end