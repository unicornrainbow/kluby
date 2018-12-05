
vars ||= {}

# vars['def']  = Proc.new do |bnd, a, b|
#   vars[a.to_s] = evl(bnd,b)
# end
vars['def']  = Proc.new do |bnd,args|
  a = args.first
  b = args.rest.first
  vars[a.to_s] = evl(bnd,b)
end

# vars['send'] = Proc.new do |bnd,a,*b|
#   a = evl(bnd, a)
#   b = b.map {|a| evl(bnd,a)}.to_a
#   a.send *b
# end
vars['send'] = Proc.new do |bnd,args|
  a = evl(bnd, args.first)
  b = args.rest.map {|a| evl(bnd,a)}.to_a
  a.send *b
end

vars['fn'] = Proc.new do |bnd,args|
  Kluby::Fn.new(args.first, args.rest.first)
end
#
vars['macro'] = Proc.new do |bnd,args|
  Kluby::Macro.new(args.first, args.rest.first)
end

vars['print'] = Proc.new do |bnd,args|
  q = args.map {|a| evl(bnd,a)}
  print *q
end
# vars['print'] = Proc.new do |bnd,*args|
#   q = args.map {|a| evl(bnd,a)}
#   print *q
# end

vars['list'] = Proc.new do |bnd,args|
  args.map{|a| evl(bnd,a)}
end
# vars['list'] = Proc.new do |bnd,*args|
#   args = args.map{|a| evl(bnd,a)}
#   args = args.reverse
#   list = List.new(args.shift)
#   args.reduce(list, &:<<)
# end

class Kluby
end

class List

  def initialize(head, tail=nil)
    @head = head
    @tail = tail
  end

  def peek
    @head
  end

  def <<(val)
    List.new(val, self)
  end

  def pop
    @tail
  end

  def conj(*val)
    val.reduce(self) do |memo, i|
      memo.push i
    end
  end

  def first
    @head
  end

  def rest
    @tail
  end

  def join(delimiter=' ')
    if rest
      first.to_s + delimiter + rest.join
    else
      first.to_s
    end
  end

  def to_s
    "(#{join})"
  end

  def inspect
    "(#{map(&:inspect).join})"
  end

  def to_a
    if rest
      [first] + rest.to_a
    else
      [first]
    end
  end

  def map(&block)
    q = @tail.map(&block) if @tail
    List.new block.call(@head), q
  end

  def reduce(memo=nil)
    memo = @tail.reduce(memo, &block) if @tail
    block.call(memo, @head)
  end

  def each(&block)
    @tail.each(&block) if @tail
    block.call(@head)
  end

  def call(bnd, *args)
    case peek
    when Kluby::Symbol.fn
      invoke bnd, self,
        args.map {|a| evl(bnd,a)}
    when Kluby::Symbol.macro
      evl bnd, invoke(bnd, self, args)
    end
  end

  def args
    # First glider
    each do |a|
      break a if a.is_a? Vector
    end
  end

  def body
    # First list
    each do |a|
      break a if a.is_a? List
    end
  end

end

class Vector

  def initialize(head, tail=nil)
    @head = head
    @tail = tail
  end

  def peek
    @head
  end

  def <<(val)
    Vector.new(val, self)
  end

  def pop
    @tail
  end

  def conj(*val)
    val.reduce(self) do |memo, i|
      memo.push i
    end
  end

  def first
    @first ||= @tail ? @tail.first : @head
  end

  def rest
    @rest ||= @tail ? Vector.new(@head, @tail.rest) : nil
  end

  # def join(delimiter=' ')
  #   if rest
  #     first.inspect + delimiter + rest.join.to_s
  #   else
  #     first.inspect
  #   end
  # end

  def join(delimiter=' ')
    if rest
      first.to_s + delimiter + rest.join
    else
      first.to_s
    end
  end

  def to_s
    # "[#{join}]"
    inspect
  end

  alias :object_inspect :inspect
  def inspect
    "[#{map(&:inspect).join}]"
  end

  def to_a
    if rest
      [first] + rest.to_a
    else
      [first]
    end
  end

  def map(&block)
    q = @tail.map(&block) if @tail
    Vector.new block.call(@head), q
  end

  def reduce(memo=nil)
    memo = @tail.reduce(memo, &block) if @tail
    block.call(memo, @head)
  end

  def each(&block)
    @tail.each(&block) if @tail
    block.call(@head)
  end
end

class Kluby::Symbol
  def initialize(value)
    @value = value
  end

  def to_s
    @value
  end

  def self.method_missing(name)
    new(name.to_s)
  end

  alias :object_inspect :inspect

  def inspect
    @value
  end

  def ==(value)
    value.class == self.class &&
      @value == value.to_s
  end
end

class Quoted
  def initialize(value)
    @value = value
  end

  def unquote
    @value
  end

  def to_s
    "'#{@value.to_s}"
  end

  def inspect
    "'#{@value.inspect}"
  end
end

class Kluby::Fn
  attr_reader :args, :body
  def initialize(args, body)
    @args = args
    @body = body
  end

  def call(bnd, args)
    invoke bnd, self,
      args.map {|a| evl(bnd,a)}
  end
end

class Kluby::Macro
  attr_reader :args, :body
  def initialize(args, body)
    @args = args
    @body = body
  end

  def call(bnd, args)
    evl bnd, invoke(bnd, self, args)
  end
end

class Kluby::Binding
  def initialize(root, keys, vals)
    @root = root # Root bnd
    @keys = keys
    @vals = vals
    @kv = keys.map(&:to_s).to_a.zip(vals.to_a).to_h
  end

  def [](key)
    key = key.to_s
    val = @kv[key]
    if val
      val
    elsif @root
      @root[key]
    end
  end
end

class RootBinding
  def initialize(vars={})
    @vars = vars
  end

  def [](key)
    key = key.to_s
    val = @vars[key]
    if val
      val
    else
      eval(key) rescue nil
    end
  end

  def []=(key, val)
    @vars[key] = val
  end
end

class Kluby
  class Syntax; end
  class LParen  < Syntax; end
  class LBrack  < Syntax; end
  class SingleQ < Syntax; end
end

def parse(s, stack=[])
  word = nil
  string = nil
  number  = /^\d+$/
  keyword = /^:.+$/
  s.split('').each do |c|
    # if string
    #   if c == '"'
    #     if string.last == "\\"
    #       string.pop
    #       string << c
    #     else
    #       stack.pop
    #       stack << string.join
    #       string = nil
    #     end
    #   else
    #     string << c
    #   end
    # else

    case c
    when '(' then
      stack << Kluby::LParen
    when '[' then
      stack << Kluby::LBrack
    when "'" then
      stack << Kluby::SingleQ
    # when '(', '[', "'" then
    #   stack << c
    # when '"' then
    #   string = []
    #   stack << c
    when ')' then
      word = stack.pop unless word
      if word == Kluby::LParen
        stack << List.new
        break
      end

      word = case word
      when number then
        word.to_i
      when keyword then
        word[1,65].to_sym
      when /^.+$/ then
        Kluby::Symbol.new(word)
      else
        word
      end

      if stack.last == Kluby::SingleQ
        stack.pop
        word = Quoted.new(word)
      end

      list = List.new(word)

      word = stack.pop
      until word == Kluby::LParen
        list = list << word
        word = stack.pop
      end

      if stack.last == Kluby::SingleQ
        stack.pop
        list = Quoted.new(list)
      end

      word = nil
      stack << list
    when ']' then
      word = stack.pop unless word
      if word == Kluby::LBrack
        stack << Vector.new
        break
      end

      case word
      when number then
        word = word.to_i
      when keyword then
        word = word[1,65].to_sym
      when /^.+$/ then
        word = Kluby::Symbol.new(word)
      end

      if stack.last == Kluby::SingleQ
        stack.pop
        word = Quoted.new(word)
      end

      tmp = []
      until word == Kluby::LBrack
        tmp << word
        word = stack.pop
      end
      word = nil

      vector = Vector.new(tmp.pop)
      until tmp.empty?
        vector = vector << tmp.pop
      end

      if stack.last == Kluby::SingleQ
        stack.pop
        vector = Quoted.new(vector)
      end

      stack << vector

    when ' ', "\n" then
      if word
        word = case word
        when number then
          word.to_i
        when keyword then
          word[1,65].to_sym
        else
          Kluby::Symbol.new(word)
        end

        if stack.last == Kluby::SingleQ
          stack.pop
          word = Quoted.new(word)
        end

        stack << word
        word = nil
      end
    else
      if word
        word << c
      else
        word = c
      end
    end
  end

  if word
    word = case word
    when number then
      word.to_i
    when keyword then
      word[1,65].to_sym
    when /^.+$/ then
      Kluby::Symbol.new(word)
    else
      word
    end

    if stack.last == Kluby::SingleQ
      stack.pop
      word = Quoted.new(word)
    end

    stack << word
    word = nil
  end
  # end

  stack
end

def evl(bnd, exp)
  case exp
  when List then
    # q = exp.first
    # if q == Kluby::Symbol.fn,
    #         Kluby::Symbol.macro
    # if q == Kluby::Symbol.fn ||
    #    q == Kluby::Symbol.macro
    #   exp
    # else
    q = evl(bnd, exp.first)
    args = exp.rest
    q.call(bnd, args)
    # end
    # if exp.fn? || exp.macro?
    #   exp
    # end
    # q = evl(bnd, exp.first)
    # args = exp.rest
    # q.call(bnd, *args.to_a)
    # case q
    # when Kluby::Fn then
    #   invoke bnd, q,
    #     args.map {|a| evl(bnd,a)}
    # when Kluby::Macro then
    #   evl bnd, invoke(bnd, q, args)
    # when Proc then
    #   q.call(bnd, args)
    # end
  when Vector then
    exp.map {|a| evl(bnd,a)}
  when Kluby::Symbol then
    bnd[exp.to_s]
  when Quoted then
    exp.unquote
  else
    exp
  end
end

def invoke(bnd, k, args)
  bnd = Kluby::Binding.new(
    bnd, k.args, args)
  evl bnd, k.body
end

def kluby(vars, s=nil)
  if s
    result =
      parse(s.chomp).map do |exp|
        evl vars, exp
      end
    result[-1]
  else
    k = []
    loop do
      print "kluby> "
      k = parse(gets.chomp, k)
      r = nil

      # puts k
      exp = k.shift
      while exp
        if exp.class == Class &&
          exp.superclass == Kluby::Syntax then
          k.unshift exp
          exp = nil
        else
          r = evl vars, exp
          exp = k.shift
        end
      end

      puts "=> #{r.inspect}" if k.empty?
    end
  end
end

root_binding = RootBinding.new(vars)
kluby root_binding, <<EOK
  (def puts
    (fn [a] (print a "\n")))

  (def +
    (fn [a b] (send a :+ b)))

  (def *
    (fn [a b] (send a :* b)))

  (def defmacro
    (macro [name args body]
      (list 'def name
        (list 'macro args body))))

  (defmacro defn
    [name args body]
    (list 'def name
      (list 'fn args body)))

  (defn / [a b] (send a :/ b))

  (defn peek [a]
    (send a :peek))

EOK

kluby root_binding

def new(klass, *args)
  klass.new(*args)
end

class Kluby::Ns
end

user = new Kluby::Ns, :user
puts user
