# RubyCall

Call Ruby programs from Julia

Things like the following work: 

```jlcon
julia> using RubyCall

julia> rbModule(:Math)[:sqrt](3)
1.7320508075688772

julia> a=RubyCall.RbValue([13,7,3,9])
RbValue(Ptr{Void} @0x00007f8166db6cf0)

julia> a[:sort]()[1]
```

### This is a work in progress. This codebase is not usable in its current form. 

