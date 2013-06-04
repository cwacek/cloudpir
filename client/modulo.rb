class InversionError < RuntimeError
end

module Modulo

  class << self

  # Returns an array of the form (x, y), a, b]where
  # x + by = gcd(x, y)
  #
  # @param [Integer] x
  # @param [Integer] y
  # @return [Array<Integer>]
  def gcdext(x, y)
    if x < 0
      g, a, b = gcdext(-x, y)
      return [g, -a, b]
    end
    if y < 0
      g, a, b = gcdext(x, -y)
      return [g, a, -b]
    end
    r0, r1 = x, y
    a0 = b1 = 1
    a1 = b0 = 0
    until r1.zero?
      q = r0 / r1
      r0, r1 = r1, r0 - q*r1
      a0, a1 = a1, a0 - q*a1
      b0, b1 = b1, b0 - q*b1
    end
    [r0, a0, b0]
  end

  def invert(num, mod)
    g, a, b = gcdext(num, mod)
    unless g == 1
      raise ZeroDivisionError.new("#{num} has no inverse modulo #{mod}")
    end
    a % mod
  end

  end
end


class Matrix

  def mod_add_row_in_place(r,v, mod=nil)
    added = row(r) + v
    newrow_vector = added.map do |e|
      mod.nil? ? e : e % mod
    end
    rows[r] = newrow_vector.to_a
  end

  def mod_multiply(m2,mod)
    if column_size != m2.row_size
      raise RuntimeError,"Matrix dimensions invalid for multiplication"
    end

    Matrix.build(row_size,m2.column_size) do |r,c|
      mult = row(r).inner_product m2.column(c)
      if mult < 0 
        raise RuntimeError, "Don't know how to handle negative > mod" if (-1 * mult) > mod
        mult
      else
        mult % mod
      end
    end
  end

  def mod_multiply_row(rownum, k, mod=nil)
    newrow = row(rownum).map do |v|
      case mod.nil?
      when true
        val = v *k
      when false
        val = (v * k) % mod
      end
      val
    end
  end

  def mod_multiply_row_in_place(rownum,k,mod=nil)
    rows[rownum] = mod_multiply_row(rownum,k,mod).to_a
  end

  def invert_modulo(mod)
      extended = Matrix.build(row_size,column_size * 2) do |r,c|
        case c > column_size - 1
        when true
          (r == c- (column_size )) ? 1 : 0
        when false
          element( r,c )
        end
      end

      for step in (0...row_size)
        #Get a 1 in the diagonal
        # Special case if it's zero, we need to add from another row
        if extended[step,step] == 0
          if step != 0
            # We'll use row 0
            begin
              mult = Modulo.invert(extended[ 0,step ],mod)
            rescue ZeroDivisionError
              #puts "Cannot invert #{self}"
              raise InversionError
            end
            to_add = extended.row(0) * mult
            extended.mod_add_row_in_place(step,to_add,mod)
          else
            # We'll use the next row
            begin
              mult = Modulo.invert(extended[ step+1,step ],mod)
            rescue ZeroDivisionError
              #puts "Cannot invert #{self}"
              raise InversionError
            end
            to_add = extended.row(step+1) * mult
            extended.mod_add_row_in_place(step,to_add,mod)
          end

          if step > 0 and extended[step,0] != 0
            raise InversionError
          end
        end

        begin
          mult = Modulo.invert(extended[step,step],mod)
        rescue ZeroDivisionError
          #puts "Cannot invert #{self}"
          throw
        end
        extended.mod_multiply_row_in_place(step, mult, mod)

        #Pivot the column
        for r in (0...extended.row_size)
          next if r == step
          multiplier = mod - extended.element(r,step)
          # WE multiply our first row by the second row, column 1 times -1
          to_add = extended.row(step) * multiplier
          extended.mod_add_row_in_place(r,to_add,mod)
        end
      end

      inverted = (0...row_size).map {|i| extended.column(i+row_size)}
      return Matrix.columns inverted
  end

end

