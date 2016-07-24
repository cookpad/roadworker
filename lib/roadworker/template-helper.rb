module Roadworker
  module TemplateHelper
    def include_template(template_name, context = {})
      tmplt = @context.templates[template_name.to_s]

      unless tmplt
        raise "Template `#{template_name}` is not defined"
      end

      context_orig = @context
      @context = @context.merge(context)
      instance_eval(&tmplt)
      @context = context_orig
    end

    def context
      @context
    end
  end
end
