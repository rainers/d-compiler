enum x = "enum xx = q{int y = 0;};";

struct S{
	mixin(xx);       
	mixin(x);
}
/+
}struct S{
	enum z = y;
	enum x = "enum xx = q{immutable y = 123;};";
	mixin(xx);
	mixin(x);
	static assert(z == 123);
}+/

/+

struct MixinEvalOrder{
	enum x = "string xx = q{int y = 0;};";
	
	struct S{
		mixin(x);
		mixin(xx); // TODO: we want this to work (?)
	}
}


mixin(q{pragma(msg, is(typeof({immutable(char)[] x=['2'];}())));});
enum immutable(dchar)[] fooz = "hello";
//pragma(msg, "fooz");
pragma(msg, typeof(fooz));

//mixin(`hallo velo();`);

void foo(){
	//mixin(x"abcd"); // TODO: fix utf exception
	mixin("abcd");
	pragma(msg, is(typeof(bar)));
}

mixin(q{
	void main(){
		mixin("pragma(msg,mixin(q{`hooray!`}));pragma(msg,mixin(q{moo}));");
		mixin("2;");
		mixin("22"~"=22;");
		mixin(22);
		mixin(cast(dchar[])['2','a']~";");
		dchar[] x;
		immutable(dchar)[] y=x;
		(){immutable(char)[] x = ['2'];}();

		int oops;
		mixin(`int oops;`);

	}
});

// +/