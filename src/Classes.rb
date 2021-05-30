class Array
  #Makes arrays "runnable" as to make them flow through functions that work on valids
  def execute
    self
  end
end


class Function
  #Class that represent one function
  #Open set to true means that parameters are being sent in as references
  def initialize(name,params,exec_list,open = false)
    @name = name
    @params = []
    params.each do |param_name|
      if param_name.is_a? Array
        param_name = param_name[0]
      end
      @params << param_name
    end
    @exec_list = exec_list
    @open = open
  end

  def get_params()
    @params
  end

  def is_open()
    @open
  end

  def get_param_from_index(index)
    @params[index]
  end

  def execute
    #Add function to current scope so a call to own function (recursion) works
    Dopo.scope_append(@name, @params, @exec_list, @open)
    ret = @exec_list.execute
    ret
  end
end


class Scope
  #The class represents a scope that can contain variables and functions
  #An open scope is for loops and if-statments, closed for functions and global scope

  def initialize(open = false)
    @variables = Hash.new
    @functions = Hash.new
    @open = open
  end

  def get_var(name)
    ret = @variables[name]
    ret
  end

  def set_open(val)
    @open = val
  end

  def get_func(name)
    ret = @functions[name]
    ret
  end

  def insert_var(name,data)
    @variables[name] = data
  end

  def insert_func(name, parameters, func, open = false)
    @functions[name] = Function.new(name,parameters,func, open)
  end

  def get_func_param(name, index = nil)
    if index != nil
      ret = @functions[name].get_param_from_index(index)
    else
      ret = @functions[name].get_params
    end
    ret
  end

  def exec_func(name)
    @functions[name].execute
  end

  def contains_var(name)
    exists = @variables.key? name
    exists
  end

  def contains_func(name)
    exists = @functions.key? name
    exists
  end

  def is_loop
    @open == "loop"
  end

  def is_open
    if @open
      true
    else
      false
    end
  end

  ########################### TESTING PURPOSE ##############################
  def to_s
    #More convinient way to print a Scope class
    ret_s= ""
    ret_s+=("VARIABLES: ")
    ret_s+=("\n")
    @variables.each do |var|
      ret_s+=("#{var}, ")
    end
    ret_s+=("\n")
    ret_s+=("FUNCTIONS: ")
    ret_s+=("\n")
    @functions.each do |func|
      ret_s+=("#{func} ")
    end
    ret_s
  end
  ##########################################################################
end


#Classes for the Dopo language internal executable structure
class Valid_list
  #Class that contains a chain of valids
  #Signals when to apply abort-, continue- or return-statement

  @@return_flag = false
  @@ret_val = nil
  @@is_aborting = false
  @@command = nil

  def initialize(valid, valid_list = nil)
    @valid = valid
    @valid_list = valid_list
  end

  def check_still_aborting_or_continuing
    #Checks if we have encountered an abort-statement last valid
    if @@is_aborting
      #We are currently in a loop scope, aborting is done after this return
      if Dopo.is_looping
        @@is_aborting = false
        return true
        #Continue to abort, we are still in a if-statement inside a loop
      elsif Dopo.is_open
        return true
      end

      @@is_aborting = false
      return false
    end
  end

  def check_running_abort_or_continue(control_check)
    if control_check.is_a? Abort_statement or control_check.is_a? Continue_statement
      @@command = control_check

      #we found closest loop
      if Dopo.is_looping
        @@is_aborting = false
        return true
      else
        @@is_aborting = true
        return true
      end
    end

    return false
  end

  def check_running_return(control_check)
    if control_check.is_a? Return_statement and @@return_flag == false
      @@return_flag = true
      @@ret_val = control_check.get_val
      return true
    end

    return false
  end

  def check_still_returning
    if @@ret_val != nil
      @@return_flag = false
      return true
    end

    return false
  end

  def execute
    #Runs current valid as well as the next valid list

    if check_still_aborting_or_continuing
      return @@command
    end

    #run the first valid
    control_check = @valid.execute

    if check_running_abort_or_continue(control_check)
      return @@command
    end

    if check_running_return(control_check)
      return @@ret_val
      #runs the rest of the valids
    elsif @valid_list != nil and @@return_flag == false
      control_check = @valid_list.execute
    end

    if check_still_returning
      #if in loop or if-statement, abort to get out of it.
      if Dopo.is_open
        return Abort_statement.new
      end

      ret = @@ret_val
      @@ret_val = nil
      return ret
    else
      #no return, abort, continue encountered return @valid_list.execute
      return control_check
    end
  end
end


class Valid
  #A valid node in the execute structure
  def execute
  end
end


class Includer < Valid
  #So that the user can include files into the program
  #Can chain multiple files in one include
  def initialize(file, parser)
    @file = file
    @parser = parser
  end

  def execute
    @file.flatten!

    @file.each do |f|
      exec_string = f.execute
      begin
        read_str = File.read(exec_string)
        @parser.parse(read_str)
      rescue
        raise Exception.new "File #{exec_string} not found"
      end
    end

    nil
  end
end


class Assignment < Valid
  #An assignment of a variable or function
  #Open set to true is for functions that take references as parameters
  #Valids are for functions and is the statements to run in a function block
  def initialize(value, name, valids = nil, open = false)
    @name = name
    @value = value
    @valids = valids
    @open = open
  end

  def execute
    #Appends a variable or function to @@scopes
    name_exec = @name.get_name
    val_exec = @value.execute

    #Variable
    if @valids == nil
      #Used for setting new values in a List, String_c or Dictionary by index
      if @name.is_a? Iterate and @name.execute # check index in range
        iterate_name = @name
        iterate = @name.call.execute
        index = @name.lookup.execute
        iterate[index] = val_exec

        ret = Dopo.scope_append(iterate_name, val_exec)
      else
        ret = Dopo.scope_append(name_exec, val_exec)
      end
    else
      #Function
      @reserved_names = ["p", "g"]
      if @reserved_names.include? name_exec
        raise Exception.new "\"#{name_exec}\" is a reserved function name"
      end

      Dopo.scope_append(name_exec, val_exec, @valids, @open)
      ret = Nil_c.new.execute
    end

    ret
  end
end


class Param_list < Valid
  #Used to get the paramteters to functions or to get the elements in a list
  def initialize(call, param_list = nil)
    @call = call
    @param_list = param_list
  end

  def get_name
    #Used to get the name of all values stored in a parameter-list
    ret_arr = []

    if @param_list == nil
      ret_arr << @call.get_name
    else
      if @param_list.is_a? Param_list
        ret_arr = [@call.get_name] + @param_list.get_name
      else
        ret_arr = [@call.get_name] << @param_list.get_name
      end
    end

    ret_arr
  end

  def execute
    #Returns an array of executed calls
    ret = Default.new

    if @param_list == nil
      ret = [@call.execute]
    else
      if @param_list.is_a? Param_list
        ret = [@call.execute] + @param_list.execute
      else
        ret = [@call.execute] << @param_list.execute
      end
    end

    ret
  end
end


class Name_list < Valid
  #Chain of names in parameter-list for when declaring a function
  def initialize(name, name_list = nil)
    @name = name
    @name_list = name_list
  end

  def execute
    #Returns an array of names of every parameter
    if @name_list != nil
      ret =[@name.execute] + @name_list.execute
    else
      ret = [@name]
    end

    ret
  end
end


class For_each < Valid
  #Functionality for a for_each loop
  #Works with String_c, List and Dictionary
  def initialize(collection, valid_list,var_name)
    @collection = collection
    @valid_list = valid_list
    @var_name = var_name
  end

  def execute
    Dopo.new_scope(open="loop")
    name = @var_name.get_name

    looper = @collection.execute

    if looper.is_a? Hash
      looper = looper.to_a
    end

    for i in 0..looper.length - 1
      loop_list = @valid_list
      Dopo.scope_append(name, looper[i])
      abort_check = loop_list.execute
      if abort_check.is_a? Abort_statement
        break
      end
    end

    Dopo.destroy_scope
    0
  end
end


class While < Valid
  #Funtionality to add a while loop
  def initialize(condition, valid_list)
    @condition = condition
    @valid_list = valid_list
  end

  def execute
    Dopo.new_scope(open="loop")
    cond_check = @condition.execute
    while(cond_check)
      loop_list = @valid_list
      abort_check = loop_list.execute

      if abort_check.is_a? Abort_statement
        break
      end

      cond_check = @condition.execute
    end

    Dopo.destroy_scope
    0
  end
end


class Abort_statement < Valid
  #Represent an abort of a loop in the language
  def initialize
  end

  def execute
    self
  end
end


class Continue_statement < Valid
  #Represent a continue in the language
  def initialize
  end

  def execute
    self
  end
end


class Return_statement < Valid
  #Represent a return in the language
  def initialize(call)
    @call = call
    @value = nil
  end

  def get_val
    @value
  end

  def execute
    @value = @call.execute
    self
  end
end


class Call < Valid
  #A call to a function
  def initialize(name, param_list = [])
    @name = name
    @param_list = param_list
  end

  def get_name
    ''
  end

  def find_func_in_scopes(name, param_execs)
    found_scope = nil

    #loop to find the function with the name being called in program
    Dopo.scopes.reverse_each.with_index do |scope,i|
      if scope.contains_func(name)
        #check function that is being called has same number of arguments as the declared one
        if scope.get_func_param(name).length != param_execs.length
          raise Exception.new "Wrong number of arguments to" + ' "' + "#{name}" + '"'
        else
          #save the scope
          found_scope = scope
        end
      end

      if found_scope != nil
        return found_scope
        #if didn't find declared function
      elsif found_scope == nil and i == Dopo.scopes_length - 1
        raise Exception.new "Unknown function with name" + ' "' + "#{name}" + '"'
      end
    end
  end

  def update_variables_if_pass_by_ref(name)
    #Function that handles if a function is open, update variable being sent in.
    #An open function means parameters are being passed by reference
    if !@param_list.is_a? Array
      new_params = {}
      #get_name will return the name of the variable if it is of type Variable
      #otherwise it will return '' for other datatypes
      name_list = @param_list.get_name
      name_list.each_with_index do |var, i|
        if var == ''
          next
        end

        scope = Dopo.scope_from_index(-1)
        scope.set_open(true)

        ref_value = scope.get_var(scope.get_func_param(name, i))
        new_params[var] = ref_value
      end

      Dopo.destroy_scope
      new_params.each { |key,value| Dopo.scope_append(key, value) }
    end
  end

  def run_func(name, param_execs)
    #Appends a functions parameters to closest scope and runs function

    found_scope = find_func_in_scopes(name, param_execs)
    Dopo.new_scope

    #add parameters as variables in found function call
    param_execs.each_with_index do |var, i|
      Dopo.scope_append(found_scope.get_func_param(name,i), var)
    end

    ret = found_scope.exec_func(name)

    #if dealing with open function
    if found_scope.get_func(name).is_open
      update_variables_if_pass_by_ref(name)
    else
      Dopo.destroy_scope
    end

    ret
  end


  def execute
    #creates a new scope, assigns parameters in this scope
    #and runs the "name" function executables in this scope
    tmp = @param_list.execute
    name_val = @name.get_name
    ret = run_func(name_val, tmp)
    ret
  end
end


class Default < Valid
  #Represent a default value to initialize certain checks
  def initialize
  end

  def execute
    self
  end
end


class Print < Valid
  #Functionality for print to terminal
  #Words==nil print newline only
  def initialize(words = nil)
    @words = words
  end

  def execute
    if @words == nil
      puts()
    else
      printer = @words.execute
      p(printer)
    end
  end
end


class User_input < Valid
  #Functionality for getting input from users using terminal
  #Can be used as a parameter in function calls and when creating a list
  def initialize(parser, var = nil)
    @parser = parser
    @var = var
  end

  def execute
    @input = STDIN.gets.chomp!

    if @var != nil
      ret = @parser.parse "(#{@input}, #{@var.get_name})@"
    else
      ret = @parser.parse @input
    end

    ret
  end
end


class Operator_expr < Call
  #Represents mathematical operators (+-*^ etc,) as well as binary operators (> = ! >= etc.)
  #And their functionality, a part of it relies on rubys functions via use of "eval".
  #Execute functions that will run depends on the dataype being sent in as paramter (param_list)
  def initialize(op, param_list = nil)
    @op = op
    @param_list = param_list
  end

  def execute
    #Find out what datatype that are being sent in and call the execute connected to that datatype
    @executed_list = @param_list.execute
    check_class = @executed_list[0].class

    if check_class == Hash
      return execute_dict_func
    elsif @executed_list.any? { |parameter| parameter.is_a? Array }
      return execute_list_func
    elsif @executed_list.any? { |parameter| parameter.nil? }
      return execute_nil_comp
    elsif @executed_list.all? { |parameter| parameter.is_a? TrueClass or parameter.is_a? FalseClass }
        execute_bool_logic
    elsif @executed_list.all? { |parameter| parameter.is_a? Integer or parameter.is_a? Float }
        execute_arithmetic
    elsif  @executed_list.all? { |parameter| parameter.is_a? String }
        execute_string_functionality
    else
      raise Exception.new "unexpected \"#{@executed_list}\" in call to \"#{@op}\" "
    end
  end

  def execute_dict_func
    if @op == "!" and @executed_list.length == 1
      if @executed_list[0].empty?
        return_val == true
      else
        return_val == false
      end
    elsif @op == '+'
      ret_dict = @executed_list[0].clone
      @executed_list[1..-1].each{ |param|  ret_dict.merge!(param)}
    elsif @op == '-'
      ret_dict = @executed_list[0].clone
      @executed_list[1..-1].each{ |param|  ret_dict.delete(param)}
    elsif @op == '='
      ret_dict = true
      @executed_list[1..-1].each{ |param|
        if @executed_list[0] != param
          ret_dict = false
          break
        end
      }
    else
      raise Exception.new "OPERROR \"#{@op}\" does not have functionality for Dictionary"
    end

    ret_dict
  end

  def execute_nil_comp
    if @op == '='
      ret = @executed_list.all? { |parameter| parameter == nil }
      if ret
        ret = true
      else
        ret = false
      end
    elsif @op == '!='
      nilcount = 0
      @executed_list.each { |parameter|
        if parameter == nil
          nilcount =+ 1
        end
      }
      if (nilcount == 1)
        ret = true
      else
        ret = false
      end
    elsif @op == '!' and @executed_list.length == 1
      return true
    else
      ret = nil
    end

    ret
  end

  def execute_list_func
    #execute for +, !, - and = operators for List class
    var1 = @executed_list[0].clone
    var2 = @executed_list[1].clone

    if @op == "!" and @executed_list.length == 1
      if @executed_list[0].empty?
        return_val == true
      else
        return_val == false
      end
    elsif @op == "+"
      return_val = []
      @executed_list.each {|val|
        if val.is_a? Array
          return_val = return_val + val
        else
          return_val = return_val << val
        end
      }
      return_val
    elsif @op == "="
      return_val = true
      @executed_list[1..-1].each{ |param|
        if  @executed_list[0] != param
          return_val = false
          break
        end
      }
    elsif @op == "-"
      var1.delete_at(var1.index(var2))
      return_val = var1
    else
      raise Exception.new "OPERROR \"#{@op}\" is not a allowed operator for List"
    end

    return_val
  end

  def execute_bool_logic
    #execute for bool_c class similiar to boolean algebra.
    var1 = @executed_list[0]
    var2 = @executed_list[1]

    if @op == "!"
      return_val = (not(var1))
    elsif @op == "+" or @op == "|"
      return_val = @executed_list[0]
      @executed_list.each {|val|
        return_val = (return_val or val)
      }
      return_val
    elsif @op == "*" or @op == "&"
      return_val = @executed_list[0]
      @executed_list.each {|val|
        return_val = (return_val and val)
      }
      return_val
    elsif @op == "="
      return_val = (var1 == var2)
    elsif @op == "-"
      return_val = (var1 and (not var2))
    elsif @op == "->"
      return_val = (not(var1 and (not var2)))
    else
      raise Exception.new "OPERROR operator \"#{@op}\" does not have functionality for booleans"
    end

    return_val
  end

  def execute_string_functionality
    #Execute for string_c class when using -, =, !=, +, !, <, >, >=, <= operator
    vars = @executed_list
    req_two_args = ["=", "!=", ">", "<", "<=", ">="]
    if vars.length != 2 and req_two_args.include? @op
      raise Exception.new "OPERROR \"#{@op}\" only allowed between two strings"
    end
    res_str = ""

    if @op == "-"
      #Remove substrings in a string
      res_str = vars.shift
      vars = vars.reverse
      vars.each { |str| res_str.sub!(str, "") }
      res_str
    elsif @op == "!"
      return false
    elsif @op == "=" or @op == "!="
      #Compare two strings equal or not
      if @op == "="
        return vars[0] == vars[1]
      else
        return vars[0] != vars[1]
      end
    elsif @op == "+"
      vars.each do |str|
        res_str += str
      end
      res_str
    #Compare based of letters
    elsif @op == ">"
      return vars[0] > vars[1]
    elsif @op == "<"
      return vars[0] < vars[1]
    elsif @op == ">="
      return vars[0] >= vars[1]
    elsif @op == "<="
      return vars[0] <= vars[1]
    else
      raise Exception.new "OPERROR \"#{@op}\" is not allowed operator for String"
    end

    res_str
  end

  def execute_arithmetic
    #Translates a math expr match to a ruby evaluate-able string and evaluates it

    if @op == "->"
      raise Exception.new "OPERROR \"#{@op}\" is not allowed operator for Integers"
    end

    vars = @executed_list
    res = ""

    if @op == "="
      temp_op = "=="
    elsif @op == "^"
      temp_op = "**"
    elsif @op == "!" and @executed_list.length == 1
      return (not @executed_list[0])
    else
      temp_op = @op
    end

    vars.each do |val|
      res += val.to_s + temp_op
    end

    res.gsub!(/\W+$/, "")
    res_num = eval(res)
    res_num
  end
end


class If_statement < Valid
  #If statements
  def initialize(statement, executables, eif_list = Default.new, else_statement = Default.new)
    @statement = statement
    @executables = executables
    @eif_list = eif_list
    @else_statement = else_statement
  end

  def execute
    Dopo.new_scope(open = true)
    has_run = Default.new
    run = false

    #check if-statement condition
    if @statement.execute
      has_run = @executables.execute
      run = true
    #check elsif-statements conditions
    elsif not @eif_list.is_a? Default and @eif_list != nil
      has_run = @eif_list.execute
    end

    #check else-statement is going to be called
    if has_run.is_a? Default and not @else_statement.is_a? Default and !run
      has_run = @else_statement.execute
    end

    Dopo.destroy_scope
    0
  end
end


class Else_if_list < Valid
  #Chain of else_if-s
  def initialize(eif,eif_list = Default.new)
    @eif = eif
    @eif_list = eif_list
  end

  def execute
    #Executes else-ifs until a Default is found
    ret = @eif.execute

    if ret.is_a? Default
      ret = @eif_list.execute
    end

    ret
  end
end


class Else_if_statement < Valid
  #Single else if
  def initialize(call, valid_list)
    @call = call
    @valid_list = valid_list
  end

  def execute
    #Execute "call" as the condition for running valid list
    ret = Default.new

    if @call.execute
      ret = @valid_list.execute
    end

    ret
  end
end


class Else_statement < Valid
  #Else statement
  def initialize(valid_list)
    @valid_list = valid_list
  end

  def execute
    @valid_list.execute
  end
end


class Dictionary < Valid
  #Represent a traditional dictionary were pair and pairs are the mapped keys and values
  def initialize(pair = nil, pairs = nil)
    @pair = pair
    @pairs = pairs
  end

  def execute
    ret_dict = {}

    if @pair != nil
      ret_dict = @pair.execute.merge(ret_dict)
      if @pairs != nil
        ret_dict = @pairs.execute.merge(ret_dict)
      end
    end

    ret_dict
  end
end


class Pair < Valid
  #Used in Dictionary class
  #Map keys to values
  def initialize(value, key)
    @value = value
    @key = key
  end

  def execute
    val_ex = @value.execute
    name_ex = @key.execute
    ret_pair = {name_ex => val_ex}
    ret_pair
  end
end


class List < Valid
  #Traditional List class to store elements
  def initialize(element_list = [])
    @element_list = element_list
  end

  def get_name
    @element_list
  end

  def execute
    ex_list = @element_list.execute
    ret_list = Array.new
    ex_list.each { |e| ret_list << e }
    ret_list
  end
end


class Iterate < Valid
  #To be able to get value from index of classes string_c, Dictionary and List
  attr_reader :lookup, :call
  def initialize(call, lookup)
    @call = call
    @lookup = lookup
  end

  def get_name
    @call
  end

  def execute
    list = @call.execute
    index = @lookup.execute

    if list.is_a? Hash
      if list.key? index
        ret = list[index]
      else
        raise Exception.new "Key error, #{index} not in #{list}"
      end
    elsif list.is_a? Array or list.is_a? String
      if list.length-1 >= index and -(list.length) <= index
        ret = list[index]
      else
        raise Exception.new "Index error, #{index} out of range in #{list}"
      end
    end

    ret
  end
end


class Variable < Call
  #Represent a variable
  def initialize(name)
    @name = name
  end

  def get_name
    @name
  end

  def execute
  #Finds value for variable call

    found_var = false

    ret = Default.new
    #start from most nestle scope and find variable with name and return its value
    Dopo.scopes.reverse_each.with_index do |scope, i|
      if scope.contains_var(@name)
        ret = scope.get_var(@name)
        found_var = true
        break
      end
    end

    #if variable is not found
    if not found_var
      Exception.new(raise"Could not found variable with name" + ' "' + "#{@name}" + '"')
    end

    ret
  end
end


class Nil_c < Valid
  #Represent an empty value
  def initialize
  end

  def execute
    nil
  end
end


class Number_c < Call
  #Datatype for a float and integer
  def initialize(num)
    @num = num
  end

  def execute
    @num
  end
end


class Bool_c < Call
  #Datatype for a bool
  def initialize(bool)
    @is_true = bool
  end

  def execute
    @is_true
  end
end


class String_c < Call
  #Datatype for a string
  def initialize(str)
    @str = str
  end

  def execute
    @str
  end
end
