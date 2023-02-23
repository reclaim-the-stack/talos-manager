class ApplicationFormBuilder < ActionView::Helpers::FormBuilder
  INPUT_CLASSES = "w-full p-3 mb-5 rounded border border-gray-300 disabled:text-gray-500".freeze

  def text_field(attribute, options = {})
    input_with_label_and_validation(attribute, options) { super }
  end

  def text_area(attribute, options= {})
    input_with_label_and_validation(attribute, options) { super }
  end

  def password_field(attribute, options = {})
    input_with_label_and_validation(attribute, options) { super }
  end

  def email_field(attribute, options = {})
    input_with_label_and_validation(attribute, options) { super }
  end

  def select(attribute, choices = nil, options = {}, html_options = {})
    html_options[:class] = "#{INPUT_CLASSES} appearance-none"
    # Inline CSS SVG background for custom caret
    html_options[:style] = %(background: url('data:image/svg+xml;utf8,<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 40 40"><polygon points="2.7,14.4 6.8,10.3 20,23.5 33.2,10.3 37.3,14.4 20,31.7 "/></svg>') no-repeat right 0.7rem top 50% rgba(249,250,251); background-size: 0.5rem auto) # rubocop:disable Layout/LineLength

    input_with_label_and_validation(attribute, html_options) { super }
  end

  SUBMIT_CLASSES =
    "w-full rounded text-white bg-mnd-red hover:bg-mnd-red-dark cursor-pointer disabled:cursor-default
    disabled:bg-mnd-red-light font-semibold p-3 mb-3".freeze

  def submit(label, options = {})
    options[:class] = SUBMIT_CLASSES

    super
  end

  private

  def input_with_label_and_validation(attribute, options = {})
    options[:class] = "#{INPUT_CLASSES} #{options[:class]}"
    options[:required] = true unless options.key?(:required)
    validation_errors = object.errors[attribute].to_sentence.capitalize.presence

    label = label(attribute, options.delete(:label)&.delete_suffix(":"), class: "block mb-2 text-left font-bold")
    error = validation_errors && %(<p class="-mt-2 mb-4 text-left text-sm text-red-500">#{validation_errors}</p>)

    options[:class] = "#{options[:class]} border-red-400" if error

    input = yield

    %(#{label}#{input}#{error}).html_safe
  end
end
