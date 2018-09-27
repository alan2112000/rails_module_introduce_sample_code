ActiveRecord provides many useful public methods we can easily write some code by DSL(domain specific language) to achieve some callback chain or validation in ActiveRecord. Those functions are mistery and incredibly helpful. Those useful function most are from **ActiveModel** module. Today we are going to go through several modules to see the mystery and incredibly helpful module.

## ActiveModel::AttributeMethods 

#### Requirement

If you have some similar public method which will base on the attribute of the class like 
`reset_attribute1`, `reset_attribute2`. Before using the module directly let's write some code to create this function. 

#### Assumption 

1. Each attribute in the class should have `reset_attribute` method which will set the attribute to be `nil` or the `attribute_sync` which sync the attribute from another place (which we don't care about the implementation detail here.)

```ruby
class SomePureRubyObject
  attr_accessor :first_name, :last_name  # => nil

  def reset_first_name
    self.first_name = nil
  end                      # => :reset_first_name

  def reset_last_name
    self.last_name = nil  # => nil
  end                     # => :reset_last_name

  def first_name_sync_from_other_place
    self.first_name = sync_from_other_place(:first_name)  # => "sync by other for first_name"
  end                                                     # => :first_name_sync_from_other_place

  def last_name_sync_from_other_place
    self.last_name = sync_from_other_place(:last_name)
  end                                                   # => :last_name_sync_from_other_place

  private  # => SomePureRubyObject

  def sync_from_other_place(attribute)
    # which we don't care about the implementation here
    "sync by other for #{attribute}"    # => "sync by other for first_name"
  end                                   # => :sync_from_other_place
end                                     # => :sync_from_other_place

object = SomePureRubyObject.new  # => #<SomePureRubyObject:0x007f897e3f0908>
object.last_name = 'set by me'   # => "set by me"
object.reset_last_name           # => nil
object.last_name                 # => nil

object.first_name_sync_from_other_place  # => "sync by other for first_name"
object.first_name                        # => "sync by other for first_name"

```

Let's write the code by using `ActiveModel::AttributeMethods` to ahcieve same function here.

```ruby
require 'active_model'                     # => true
class SomePureRubyObject
  include ::ActiveModel::AttributeMethods  # => SomePureRubyObject

  attribute_method_suffix '_sync_from_other_place'  # => #<Concurrent::Map:0x007fb9c80d2f30 entries=0 default_proc=nil>
  attribute_method_prefix 'reset_'                  # => #<Concurrent::Map:0x007fb9c80d2f30 entries=0 default_proc=nil>
  define_attribute_methods :first_name, :last_name  # => [:first_name, :last_name]
  attr_accessor :first_name, :last_name             # => nil

  private  # => SomePureRubyObject

  def attribute_sync_from_other_place(attr)
    send("#{attr}=", sync_from_other_place(attr))  # => "sync by other for first_name"
  end                                              # => :attribute_sync_from_other_place

  def reset_attribute(attr)
    send("#{attr}=", nil)    # => nil
  end                        # => :reset_attribute

  def sync_from_other_place(attribute)
    # which we don't care about the implementation here
    "sync by other for #{attribute}"    # => "sync by other for first_name"
  end                                   # => :sync_from_other_place
end                                     # => :sync_from_other_place

object = SomePureRubyObject.new  # => #<SomePureRubyObject:0x007fb9c80aa8c8>
object.last_name = 'set by me'   # => "set by me"
object.reset_last_name           # => nil
object.last_name                 # => nil

object.first_name_sync_from_other_place  # => "sync by other for first_name"
object.first_name                        # => "sync by other for first_name"

```

The same function we can easily to use provided by `ActiveModel::AttributeMethods` to create some similar function for that. 

Here are the few steps you to use the `ActiveModel::AttributeMethods` 

1. Include `ActiveModel::AttributeMethods` in your class.

2. Call each of its methods you want to add, such as attribute_method_suffix or attribute_method_prefix.

3. Call define_attribute_methods after the other methods are called.

4. Define the various generic _attribute methods that you have declared.

5. Define an attributes method which returns a hash with each attribute name in your model as hash key and the attribute value as hash value. Hash keys must be strings.


[Documentaion of ActiveModel::AttribuiteMethods](https://api.rubyonrails.org/classes/ActiveModel/AttributeMethods.html)

Although we did not remove a lot of code compare to the first example, once the attributes are more and more, it's not a good idea to manually write those methods again and again. 

The `define_method` in Ruby can still achieve the same thing, but personally, I like to reuse the existing module to finish my work.

## Tracking System in AcitveModel 

It's quite interesting that when ActiveRecord decide trigger sql `UPDATE` command to database, when not to. 

Consider to below code

```ruby
# first_name Strign type
class Post < ActiveRecord
end


post = Post.find(1)
post.save  #=> wont' trigger sql command

post.first_name = 'what ever'
post.save #=> it trigger sql command
```

The magic part is the `ActiveModel::Dirty` module 

Here is the documentation of the `ActiveModel::Dirty` 

> Provides a way to track changes in your object in the same way as Active Record does.

After you included this module in your class you have those abilities

- You can know what kind of attributes has been changed 
- You can know the old valid of the attributes you have changed 
- You can restore the value back if you want to. 

Below is the example code from the Rails documentation  

```ruby
class Person
  include ActiveModel::Dirty

  define_attribute_methods :name  # Here we define the attribute we want to tracking

  def initialize
    @name = nil
  end

  def name
    @name
  end

  def name=(val)
    name_will_change! unless val == @name # once the attribute be changed , we need to record this change into our trackign module
    @name = val
  end

  def save 
    # do persistence work

    changes_applied
  end

  def reload!
    # get the values from the persistence layer

    clear_changes_information
  end

  def rollback!
    restore_attributes
  end
end
```

```ruby
person = Person.new
person.changed? # => false



person.name = 'Bob'
person.changed?       # => true
person.name_changed?  # => true
person.name_changed?(from: nil, to: "Bob") # => true
person.name_was       # => nil
person.name_change    # => [nil, "Bob"]
person.name = 'Bill'
person.name_change    # => [nil, "Bill"]
```

Now, we have some dirty tracking function on our attributes also if we want to restore the old value back it still really easy. 

## Define callback arround you public method 

Let's say we are going to reimplement an object like ActiveRecord which only need us to implement `execute` public method in the child class, and we can set `valid?` before the `execute` method, and the `sync_method` after the `execute` method 

The sample code like there

```ruby
execution_object = BaseExecutionClass.new

execution_object.execute # it will execute below method in sequence 1. valid? 2. execute 3. sync_method


```

Then how do we write the base class to have this function?

We can use another useful module provided by the `ActiveSupport::Callback` which we can define the code hook during the object lifecycle.

we can use the class method `define_callbacks` to have the function we describe above. 

```ruby
require 'active_support/callbacks'  # => true
class BaseClass
  include ActiveSupport::Callbacks  # => BaseClass
  define_callbacks :execute         # => [:execute]

  set_callback :execute, :before, :valid?  # => [BaseClass]
  def valid?
    raise NotImplementError
  end                                      # => :valid?

  set_callback :execute, :after, :sync_method  # => [BaseClass]
  def sync_method
    raise NotImplementError
  end                                          # => :sync_method


  def execute
    run_callbacks :execute do
      puts "In excute method itsefl"  # => nil
    end                               # => nil
  end                                 # => :execute
end                                   # => :execute

class ChildClass < BaseClass  # => BaseClass
  def valid?
    puts "in validation"      # => nil
  end                         # => :valid?

  def sync_method
    puts "in sync method"  # => nil
  end                      # => :sync_method
end                        # => :sync_method

child_instance = ChildClass.new  # => #<ChildClass:0x00007fbe688808f0>
child_instance.execute           # => nil

# >> in validation
# >> In excute method itsefl
# >> in sync method

```

Looks good !! 

now let's change return throw abort to mimic the behavior that some validation failed in the first callback and it should stop execute the sequence of the callback methods. 

```ruby
class ChildClass < BaseClass  # => BaseClass
  def valid?
    puts "in validation"      # => nil

    throw(:abort)
  end              # => :valid?

  def sync_method
    puts "in sync method"  # => nil
  end                      # => :sync_method
end                        # => :sync_method

child_instance = ChildClass.new  # => #<ChildClass:0x00007f8f6407b598>
child_instance.execute           # => false

# >> in validation
# >> in sync method

```

Why??  Why do we still get the after method be executed? The only callback chain be skipped is the `execute` method itself. 

According to the `define_callback` [documentation](https://api.rubyonrails.org/classes/ActiveSupport/Callbacks/ClassMethods.html) 

- `terminator` option default value is `abort` only for the `before` and `arround` callback

- `skip_after_callback_if_terminated`: Determines if after callbacks should be terminated by the :terminator option. By default after callbacks are executed no matter if callback chain was terminated or not. This option has no effect if :terminator option is set to nil.


It means we need to set it to skip after callback or not

The final version will be  

```
define_callbacks :execute, skip_after_callbacks_if_terminated: :abort  # => [:execute]
```

put an extra option for the callback, then we can halt the whole callback chain successfully. 


### Dig Deeper the callback module

Below is the source code of the `define_callback` 

```ruby
def define_callbacks(*names)
  options = names.extract_options!

  names.each do |name|
    name = name.to_sym

    ([self] + ActiveSupport::DescendantsTracker.descendants(self)).each do |target|
      target.set_callbacks name, CallbackChain.new(name, options)
    end

    module_eval <<-RUBY, __FILE__, __LINE__ + 1
              def _run_#{name}_callbacks(&block)
                run_callbacks #{name.inspect}, &block
              end
              def self._#{name}_callbacks
                get_callbacks(#{name.inspect})
              end
              def self._#{name}_callbacks=(value)
                set_callbacks(#{name.inspect}, value)
              end
              def _#{name}_callbacks
                __callbacks[#{name.inspect}]
              end
    RUBY
  end
end

```

[source code](https://github.com/rails/rails/blob/master/activesupport/lib/active_support/callbacks.rb#L812)


Here we can see in the module it try to define `_run_execute_callbacks(&block)`, `self._execute_callbacks`, `self._execute_callback=(value)`, `_execute_callbacks` method here, which is represent

1. running execute callback 
2. class method which return the callback chain of `execute` 
3. `self._execute_callbacks=(value)`
4. `_execute_callbacks` => The callbacks of the `excute` method we define 


`set_callback` source code here

set_callback will get the existing callback by using `get_callbacks` we can get the callbacks of the `execute` and wrap the new callbacks by the `Callback` class and update into existing callbacks of the `execute` method here.

```ruby
def set_callback(name, *filter_list, &block)
  type, filters, options = normalize_callback_params(filter_list, block)

  self_chain = get_callbacks name
  mapped = filters.map do |filter|
    Callback.build(self_chain, filter, type, options)
  end

  __update_callbacks(name) do |target, chain|
    options[:prepend] ? chain.prepend(*mapped) : chain.append(*mapped)
    target.set_callbacks name, chain
  end
end
```

After hook the `execute` method chain then we will run below code `run_callbacks :execute` to trigger our callbacks for `execute` method 


[source code](https://github.com/rails/rails/blob/master/activesupport/lib/active_support/callbacks.rb#L94)

```ruby
  def run_callbacks(kind)
      callbacks = __callbacks[kind.to_sym]

      if callbacks.empty?
        yield if block_given?
      else
        env = Filters::Environment.new(self, false, nil)
        next_sequence = callbacks.compile

        invoke_sequence = Proc.new do
          skipped = nil
          while true
            current = next_sequence
            current.invoke_before(env)
            if current.final?
              env.value = !env.halted && (!block_given? || yield)
            elsif current.skip?(env)
              (skipped ||= []) << current
              next_sequence = next_sequence.nested
              next
            else
              next_sequence = next_sequence.nested
              begin
                target, block, method, *arguments = current.expand_call_template(env, invoke_sequence)
                target.send(method, *arguments, &block)
              ensure
                next_sequence = current
              end
            end
            current.invoke_after(env)
            skipped.pop.invoke_after(env) while skipped && skipped.first
            break env.value
          end
        end

        # Common case: no 'around' callbacks defined
        if next_sequence.final?
          next_sequence.invoke_before(env)
          env.value = !env.halted && (!block_given? || yield)
          next_sequence.invoke_after(env)
          env.value
        else
          invoke_sequence.call
        end
      end
    end
```

We can see the `callbacks.compile` will return an instance of `CallbackSequence` which is responsibly storing the before callbacks, around callbacks, and after callbacks. 

and here is the exactly the place where our callbacks are run here.


Instead of rewriting everything from scratch, `ActiveSupport::Callbacks` provide as the function to define the events in object life cycle which is super convenient. 

[Docuemntation of ActiveSupport::Callbacks](https://kapeli.com/dash_share?docset_file=Ruby%20on%20Rails&docset_name=Ruby%20on%20Rails%205&path=api.rubyonrails.org/classes/ActiveSupport/Callbacks.html%23method-i-run_callbacks&platform=rails&repo=Main&source=api.rubyonrails.org/classes/ActiveSupport/Callbacks.html&version=5.2.1)

Here I won't cover all of the modules be used in rails. there is still some useful modules you can use outside the rails like `ActiveModel::Validations`, `ActiveModel::Errors`..., you dig into the source code to know how the commiter write those modules I think it's a good way to know more about ruby and rails.