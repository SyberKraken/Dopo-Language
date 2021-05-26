#!/usr/bin/env ruby

require_relative "rdparse"
require_relative "Classes"

class Dopo
  #Parser for language
  #Stores scopes for programs with helper functions

  @@scopes = [Scope.new]

  ##################### TESTING PURPOSES ####################################################
  def self.scopes_to_string_print
    @@scopes.each_with_index do |var, i| print("Scope #{i}\n"); print(var); print("\n") end
  end

  def self.clean_scopes
    @@scopes = [Scope.new]
  end
  ##############################################################################################

  def self.scopes
    @@scopes
  end

  def self.new_scope(open = false)
    if open
      @@scopes << Scope.new(open)
    else
      @@scopes << Scope.new()
    end
  end

  def self.destroy_scope
    @@scopes.pop()
  end

  def self.scope_from_index(index)
    @@scopes[index]
  end

  def self.is_open
    @@scopes[-1].is_open
  end

  def self.is_looping
    @@scopes[-1].is_loop
  end

  def self.scopes_length
    @@scopes.length
  end

  def Dopo.scope_append(name, data, func = nil, open=false)
    #Function finds the closest existing variable in @@scopes and appends a variable
    #or function.
    i = -1
    if @@scopes[i].is_open
      #Note index in loop = -|i| -1
      @@scopes.reverse.each_with_index do |scope,j|
        if scope.contains_var(name)
          i = scopes_length - j - 1
          break
        end
      end
    end
    #Variables
    if func == nil
      @@scopes[i].insert_var(name,data)
    else
    #Functions
      @@scopes[i].insert_func(name,data,func,open)
    end

    data
  end

  def initialize
    @dopo_parser = Parser.new("Dopo parser") do
      token(/(#)(.|\n)+?(#)/)
      token(/"[^"]*"/)   {|m| m}
      token(/include/) {|m| m}
      token(/nil/)       {|m| m}
      token(/>=/)       {|m| m}
      token(/e>/)       {|m| m}
      token(/e\?/)       {|m| m}
      token(/¤\+/)       {|m| m}
      token(/!¤/)       {|m| m}
      token(/\*/)       {|m| m}
      token(/<-/)       {|m| m}
      token(/->/)       {|m| m}
      token(/<=/)       {|m| m}
      token(/!=/)       {|m| m}
      token(/[A-Za-z][\wåäöÖÄÅ$£]*\n/) {|m| m[0..-2]}
      token(/[A-Za-z][\wåäöÖÄÅ£$]*/) {|m| m}
      token(/[0-9]+\n/) {|m| m[0..-2]}
      token(/\s+/)
      token(/\d+/)      {|m| m}
      token(/./)        {|m| m }

      start :program do
        match(:valid_list){|vl| vl.execute}
      end

      rule :valid_list do
        match(:valid, :valid_list) {|v,vl| Valid_list.new(v, vl)}
        match(:valid) {|v| Valid_list.new(v)}
      end

      rule :valid do
        match(:include) {|i| i}
        match(:control) {|c| c}
        match(:assignment) {|a| a}
        match(:call) {|c| c}
      end

      rule :include do
        match("include", :include_list) {|_,i| Includer.new(i,self)}
      end

      rule :include_list do
        match(:string, :include_list) {|s,i| [s, i]}
        match(:string) {|s| [s]}
      end

      rule :control do
        match(:return) {|r| r}
        match(:abort) {|a| a}
        match(:continue) {|c| c}
        match(:for_each) {|f| f}
        match(:while) {|w| w}
        match(:if) {|i| i}
      end

      rule :return do
        match(:variable_assignment, '<-') {|v,_| Return_statement.new(v)}
        match(:call, '<-') {|c,_| Return_statement.new(c)}
        match('<-') {Return_statement.new(Nil_c.new)}
      end

      rule :abort do
        match('!¤' ) {Abort_statement.new}
      end

      rule :continue do
        match('¤+') {Continue_statement.new}
      end

      rule :for_each do
        match(:call, '¤+', :name, :block) {|c,_,n,b| For_each.new(c,b,n)}
      end

      rule :while do
        match(:call, '¤', :block) {|c,_,b| While.new(c,b)}
      end

      rule :if do
        match(:call, '?', :block, :else_if_list, :else) {|c,_,b,ei,e| If_statement.new(c,b,ei,e)}
        match(:call, '?', :block, :else_if_list) {|c,_,b,ei| If_statement.new(c,b,ei)}
        match(:call, '?', :block, :else) {|c,_,b,e| If_statement.new(c,b,nil,e) }
        match(:call, '?', :block) {|c,_,b| If_statement.new(c,b)}
      end

      rule :else_if_list do
        match(:else_if, :else_if_list) {|ei,eil| Else_if_list.new(ei,eil)}
        match(:else_if) {|e| e}
      end

      rule :else_if do
        match(:call, 'e?', :block) {|c,_,b| Else_if_statement.new(c,b)}
      end

      rule :else do
        match('e>', :block) {|_,b| Else_statement.new(b)}
      end
      rule :assignment do
        match(:function_assignment) {|f| f}
        match(:variable_assignment) {|v| v}
      end

      rule :function_assignment do
        match('(', :name_list, ')', '@', :name, '*', :block) {|_,nl,_,_,n,_,b| Assignment.new(nl,n,b,true)}
        match('(', :name_list, ')', '@', :name, :block) {|_,nl,_,_,n,b| Assignment.new(nl,n,b)}
        match('(', ')', '@', :name, '*', :block) {|_,_,_,n,_,b| Assignment.new([],n,b,true)}
        match('(', ')', '@', :name, :block) {|_,_,_,n,b| Assignment.new([],n,b)}
      end

      rule :block do
        match('{', :valid_list, '}') {|_,v,_| v}
        match('{','}') {Nil_c.new}
      end

      rule :name_list do
        match(:parameter_name, ',', :name_list) {|pa,_, n| Name_list.new(pa, n)}
        match(:parameter_name) {|pa| pa}
      end

      rule :parameter_name do
        match(:letter, :char_list) {|l,c| Name_list.new(l+c)}
        match(:letter) {|l| Name_list.new(l)}
      end

      rule :variable_assignment do
        match('(', :call, ',' , :index, ')', '@') {|_, c,_, i, _, _|  Assignment.new(c,i) }
        #Math works in right to left, assignment operator dominant
        match('(', :call, ',' , :name, ')', :math_op,'@') {|_,c,_,n,_,m,_| Assignment.new(Operator_expr.new(m, Param_list.new(n,c)), n)}
        match('(', :call, ',' , :name, ')','@') {|_,c,_,n,_,_| Assignment.new(c,n) }
        match('(', :name, ')', '@') {|_,n,_,_| Assignment.new(Nil_c.new,n) }
      end

      rule :call do
        match(:user_input) {|u| u}
        match(:print) {|pr| pr}
        match('(', :param_list, ')', :name) {|_,pa,_,n| Call.new(n, pa)}
        match('(', :param_list, ')', :op) {|_,pa,_,o| Operator_expr.new(o, pa)}
        match('(', ')', :name) {|_,_,n| Call.new(n)}
        match(:index) {|i|i}
        match(:var) {|v|v}
      end

      rule :param_list do
        match(:call, ',', :param_list) {|c,_,pa| Param_list.new(c, pa)}
        match(:call) {|c| Param_list.new(c)}
      end

      rule :index do
        match('[',:call, ']', :call) {|_,cl,_,c| Iterate.new(c,cl)}
      end

      rule :print do
        match('(', :call, ')', 'p') {|_,c,_,_|Print.new(c)}
        match('(', ')', 'p') {|_,_,_|Print.new()}
      end

      rule :user_input do
        match('(', :call ,')','g') {|_,c,_,_| User_input.new(self, c) }
        match('(',')','g') {User_input.new(self)}
      end

      rule :op do
        match(:bolean_op) {|b| b}
        match(:math_op) {|m| m}
      end

      rule :bolean_op do
        match(/>=/) {|o| o}
        match(/->/) {|o| o}
        match(/<=/) {|o| o}
        match(/!=/) {|o| o}
        match(/[\&\|\!=<>]/) {|o| o}
      end

      rule :math_op do
        match(/\+|-|\*|\/|%|\^/) {|o| o}
      end

      rule :index do
        match('[',:call, ']', :call) {|_,cl,_,c| Iterate.new(c,cl)}
      end

      rule :var do
        match(:nil) {|n| n }
        match(:dictionary) {|d| d }
        match(:list) {|l| l}
        match(:string) {|s| s}
        match(:bool) {|b| Bool_c.new(b)}
        match(:name) {|n| n}
        match(:number) {|n| Number_c.new(n)}
      end

      rule :nil do
        match ('nil') {Nil_c.new}
      end

      rule :dictionary do
        match('[', :mapping_list, ']'){|_,m,_| m}
        match('[', '@' ,']'){Dictionary.new}
      end

      rule :mapping_list do
        match(:mapping, ',', :mapping_list) {|m,_,ml| Dictionary.new(m,ml)}
        match(:mapping) {|m| Dictionary.new(m)}
      end

      rule :mapping do
        match(:call, '@', :call) {|cv,_,cn| Pair.new(cv,cn)}
      end

      rule :list do
        match('[', :param_list, ']') {|_,p,_| List.new(p)}
        match('[', ']') {|_,_| List.new}
      end

      rule :string do
        match(/"[^"]*"/) {|s| String_c.new("#{s[1..-2]}")}
        match('"', '"') {|s| String_c.new("#{s}")}
      end

      rule :number do
        match(:float) {|f| f}
        match(:int) {|i| i}
      end

      rule :float do
        match('-',  :digit_list, '.', :digit_list) {|_, d, _, dl| -(d + "." + dl).to_f}
        match(:digit_list, '.', :digit_list) {|d, _, dl| (d + "." + dl).to_f }
      end

      rule :int do
        match('-', :digit_list) {|_, d| -(d.to_i)}
        match(:digit_list) {|d| d.to_i}
      end

      rule :bool do
        match('true') {true}
        match('false') {false}
        match('T') {true}
        match('F') {false}
      end

      rule :name do
        match(/[A-Za-z][\wåäöÖÄÅ]*/) {|n| Variable.new(n)}
      end

      rule :char_list do
        match(:char, :char_list) {|c, cl| c + cl}
        match(:char) {|c| c}
      end

      rule :char do
        match(:letter) {|l| l}
        match(:digits) {|d| d}
        match(:symbol) {|s| s}
      end

      rule :letter do
        match(/[A-Za-z]/) {|l| l}
      end

      rule :digit_list do
        match(:digits, /\n/) {|d,_| d }
        match(:digits) {|d| d}
      end

      rule :digits do
        match(/[0-9]+/) {|d| d}
      end

      rule :symbol do
        match(/[$£]|å|ä|ö|Å|Ä|Ö/) {|s| s}
      end
    end
  end

  def start(runstring = false)
    #runs the language on given string,file or in interactive mode if no string or file is given.
    log(false) # set to true to track lexer and parsing process from rdparse

    if runstring
      @dopo_parser.parse runstring
    else
      if ARGV.length >= 1
        #File read mode
        lines = File.read("stdlib", :encoding => 'utf-8')
        @dopo_parser.parse lines
        lines = File.read(ARGV[0], :encoding => 'utf-8')
        @dopo_parser.parse "([],CIN)@"
        ARGV[1..-1].each do |arg|
          @dopo_parser.parse("((\"#{arg}\",CIN)+,CIN)@")
        end
         @dopo_parser.parse lines
      else
        while true
          #Interactive mode
          puts "=> #{@dopo_parser.parse gets.chomp}"
        end
      end
    end
  end

  def log(state = false)
    if state
      @dopo_parser.logger.level = Logger::DEBUG
    else
      @dopo_parser.logger.level = Logger::WARN
    end
  end
end

if __FILE__ == $0
  pf = Dopo.new
  pf.start
end
