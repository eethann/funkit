This is a smallish mod that adds 2 parameter function operators to the awesome
[mod matrix](https://github.com/sixolet/matrix) and
[toolkit](https://github.com/sixolet/toolkit) mods for Norns by sixolet. the
functions are inspired by the
[FUN operators](https://www.manualslib.com/manual/399250/Kurzweil-K2000-Musicians-Guide.html?page=345)
in Kurzweil's V.A.S.T. synths, and include the following operators:


* **max **: math.max
* **min **: math.min
* **sum **: `a + b`
* **diff **: `a - b`
* **avg **: `(a + b) / 2`
* **|a-b| **: absolute value of `a-b`
* **a^b **: a to the power of b
* **qntz **: quantize b to steps of size a
* **mod **: `a % b`
* **wrap **: `(a % b) / b`, modulo normalized to 1 
* **a/2+b ** 
* **a/4+b/2 ** 
* **(a+2b)/3 ** 
* **a \* b ** 
* **1-a\*b ** 
* **a\*10^b *: 
* **lopass **: simple low pass filter, b + a\*y 
* **b/1-a **: 
* **(a+b)/2 **: 
* **and**: logical and with threshold of 0.5 
* **or**: logical or
* **a(y + b)**: chaotic fun
* **ay + b**: chaotic fun
* **(a + 1)y + b**: chaotic fun
* **y +a(y + b)**: chaotic fun
* **a |y| + b**: chaotic fun
* **S&H**: sample B when A > 0.5
* **T&H**: track B when A > 0.5

