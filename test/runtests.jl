using RubyCall
using Base.Test

# write your own tests here
@test_approx_eq rbModule(:Math)[:sqrt](3) sqrt(3)
a=RubyCall.RbValue([13,7,3,9])
@test a[:sort]()[1] == 3
