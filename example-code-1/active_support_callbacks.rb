require 'active_support/callbacks'
class BaseClass
  include ActiveSupport::Callbacks
  define_callbacks :execute, skip_after_callbacks_if_terminated: :abort

  set_callback :execute, :before, :valid?,
  def valid?
    raise NotImplementError
  end

  set_callback :execute, :after, :sync_method
  def sync_method
    raise NotImplementError
  end


  def execute
    run_callbacks :execute do
      puts "In excute method itsefl"
    end
  end
end

class ChildClass < BaseClass
  def valid?
    puts "in validation"

    throw(:abort)
  end

  def sync_method
    puts "in sync method"
  end
end

child_instance = ChildClass.new
child_instance.execute
