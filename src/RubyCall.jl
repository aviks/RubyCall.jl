module RubyCall
	export rbModule

	libruby=dlopen("/System/Library/Frameworks/Ruby.framework/Versions/2.0/usr/lib/libruby.2.0.0")

	ruby_init = dlsym(libruby, :ruby_init)
	ccall(ruby_init,Void, ())

	 code="Math.sqrt(9)"
	 rb_eval_string = dlsym(libruby, :rb_eval_string)
	 #r = ccall(rb_eval_string, Ptr{Void}, (Ptr{Uint8},), code)
	 rb_num2int = dlsym(libruby, :rb_num2int)
	 rb_num2dbl = dlsym(libruby, :rb_num2dbl)
	 # ccall(rb_num2int, Clong, (Ptr{Void}, ) , r)


	 rb_int2fix(x::Int64) = reinterpret (Ptr{Void}, x << 1 | 0x01 )

	rb_define_module = dlsym(libruby, :rb_define_module)
	rb_funcall = dlsym(libruby, :rb_funcall)
	 # mod_Math =  ccall(rb_define_module, Ptr{Void}, (Ptr{Uint8},), "Math")

	rb_intern = dlsym(libruby, :rb_intern)

	# id_sqrt = ccall(rb_intern, Ptr{Void}, (Ptr{Uint8},), "sqrt")
	# rb_funcall = dlsym(libruby, :rb_funcall)

	# ccall(rb_funcall, Ptr{Void}, (Ptr{Void}, Ptr{Void}, Cint, Ptr{Void}), mod_Math, id_sqrt, 1, reinterpret(Ptr{Void}, rb_int2fix(9)))
	# ccall(rb_num2int, Cint, (Ptr{Void}, ) , r)


  #############################################

	type RbValue
		VALUE::Ptr{Void}
	end

	function rbModule(mod::Symbol) 
		v = ccall(rb_define_module, Ptr{Void}, (Ptr{Uint8},), string(mod))
		return RbValue(v)
	end

	function Base.getindex(v::RbValue, method::Symbol)
		return (args...) -> rb_call(v, method, args...)
	end

	function rb_call(recv::RbValue, method::Symbol, args...)
		ID = ccall(rb_intern, Ptr{Void}, (Ptr{Uint8},), string(method))
		converted_args = convert_args(args...)
		if length(args) == 1
			r = ccall(rb_funcall, Ptr{Void}, (Ptr{Void}, Ptr{Void}, Cint, Ptr{Void}), recv.VALUE, ID, 1, converted_args[1])
		end 

		if length(args) == 2
			r = ccall(rb_funcall, Ptr{Void}, (Ptr{Void}, Ptr{Void}, Cint, Ptr{Void}, Ptr{Void}), recv.VALUE, ID, 2, converted_args[1], converted_args[2])
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

	convert_arg(arg::Int64) = rb_int2fix(arg)

	function convert_result(r::Ptr{Void}) 
		TYP = rb_type(r)
		if TYP == RUBY_T_FIXNUM 
			return ccall(rb_num2int, Cint, (Ptr{Void}, ) , r)
		end

		if TYP == RUBY_T_FLOAT
			return ccall(rb_num2dbl, Cdouble, (Ptr{Void}, ), r)
		end
		return RbValue(r)
	end

	function rb_type(obj::Ptr{Void})

		if (IMMEDIATE_P(obj) > 0x00 ) 
			if (FIXNUM_P(obj) > 0x00) return RUBY_T_FIXNUM; end
	        if (FLONUM_P(obj) > 0x00) return RUBY_T_FLOAT; end 
	    end


		# if (IMMEDIATE_P(obj) == 0x01 ) 
		# 	if (FIXNUM_P(obj) == 0x01) return RUBY_T_FIXNUM;
	 #        if (FLONUM_P(obj) == 0x01) return T_FLOAT;
	 #        if (reinterpret(Int64, obj.VALUE) == RUBY_Qtrue)  return T_TRUE;
		# 	if (SYMBOL_P(obj)) return T_SYMBOL;
		# 	if (reinterpret(Int64, obj.VALUE) == RUBY_Qundef) return T_UNDEF;
	    
	 #    else if (!RTEST(obj)) 
		# 	if (reinterpret(Int64, obj.VALUE) == Qnil)   return T_NIL;
		# 	if (reinterpret(Int64, obj.VALUE) == Qfalse) return T_FALSE;
	 #    end
	 #    return BUILTIN_TYPE(obj);
	end

	immutable RBasic 
    	flags::Ptr{Void};
    	klass::Ptr{Void};
	end

	IMMEDIATE_P(x::Ptr{Void}) =  reinterpret(Int64, x) & RUBY_IMMEDIATE_MASK
	FIXNUM_P(x::Ptr{Void}) =  reinterpret(Int64, x) & RUBY_FIXNUM_FLAG
	FLONUM_P(x::Ptr{Void}) = (reinterpret(Int64, x) & RUBY_FLONUM_MASK) == RUBY_FLONUM_FLAG

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
