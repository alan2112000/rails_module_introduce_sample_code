ActiveRecord provides many useful public method we can easily write some code by DSL(domain specific language) to achieve some callback chain or validation in ActiveRecord. Those function are mysyster and incredible helpful. Those useful function most are from **ActiveModel** module. Today we are going to go through serveral of module to see the mystery and incrediable helpful module.

## ActiveModel::AttributeMethods 

#### Requirement

If you have some similar public method which will base on the attribute of the class like 
`reset_attribute1`, `reset_attribute2`. Before using the module directly let's write some code to create this function. 


#### Assumption 

1. Each attribute in the class should have `reset_attribute` method which will set the attribute to be `nil` or the `attribute_sync` which sync the attriute from other place(which we don't care about the implementation detail here.)

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

The same function we can easily to use provided by `ActiveModel::AttributeMethods` to create some simliar function for that. 

Here are the few steps you to use the `ActiveModel::AttributeMethods` 

1. Include `ActiveModel::AttributeMethods` in your class.

2. Call each of its methods you want to add, such as attribute_method_suffix or attribute_method_prefix.

3. Call define_attribute_methods after the other methods are called.

4. Define the various generic _attribute methods that you have declared.

5. Define an attributes method which returns a hash with each attribute name in your model as hash key and the attribute value as hash value. Hash keys must be strings.


[Documentaion of ActiveModel::AttribuiteMethods](https://api.rubyonrails.org/classes/ActiveModel/AttributeMethods.html)

Althgouth we did not remove a lot of code compare to the first example, once the attributes are more and more, it's not a good idea to manually write those method again and agian. 

The `define_method` in Ruby can still achieve the same thing, but personally I am a fans to resue the module which created by others. 

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

After you included this module into your class you have those abilitites

- You can know what kind of attriburtes has been changed 
- You can know the old valid of the attributes you have changed 
- You can restore the value back if you want to. 

Below is the example code from the rails documentation 

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

Let's say we are going to reimplment a object like ActiveRecord which only need us to implmenent `execute` public method in child class, and we can set `valid?` before the `execute` method, and the `sync_method` after the `execute` method 


The sample code like there

```ruby
execution_object = BaseExecutionClass.new

execution_object.execute # it will execute below method in sequence 1. valid? 2. execute 3. sync_method


```

Then how do we write the base class to have this function?

We can use another useful module provided by the `ActiveSupport::Callback` which we can define the code hook during the object lifecycle.

we can use the class method `define_callbacks` to have the function we describe above. 

```ruby
require 'active_support/callbacks'
class BaseClass
  include ActiveSupport::Callbacks
  define_callbacks :execute

  set_callback :execute, :before, :valid?
  def valid?
    raise NotImplementError
  end

  set_callback :execute, :after, :sync_method
  def sync_method
    raise NotImplementError
  end


  def execute
    return false unless valid?
    run_callbacks :execute do

      puts "In excute method itsefl"
    end
  end
end

class ChildClass < BaseClass
  def valid?
    puts "in validation"
  end

  def sync_method
    puts "in sync method"
  end
end

child_instance = ChildClass.new
child_instance.execute
```

Instead rewriting everything from scratch, `ActiveSupport::Callbacks` provide as the function to define the events in object life cycle which is supper convenient. 

[Docuemntation of ActiveSupport::Callbacks](https://kapeli.com/dash_share?docset_file=Ruby%20on%20Rails&docset_name=Ruby%20on%20Rails%205&path=api.rubyonrails.org/classes/ActiveSupport/Callbacks.html%23method-i-run_callbacks&platform=rails&repo=Main&source=api.rubyonrails.org/classes/ActiveSupport/Callbacks.html&version=5.2.1)


Here I won't cover all of the module be used in rails. there are still some useful module you can use outside the rails like `ActiveModel::Validations`, `ActiveModel::Errors`..., you dig into the source code to know how the commiter write those module I think it's a good way to know more about ruby and rails. 

Happy coding !!