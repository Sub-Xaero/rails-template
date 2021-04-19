# frozen_string_literal: true

module LayoutHelper

  def standard_page_layout(&block)
    tag.div(:div, class: "container", &block)
  end

  def page_title(title, meta_title: nil)
    content_for(:title, meta_title.presence || title)
    tag.h1(title)
  end

  def padded_center_layout(extra_classes = "")
    tag.div(class: "container-fluid d-flex justify-content-center align-items-center #{extra_classes}") do
      tag.div(class: "col-md-10 ") do
        if block_given?
          yield
        end
      end
    end
  end

  def auth_page_layout
    padded_center_layout("bg-dark py-5 min-h-screen") do
      tag.div(class: "text-center rounded shadow bg-light m-2 m-md-4 p-4") do
        if block_given?
          yield
        end
      end
    end
  end

end
