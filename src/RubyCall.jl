module RubyCall
	export rbModule

	libruby=dlopen("libruby")

	ruby_init = dlsym(libruby, :ruby_init)
	ccall((:ruby_init, :libruby) , Void, ())

	 code="Math.sqrt(9)"
	 rb_eval_string = dlsym(libruby, :rb_eval_string)

	 rb_num2int = dlsym(libruby, :rb_num2int)
	 rb_num2dbl = dlsym(libruby, :rb_num2dbl)

	 const FIXNUM_MAX = typemax(Int64) >> 1
	 const FIXNUM_MIN = typemin(Int64) >> 1
	 function rb_int2num(x::Int64) 
	 	if x < FIXNUM_MAX + 1 && x >= FIXNUM_MIN
	 		return rb_int2fix(x)
	 	else 
	 		return ccall(rb_int2big, Ptr{Void}, (Cint, ), x)
	 	end
	 end 

	 rb_int2fix(x::Int64) = reinterpret (Ptr{Void}, x << 1 | 0x01 )

	rb_define_module = dlsym(libruby, :rb_define_module)
	rb_funcall = dlsym(libruby, :rb_funcall)

	rb_intern = dlsym(libruby, :rb_intern)
	rb_int2big = dlsym(libruby, :rb_int2big)


  #############################################

	type RbValue
		VALUE::Ptr{Void}
	end

	RbValue(x) = RbValue(convert_arg(x))

	#This is VALUE* points to 
	immutable RBasic 
    	flags::Ptr{Void};
    	klass::Ptr{Void};
	end

	#Wrapper around a Ruby Array
	type RbArray <: AbstractArray
		VALUE::Ptr{Void}
	end

	Base.size(x::RbArray) = (rb_call(x.VALUE, :length) ,)
	Base.ndims(x::RbArray) = 1

	function rbModule(mod::Symbol) 
		v = ccall(rb_define_module, Ptr{Void}, (Ptr{Uint8},), string(mod))
		return RbValue(v)
	end

	function Base.getindex(v::RbValue, method::Symbol)
		return (args...) -> rb_call(v.VALUE, method, args...)
	end

	function Base.getindex(v::RbArray, index::Int64)
		r = ccall((:rb_ary_entry, :libruby), Ptr{Void}, (Ptr{Void}, Clong), v.VALUE, index-1)
		return convert_result(r)
	end

	# Base.show(io::IO, x::RbArray) = write(io,"$(length(x)) element RbArray")
	Base.showarray(io::IO, x::RbArray; kw...) = write(io, "$(length(x)) element RbArray")

	rb_respond_to(recv::Ptr{Void}, ID::Ptr{Void}) = ccall((:rb_respond_to, :libruby), Cint, (Ptr{Void}, Ptr{Void}), recv, ID) == 1

	function rb_call(recv::Ptr{Void}, method::Symbol, args...)
		ID = ccall((:rb_intern, :libruby), Ptr{Void}, (Ptr{Uint8},), string(method))
		if !rb_respond_to(recv, ID) throw(ErrorException("NoSuchMethodError: $method"))  end
		converted_args = convert_args(args...)
		
		if length(args) == 0
			r = ccall(rb_funcall, Ptr{Void}, (Ptr{Void}, Ptr{Void}, Cint ), recv, ID, 0)
		end 

		if length(args) == 1
			r = ccall(rb_funcall, Ptr{Void}, (Ptr{Void}, Ptr{Void}, Cint, Ptr{Void}), recv, ID, 1, converted_args[1])
		end 

		if length(args) == 2
			r = ccall(rb_funcall, Ptr{Void}, (Ptr{Void}, Ptr{Void}, Cint, Ptr{Void}, Ptr{Void}), recv, ID, 2, converted_args[1], converted_args[2])
		end 

		return convert_result(r)
	end

	function convert_args(args...) 
		ret = Array(Ptr{Void}, length(args))
		for (i,a) in enumerate(args) 
			ret[i] = convert_arg(a)
		end
		return ret
	end

	convert_arg(arg::Ptr{Void}) = arg
	convert_arg(arg::RbValue) = arg.VALUE
	convert_arg(arg::Int64) = rb_int2num(arg)
	convert_arg(arg::ASCIIString) = ccall((:rb_usascii_str_new, :libruby), Ptr{Void}, (Ptr{Uint8}, Cint), arg, length(arg))
	convert_arg(arg::UTF8String) = ccall((:rb_utf8_str_new, :libruby), Ptr{Void}, (Ptr{Uint8}, Cint), arg, sizeof(arg))
	convert_arg(arg::String) = convert_arg(utf8(arg))
	function convert_arg{T}(arg::AbstractArray{T,1}) 
		arr = ccall((:rb_ary_new2, :libruby), Ptr{Void}, (Clong,), length(arg))
		for (i, a ) in enumerate(arg) 
			ccall((:rb_ary_store, :libruby), Void, (Ptr{Void}, Clong, Ptr{Void}), arr, i-1, convert_arg(a))
		end
		return arr
	end

	function convert_result(r::Ptr{Void}) 
		TYP = rb_type(r)
		if TYP == RUBY_T_FIXNUM 
			return ccall((:rb_num2long, :libruby), Clong, (Ptr{Void}, ) , r)
		elseif TYP == RUBY_T_FLOAT
			return ccall(rb_num2dbl, Cdouble, (Ptr{Void}, ), r)
		elseif TYP == RUBY_T_TRUE
			return true
		elseif TYP == RUBY_T_FALSE
			return false
		elseif TYP == RUBY_T_UNDEF
			return nothing
		elseif TYP == RUBY_T_NIL
			return nothing
	    elseif TYP == RUBY_T_ARRAY
	    	return RbArray(r)
		else 
			return RbValue(r)
		end
	end

	function rb_type(obj::Ptr{Void})

		if IMMEDIATE_P(obj) 
			if FIXNUM_P(obj) return RUBY_T_FIXNUM; end
	        if FLONUM_P(obj) return RUBY_T_FLOAT; end 
	        if reinterpret(Int64, obj) == RUBY_Qtrue  return RUBY_T_TRUE end
	        if SYMBOL_P(obj)  return RUBY_T_SYMBOL end 
	        if reinterpret(Uint64, obj) == RUBY_Qundef  return RUBY_T_UNDEF end	
	    elseif !RTEST(obj)
	    	if (reinterpret(Uint64, obj) == RUBY_Qnil)   return RUBY_T_NIL end
		 	if (reinterpret(Uint64, obj) == RUBY_Qfalse) return RUBY_T_FALSE end
		end
		return BUILTIN_TYPE(obj)
	end

	IMMEDIATE_P(x::Ptr{Void}) =  (reinterpret(Uint64, x) & RUBY_IMMEDIATE_MASK) > 0x00
	FIXNUM_P(x::Ptr{Void}) =  (reinterpret(Uint64, x) & RUBY_FIXNUM_FLAG) > 0x00
	FLONUM_P(x::Ptr{Void}) = (reinterpret(Uint64, x) & RUBY_FLONUM_MASK) == RUBY_FLONUM_FLAG
	SYMBOL_P(x::Ptr{Void}) = ((x) & ~( ~0x00 << RUBY_SPECIAL_SHIFT)) == RUBY_SYMBOL_FLAG
 	RTEST(x::Ptr{Void}) = !(( reinterpret(Uint64, x) & ~RUBY_Qnil) == 0)
 	NIL_P(x::Ptr{Void}) = !(reinterpret(Uint64, x) != RUBY_Qnil)

 	function BUILTIN_TYPE(x::Ptr{Void}) 
 			y = convert(Ptr{RBasic}, x)
 			r = unsafe_load(y)
 			reinterpret(Uint64, r.flags) & RUBY_T_MASK
 			#(int)(((struct RBasic*)(x))->flags & T_MASK)
 	end

	const 	 RUBY_T_NONE   = 0x00
	const    RUBY_T_OBJECT = 0x01
	const    RUBY_T_CLASS  = 0x02
	const    RUBY_T_MODULE = 0x03
	const    RUBY_T_FLOAT  = 0x04
	const    RUBY_T_STRING = 0x05
	const    RUBY_T_REGEXP = 0x06
	const    RUBY_T_ARRAY  = 0x07
	const    RUBY_T_HASH   = 0x08
	const    RUBY_T_STRUCT = 0x09
	const    RUBY_T_BIGNUM = 0x0a
	const    RUBY_T_FILE   = 0x0b
	const    RUBY_T_DATA   = 0x0c
	const    RUBY_T_MATCH  = 0x0d
	const    RUBY_T_COMPLEX  = 0x0e
	const    RUBY_T_RATIONAL = 0x0f

	const    RUBY_T_NIL    = 0x11
	const    RUBY_T_TRUE   = 0x12
	const    RUBY_T_FALSE  = 0x13
	const    RUBY_T_SYMBOL = 0x14
	const    RUBY_T_FIXNUM = 0x15

	const    RUBY_T_UNDEF  = 0x1b
	const    RUBY_T_NODE   = 0x1c
	const    RUBY_T_ICLASS = 0x1d
	const    RUBY_T_ZOMBIE = 0x1e

	const    RUBY_T_MASK   = 0x1f

	const RUBY_Qfalse = 0x00
    const RUBY_Qtrue  = 0x14
    const RUBY_Qnil   = 0x08
    const RUBY_Qundef = 0x34

    const RUBY_IMMEDIATE_MASK = 0x07
    const RUBY_FIXNUM_FLAG    = 0x01
    const RUBY_FLONUM_MASK    = 0x03
    const RUBY_FLONUM_FLAG    = 0x02
    const RUBY_SYMBOL_FLAG    = 0x0c
    const RUBY_SPECIAL_SHIFT  = 8

 


end # module
