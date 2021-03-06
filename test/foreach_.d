
struct OpApplyIotaTests{
static:
	struct Iota{
		int s,e;
		this(int s,int e){ this.s=s; this.e=e; }
		int opApply(int delegate(int) dg){
			foreach(i;s..e) if(auto r=dg(i)){ return r; }
			return 0;
		}
		int opApplyReverse(int delegate(int) dg){
			foreach_reverse(i;s..e) if(auto r=dg(i)){ return r; }
			return 0;
		}
	}

	string testOpApplyReverse(){
		string r;
		foreach_reverse(i;Iota(0,10)){
			r~=cast(char)('0'+i);
		}
		return r;
	}
	static assert(testOpApplyReverse()=="9876543210");

	int bar(){
		int r=0;
		foreach(x;Iota(1,10)){
			r+=x;
		}
		return r;
	}
	static assert(bar()==45);

	auto testReturnFromOpApply(){
		foreach(x;Iota(0,10)) return "hi from within opApply";
		assert(0);
	}
	pragma(msg, testReturnFromOpApply());
	static assert(testReturnFromOpApply()=="hi from within opApply");

	void errorFoo(){
		foreach(char[] x;Iota(1,100)){} // TODO: improve diagnostic
		foreach(x,y;Iota(1,100)){}      // TODO: ditto
	}


	int labelShadowing(){
		int r=0;
		foreach(x;Iota(1,10)){
			r+=x;
			if(x==4) goto Lfoo;
		Lfoo:;	// TODO: this probably should be an error instead, but DMD allows this
		}
	Lfoo:
		return r;
	}
	static assert(labelShadowing()==45);
	pragma(msg, labelShadowing());


	immutable arr=[[[9]],[[4,5,2,3],[5,0,6],[0,1,2]],[[4,5,1,4],[6,1,6],[0,1,2]],[[0],[1],[2]],[[1],[2],[3]],[[7]],[[8]]];
	auto labeledContinue(){
		int[] r;
	L0:foreach(i;0..arr.length){
		L1:foreach(j;0..arr[i].length){
			L2:foreach(k;0..arr[i][j].length){
					switch(arr[i][j][k]){
					case 0: continue L0;
					case 1: continue L1;
					case 2: continue L2;
					case 7: break L0;
					case 8: return 8~r;
					case 9: goto Lninetynine;
					default: r~=arr[i][j][k];
					}
				}
				continue;
			Lninetynine:
				r~=99;
			}
		}
		return r;
	}
	pragma(msg, labeledContinue());
	static assert(labeledContinue()==[99,4,5,3,5,4,5,6,3]);

	auto opApplyLabeledContinue(){
		int[] r;
	L0:foreach(i;Iota(0,cast(int)arr.length)){
		L1:foreach(j;Iota(0,cast(int)arr[i].length)){
			L2:foreach(k;Iota(0,cast(int)arr[i][j].length)){
					switch(arr[i][j][k]){
					case 0: continue L0;
					case 1: continue L1;
					case 2: continue L2;
					case 7: break L0;
					case 8: return 8~r;
					case 9: goto Lninetynine;
					default: r~=arr[i][j][k];
					}
				}
				continue;
			Lninetynine:
				r~=99;
			}
		}
		return r;
	}
	pragma(msg, opApplyLabeledContinue());
	static assert(labeledContinue()==opApplyLabeledContinue());

	auto gotoBeforeLoop(int x){
		int[] r;
		goto Lfoo;
	Lbar: return 2;
	Lfoo:
		foreach(i;Iota(0,x)){
			goto Lbar;
		}
		return 0;
	}
	static assert(gotoBeforeLoop(1)==2&&gotoBeforeLoop(0)==0);

	int testGotoCaseGotoDefault(int x,int z){
		int y=1;
		switch(z){
		case -1:
			foreach(i;Iota(0,x)){	
				goto case;
			}
			return -1;
		case 0:
			y++;
			foreach(i;Iota(0,x)){
				y++;
				if(i>2) goto case 2;
			}
			goto case;
		case 2:
			foreach(i;Iota(0,x)){
				y++;
				if(i>1) goto default;
			}
		default:
			return x+y;
		}
	}
	pragma(msg, iota(-1,8).fmap!(function(i)=>iota(-1,8).fmap!(j=>testGotoCaseGotoDefault(i,j))));
	static assert(iota(-1,8).fmap!(function(i)=>iota(-1,8).fmap!(j=>testGotoCaseGotoDefault(i,j)))==[-1,1,0,0,0,0,0,0,0,-1,2,1,1,1,1,1,1,1,5,5,2,3,2,2,2,2,2,8,8,3,5,3,3,3,3,3,11,11,4,7,4,4,4,4,4,13,13,5,8,5,5,5,5,5,14,14,6,9,6,6,6,6,6,15,15,7,10,7,7,7,7,7,16,16,8,11,8,8,8,8,8]);
	pragma(msg, iota(-1,8).fmap!(i=>iota(-1,8).fmap!(j=>testGotoCaseGotoDefault(i,j))));

}
int[] iota(int x,int y){ int[] r; foreach(i;x..y) r~=i; return r; }
int[] fmap(alias a)(int[] b){ int[] r; foreach(x;b) r~=a(x); return r; } // TODO: fix 'cannot access this at nesting level' issue.

bool checkSaveCall(){
	static struct S{
		@property int front(){ return 1; }
		bool empty=true;
		void popFront(){ empty=true; }
		S save(){ empty=false; return this; }
	}
	foreach(x;S()) return !!x;
	return false;
}
static assert(!checkSaveCall());

auto foreachArray(){
	auto arr=[5,2,3,4];
	int[] r=[];
	foreach(i,ref x;arr) r~=[x++,cast(int)i];
	foreach(x;r) r~=x;
	return r~arr;
}
pragma(msg, foreachArray());
static assert(foreachArray()==[5,0,2,1,3,2,4,3,5,0,2,1,3,2,4,3,6,3,4,5]);

int[] foreachReverseToIntMin(){
	int[] r=[];
	foreach_reverse(ref x;int.min..int.min+10){ // TODO
		r~=x;
		x--;
	}
	return r;
}
pragma(msg, foreachReverseToIntMin());

int[] frrngrvShdw(){
	int[] r=[];
	foreach_reverse(ref x;0..21){
		r~=x*x;
		//x-=2;
		int x=2; // error
	}
	for({int l=0,rr=21;}l<rr;){
		--rr;
		auto x=rr;
		r~=x*x;
		int l=0; // error
	}
	return r;
}

int[] frrngrv(){
	int[] r=[];
	foreach_reverse(ref x;0..21){
		r~=x*x;
	}
	for({int l=0,rr=21;}l<rr;){
		--rr;
		auto x=rr;
		r~=x*x;
	}
	return r;
}
enum e=frrngrv();
static assert(e[0..$/2]==e[$/2..$]);
pragma(msg, frrngrv());

int[] frrng(){
	int[] r=[];
   	foreach(ref x;0..20){
		r~=x*x;
		x+=2;
	}
	int y;
	foreach(x;0..10){
		if(x>0){ y=x; break; }
		x=123;
	}
	r~=y;
	return r;
}
pragma(msg, frrng());
static assert(frrng()==[0,9,36,81,144,225,324,1]);

struct Iota{
	size_t s,e;
	this(size_t s,size_t e){ this.s=s; this.e=e; } // // TODO: default constructors
	@property bool empty() => s>=e;
	@property size_t front() => s;
	void popFront(){ s++; }
}
auto iota(size_t s, size_t e){ return Iota(s,e); }
//auto iota(size_t e){ return iota(0,e); } // TODO
auto iota(size_t e){ return Iota(0,e); }

template map(alias a){
	struct Map(R){
		R r;
		this(R r){ this.r=r; }
		@property front(){ return a(r.front); }
		@property bool empty(){ return r.empty; }
		void popFront(){ r.popFront(); }
	}
	auto map(R)(R r){ return Map!R(r); }
}

auto array(R)(R r){
	typeof(r.front)[] a;
	foreach(x;r) a~=x;
	return a;
}
pragma(msg, iota(20).map!(a=>a*a).array);

struct ApWrap(T){
	T r;
	this(T r){ this.r=r; } // // TODO: default initializers
	int opApply(int delegate(size_t) dg){
		foreach(x;r) if(auto r=dg(x)) return r;
		return 0;
	}
}
auto apWrap(T)(T arg){ return ApWrap!T(arg); }

int[] foo(){
	int j=0;
	foreach(i;0..10){ j+=i; }
	assert(j==45);
	foreach(i;iota(10)){ j+=cast(int)i; }
	assert(j==90);
	int[] foo(size_t[] a){
		int[] r=[];
	Lstart:
		r~=1;
		a=a[1..$];
	Lforeach: foreach(x;apWrap(apWrap(apWrap(a)))){
			switch(x){
			case 1: goto Lstart;
			case 2: goto Lend;
			case 3: r~=1337~r;
			case 4: continue;
			case 5: r~=2; continue;
			case 6: break Lforeach;
			case 7: return r;
			default: break;
			}
			r~=3;
			if(x<1||x>6) break;
		}
		r~=4;
	Lend:
		return r;
	}
	return foo([1,3,4,1,3,1,3,1,3,4,5,6,3])~foo([4,5,6,2,1])~foo([4,3,4,5,5,5,7,1,2,3,4,5])~foo([1,5,0]);
}
static assert(foo()==[1,1337,1,1,1,1,1337,1,1337,1,1,1,1,1,1,1337,1,1337,1,1,1,1,1337,1,1337,1,1,1,1,1,1,1,1,1337,1,1337,1,1,1,1,1337,1,1337,1,1,1,1,1,1,1337,1,1337,1,1,1,1,1337,1,1337,1,1,1,1,1,1,1,1,2,4,1,2,4,1,1337,1,2,2,2,1,2,3,4]);
pragma(msg, "foo: ",foo());

alias size_t = typeof(int[].length);
alias string = immutable(char)[];
// +/
// +/
// +/
