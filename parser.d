module parser;

import std.array, std.range, std.algorithm, std.traits, std.conv: to;
import std.typetuple;

import lexer;

abstract class Node{
	Location loc;
}

class Expression: Node{ // empty expression if instanced
	int brackets=0;
	override string toString(){return _brk("{}()");}
	private string _brk(string s){return std.array.replicate("(",brackets)~s~std.array.replicate(")",brackets); return s;}
}
class Statement: Node{ // empty statement if instanced
	Location loc;
	override string toString(){return ";";}
}
class Declaration: Statement{ // empty declaration if instanced
	STC stc;
	Identifier name;
	this(STC stc,Identifier name){this.stc=stc; this.name=name;}
	override string toString(){return ";";}
}

class ErrorDecl: Declaration{
	this(){super(STC.init, null);}
	override string toString(){return "__error ;";}
}

class ModuleDecl: Declaration{
	Expression symbol;
	this(STC stc, Expression sym){symbol=sym; super(stc, null);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"module "~symbol.toString()~";";}
}

class ImportBindingsExp: Expression{
	Expression symbol;
	Expression[] bindings;
	this(Expression sym, Expression[] bind){symbol=sym; bindings=bind;}
	override string toString(){return symbol.toString()~": "~join(map!(to!string)(bindings),", ");}
}
class ImportDecl: Declaration{
	Expression[] symbols;
	this(STC stc, Expression[] sym){symbols=sym; super(stc,null);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"import "~join(map!(to!string)(symbols),", ")~";";}
}
class EnumDecl: Declaration{
	Expression base;
	Expression[2][] members;
	this(STC stc,Identifier name, Expression base, Expression[2][] mem){this.base=base; members=mem; super(stc,name);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"enum"~(name?" "~name.toString():"")~(base?":"~base.toString():"")~
			"{"~join(map!((a){return a[0].toString()~(a[1]?"="~a[1].toString():"");})(members),",")~"}";}
}

abstract class ConditionalDecl: Declaration{
	Statement bdy;
	Statement els;
	this(STC stc,Statement b,Statement e)in{assert(b&&1);}body{
		bdy=b; els=e; super(stc,null);
		if(auto bb=cast(CompoundStm)bdy) bb.newScope=false;
		if(auto ee=cast(CompoundStm)els) ee.newScope=false;
	}
}
class VersionSpecDecl: Declaration{
	Expression spec;
	this(STC stc,Expression s)in{assert(s!is null);}body{spec=s; super(stc,null);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"version="~spec.toString()~";";}
}
class VersionDecl: ConditionalDecl{
	Expression cond;
	this(STC stc,Expression c,Statement b, Statement e)in{assert(c!is null);}body{cond=c; super(stc,b,e);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"version("~cond.toString()~") "~bdy.toString()~
			(els?(cast(CompoundStm)bdy||cast(CompoundDecl)bdy?"":"\n")~"else "~els.toString():"");}
}
class DebugSpecDecl: Declaration{
	Expression spec;
	this(STC stc,Expression s)in{assert(s!is null);}body{spec=s; super(stc,null);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"debug="~spec.toString()~";";}
}
class DebugDecl: ConditionalDecl{
	Expression cond;
	this(STC stc,Expression c,Statement b, Statement e){cond=c; super(stc,b,e);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"debug"~(cond?"("~cond.toString()~") ":"")~bdy.toString()~
			(els?(cast(CompoundStm)bdy||cast(CompoundDecl)bdy?"":"\n")~"else "~els.toString():"");}
}
class StaticIfDecl: ConditionalDecl{
	Expression cond;
	this(STC stc,Expression c,Statement b,Statement e)in{assert(c&&b);}body{cond=c; super(stc,b,e);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"static if("~cond.toString()~") "~bdy.toString()~
			(els?(cast(CompoundStm)bdy||cast(CompoundDecl)bdy?"":"\n")~"else "~els.toString():"");}
}
class StaticAssertDecl: Declaration{
	Expression[] a;
	this(STC stc,Expression[] args){a = args; super(stc,null);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"static assert("~join(map!(to!string)(a),",")~");";}
}

class MixinDecl: Declaration{
	Expression e;
	this(STC stc, Expression exp){e=exp; super(stc,null);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"mixin("~e.toString()~");";}
}
class AliasDecl: Declaration{
	Declaration decl;
	this(STC stc, Declaration declaration){decl=declaration; super(stc, declaration.name);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"alias "~decl.toString();}
}
class TypedefDecl: Declaration{
	Declaration decl;
	this(STC stc, Declaration declaration){decl=declaration; super(stc, declaration.name);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"typedef "~decl.toString();}
}
class CompoundDecl: Declaration{
	Declaration[] decls;
	this(STC s,Declaration[] declarations){stc=s; decls=declarations; super(stc,null);}
	override string toString(){return STCtoString(stc)~"{\n"~(stc?join(map!(to!string)(decls),"\n")~"\n}":indent(join(map!(to!string)(decls),"\n"))~"\n}");}
}
class AttributeDecl: Declaration{
	Declaration[] decls;
	this(STC stc,Declaration[] declarations){decls=declarations; super(stc,null);}
	override string toString(){return STCtoString(stc)~":\n"~join(map!(to!string)(decls),"\n");}
}

class TemplateParameter{
	Identifier name;
	Expression type, spec, init;
	bool isAlias, isTuple;
	this(bool isa, bool ist, Expression tt, Identifier name, Expression specialization, Expression deflt){
		isAlias=isa, isTuple=ist; this.name = name;
		type=tt; spec=specialization; init=deflt;
	}
	override string toString(){
		return (isAlias?"alias ":"")~(type?type.toString()~" ":"")~(name?name.toString():"")~
			(isTuple?"...":"")~(spec?":"~spec.toString():"")~(init?"="~init.toString():"");
	}
}

class TemplateDecl: Declaration{
	bool ismixin;
	TemplateParameter[] params;
	Expression constraint;
	CompoundDecl bdy;
	this(bool m,STC stc,Identifier name, TemplateParameter[] prm, Expression c, CompoundDecl b){
		ismixin=m; params=prm; constraint=c; bdy=b; super(stc,name);
	}
	override string toString(){
		return (stc?STCtoString(stc)~" ":"")~"template "~name.toString()~"("~join(map!(to!string)(params),",")~")"~
			(constraint?" if("~constraint.toString()~")":"")~bdy.toString();
	}
}

class TemplateMixinDecl: Declaration{
	Expression inst;
	this(STC stc, Expression i, Identifier name)in{assert(i&&1);}body{inst=i; super(stc,name);}
	override string toString(){return "mixin "~inst.toString()~(name?" "~name.toString():"")~";";}
}

abstract class AggregateDecl: Declaration{
	CompoundDecl bdy;
	this(STC stc, Identifier name, CompoundDecl b){bdy=b; super(stc,name);}
}
class StructDecl: AggregateDecl{
	this(STC stc,Identifier name, CompoundDecl b){super(stc,name,b);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"struct"~(name?" "~name.toString():"")~(bdy?bdy.toString():";");}
}
class UnionDecl: AggregateDecl{
	this(STC stc,Identifier name, CompoundDecl b){super(stc,name,b);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"union"~(name?" "~name.toString():"")~(bdy?bdy.toString():";");}
}
struct ParentListEntry{
	STC protection;
	Expression symbol;
	string toString(){return (protection?STCtoString(protection)~" ":"")~symbol.toString();}
}
class ClassDecl: AggregateDecl{
	ParentListEntry[] parents;
	this(STC stc,Identifier name, ParentListEntry[] p, CompoundDecl b){ parents=p; super(stc,name,b); }
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"class"~(name?" "~name.toString():"")~
			(parents?": "~join(map!(to!string)(parents),","):"")~(bdy?bdy.toString():"");}
}
class InterfaceDecl: AggregateDecl{
	ParentListEntry[] parents;
	this(STC stc,Identifier name, ParentListEntry[] p, CompoundDecl b){ parents=p; super(stc,name,b); }
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"interface"~(name?" "~name.toString():"")~
			(parents?": "~join(map!(to!string)(parents),","):"")~(bdy?bdy.toString():";");}
}
class TemplateAggregateDecl: Declaration{
	TemplateParameter[] params;
	Expression constraint;
	AggregateDecl decl;
	this(STC stc,TemplateParameter[] p, Expression c, AggregateDecl ad){ params=p; constraint=c; decl=ad; super(stc,decl.name); }
	override string toString(){
		auto s=cast(StructDecl)decl, u=cast(UnionDecl)decl, c=cast(ClassDecl)decl, i=cast(InterfaceDecl)decl;
		string r=(stc?STCtoString(stc)~" ":"");
		r~=(s?"struct":u?"union":c?"class":"interface")~(decl.name?" "~name.toString():"")~"("~join(map!(to!string)(params),",")~")";
		if(c && c.parents) r~=": "~join(map!(to!string)(c.parents),",");
		if(i && i.parents) r~=": "~join(map!(to!string)(i.parents),",");
		auto bdy=s?s.bdy:u?u.bdy:c?c.bdy:i.bdy;
		return r~(constraint?" if("~constraint.toString()~")":"")~(bdy?bdy.toString():";");
	}
}

class TemplateFunctionDecl: Declaration{
	TemplateParameter[] params;
	Expression constraint;
	FunctionDecl fdecl;
	this(STC stc, TemplateParameter[] tp, Expression c, FunctionDecl fd){params=tp; constraint=c;fdecl=fd; super(stc, fdecl.name);}
	override string toString(){
		auto fd=cast(FunctionDef)fdecl;
		return (fdecl.type.stc?STCtoString(fdecl.type.stc)~" ":"")~(fdecl.type.ret?fdecl.type.ret.toString()~" ":"")~name.toString()~
			"("~join(map!(to!string)(params),",")~")"~fdecl.type.pListToString()~(constraint?" if("~constraint.toString()~")":"")
			~(fdecl.pre?"in"~fdecl.pre.toString():"")~(fdecl.post?"out"~(fdecl.postres?"("~fdecl.postres.toString()~")":"")~fdecl.post.toString():"")~
			(fd?(fd.pre||fd.post?"body":"")~fd.bdy.toString():!fdecl.pre&&!fdecl.post?";":"");
	}
}

class CArrayDecl: Declaration{
	Expression type;
	Expression init;
	Expression postfix; // reverse order
	this(STC stc, Expression type, Identifier name, Expression pfix, Expression initializer)in{assert(type&&name&&pfix);}body{
		this.stc=stc; this.type=type; postfix=pfix; init=initializer; super(stc,name);
	}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~type.toString()~" "~postfix.toString()~(init?"="~init.toString():"")~";";}
}

class VarDecl: Declaration{
	Expression type;
	Expression init;
	this(STC stc, Expression type, Identifier name, Expression initializer){this.stc=stc; this.type=type; init=initializer; super(stc,name);}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~(type?type.toString()~" ":"")~name.toString()~(init?"="~init.toString():"")~";";}
}
class Declarators: Declaration{
	VarDecl[] decls;
	this(VarDecl[] declarations)in{assert(declarations.length>1);foreach(x;declarations) assert(x.type is declarations[0].type);}body{
		decls=declarations;super(STC.init,null);
	}
	override string toString(){
		string r=(decls[0].stc?STCtoString(decls[0].stc)~" ":"")~(decls[0].type?decls[0].type.toString()~" ":"");
		//return r~join(map!((a){return a.name.toString();})(decls),","); // WTF???
		foreach(x;decls[0..$-1]) r~=x.name.toString()~(x.init?"="~x.init.toString():"")~",";
		return r~decls[$-1].name.toString()~(decls[$-1].init?"="~decls[$-1].init.toString():"")~";";
	}
}

class Parameter: VarDecl{ // for functions, foreach etc
	this(STC stc, Expression type, Identifier name, Expression initializer){super(stc,type,name,initializer);}
	override string toString(){return STCtoString(stc)~(stc&&type?" ":"")~(type?type.toString():"")~
			(name?(stc||type?" ":"")~name.toString():"")~(init?"="~init.toString():"");}
}
class PostblitParameter: Parameter{
	this(){super(STC.init,null,null,null);}
	override string toString(){return "this";}
}
class FunctionDecl: Declaration{
	FunctionType type;
	CompoundStm pre,post;
	Identifier postres;
	this(FunctionType type,Identifier name,CompoundStm pr,CompoundStm po,Identifier pres){
		this.type=type; pre=pr, post=po; postres=pres; super(type.stc, name);
	}
	override string toString(){
		return (type.stc?STCtoString(type.stc)~" ":"")~(type.ret?type.ret.toString()~" ":"")~name.toString()~type.pListToString()~
			(pre?"in"~pre.toString():"")~(post?"out"~(postres?"("~postres.toString()~")":"")~post.toString():"")~(!pre&&!post?";":"");
	}
}

class FunctionDef: FunctionDecl{
	CompoundStm bdy;
	this(FunctionType type,Identifier name, CompoundStm precondition,CompoundStm postcondition,Identifier pres,CompoundStm fbody){
		super(type,name, precondition, postcondition, pres); bdy=fbody;}
	override string toString(){
		return (type.stc?STCtoString(type.stc)~" ":"")~(type.ret?type.ret.toString()~" ":"")~name.toString()~type.pListToString()~
			(pre?"in"~pre.toString():"")~(post?"out"~(postres?"("~postres.toString()~")":"")~post.toString():"")~(pre||post?"body":"")~bdy.toString();
	}
}

class UnitTestDecl: Declaration{
	CompoundStm bdy;
	this(STC stc,CompoundStm b)in{assert(b!is null);}body{ bdy=b; super(stc,null); }
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"unittest"~bdy.toString();}
}

class PragmaDecl: Declaration{
	Expression[] args;
	Statement bdy;
	this(STC stc,Expression[] a, Statement b)in{assert(b&&1);}body{
		args=a; bdy=b; super(stc,null);
		if(auto bb=cast(CompoundStm)bdy) bb.newScope=false;
	}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~"pragma("~join(map!(to!string)(args),",")~")"~bdy.toString();}
}

enum LinkageType{
	D,
	C,
	CPP,
	Pascal,
	System,
	Windows,
}

class ExternDecl: Declaration{
	LinkageType linktype;
	Declaration decl;
	this(STC stc,LinkageType l,Declaration d)in{assert(d&&1);}body{
		linktype=l; decl=d;
		super(stc,d.name);
	}
	override string toString(){
		return (stc?STCtoString(stc)~" ":"")~"extern("~(linktype==LinkageType.CPP?"C++":to!string(linktype))~") "~decl.toString();
	}
}
class AlignDecl: Declaration{
	ulong alignment;
	Declaration decl;
	this(STC stc,ulong a,Declaration d)in{assert(d&&1);}body{
		alignment=a; decl=d;
		super(stc,d.name);
	}
	override string toString(){
		return (stc?STCtoString(stc)~" ":"")~"align("~to!string(alignment)~") "~decl.toString();
	}
}
enum VarArgs{
	none,
	cStyle,
	dStyle,
}
class FunctionType: Type{
	STC stc;
	Expression ret;
	Parameter[] params;
	VarArgs vararg;
	this(STC stc, Expression retn,Parameter[] plist,VarArgs va){this.stc=stc; ret=retn; params=plist; vararg=va;}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~(ret?ret.toString():"")~pListToString();}
	string pListToString(){
		return "("~join(map!(to!string)(params),",")~(vararg==VarArgs.cStyle?(params.length?",":"")~"...)":vararg==VarArgs.dStyle?"...)":")");
	}
}

class FunctionPtr: Type{
	FunctionType ft;
	this(FunctionType ft)in{assert(ft !is null&&ft.ret !is null);}body{this.ft=ft;}
	override string toString(){return ft.ret.toString()~" function"~ft.pListToString()~(ft.stc?" "~STCtoString(ft.stc):"");}
}

class DelegateType: Type{
	FunctionType ft;
	this(FunctionType ft)in{assert(ft !is null&&ft.ret !is null);}body{this.ft=ft;}
	override string toString(){return ft.ret.toString()~" delegate"~ft.pListToString()~(ft.stc?" "~STCtoString(ft.stc):"");}
}

class TypeidExp: Expression{
	Expression e;
	this(Expression exp)in{assert(exp&&1);}body{e=exp;}
	override string toString(){return "typeid("~e.toString~")";}
}

class Type: Expression{ //Types can be part of Expressions and vice-versa
  Location loc;
  override string toString(){return "Type";}
}

class TypeofExp: Type{
	Expression e;
	this(Expression exp){e=exp;}
	override string toString(){return _brk("typeof("~e.toString()~")");}
}
class TypeofReturnExp: Type{
	override string toString(){return _brk("typeof(return)");}
}
class BasicType: Type{
	TokenType type;
	this(TokenType type){this.type=type;}
	override string toString(){return _brk(Token(type).toString());}
}

class Pointer: Type{
	Expression e;
	this(Expression next)in{assert(next&&1);}body{e=next;}
	override string toString(){return _brk(e.toString()~'*');}
}

class QualifiedType(TokenType op): Type{
	Expression type;
	this(Expression type){this.type=type;}
	override string toString(){return _brk(TokChars!op~(!type.brackets?" ":"")~type.toString());}
}

class ErrorExp: Expression{
	override string toString(){return _brk("__error");}
}

class Identifier: Expression{
	string name;
	this(string name){this.name = name;}
	override string toString(){return _brk(name);}
}

class LiteralExp: Expression{
	Token lit;
	this(Token literal){lit=literal;}
	override string toString(){return _brk(lit.toString());}
}

class ArrayAssocExp: Expression{
	Expression key;
	Expression value;
	this(Expression k, Expression v){key=k; value=v;}
	override string toString(){return key.toString()~":"~value.toString();}
}

class ArrayLiteralExp: Expression{
	Expression[] lit;
	this(Expression[] literal){lit=literal;}
	override string toString(){return _brk("["~join(map!(to!string)(lit),",")~"]");}
}
/*
class AssocArrayLiteralExp: Expression{
	Expression[2][] lit;
	this(Expression[2][] literal){lit=literal;}
	override string toString(){return _brk("["~join(map!q{a[0].toString()~":"~a[1].toString()}(lit),",")~"]");}
}
*/
class FunctionLiteralExp: Expression{
	FunctionType type;
	CompoundStm bdy;
	bool isStatic;
	this(FunctionType ft, CompoundStm b, bool s=false){ type=ft; bdy=b; isStatic=s;}
	override string toString(){return _brk((isStatic?"function"~(type&&type.ret?" ":""):type&&type.ret?"delegate ":"")~(type?type.toString():"")~bdy.toString());}
}

class ThisExp: Identifier{
	this(){ super(q{this}); }
}
class SuperExp: Identifier{
	this(){ super(q{super}); }
}
class TildeThisExp: Identifier{
	this(){ super(q{~this}); }
}
class InvariantExp: Identifier{
	this(){ super(q{invariant}); }
}
class DollarExp: Identifier{
	this(){ super(q{$}); }
}

class CastExp: Expression{
	STC stc;
	Expression type,e;
	this(STC ss,Expression tt,Expression exp){stc=ss; type=tt; e=exp;}
	override string toString(){return _brk("cast("~(stc?STCtoString(stc)~(type?" ":""):"")~(type?type.toString():"")~")"~e.toString());}
}
class NewExp: Expression{
	Expression[] a1;
	Expression type;
	Expression[] a2;
	this(Expression[] args1,Expression type,Expression[] args2){a1=args1; this.type=type; a2=args2;}
	override string toString(){
		return _brk("new"~(a1?"("~join(map!(to!string)(a1),",")~") ":" ")~type.toString()~(a2?"("~join(map!(to!string)(a2),",")~")":""));
	}
}
class NewClassExp: Expression{
	Expression[] args;
	ClassDecl class_;
	this(Expression[] a, ClassDecl c)in{assert(c&&c.bdy);}body{args=a; class_=c;}
	override string toString(){
		return "new class("~join(map!(to!string)(args),",")~")"~(class_.parents?" "~join(map!(to!string)(class_.parents),","):"")~class_.bdy.toString();
	}
}
class MixinExp: Expression{
	Expression e;
	this(Expression exp){e=exp;}
	override string toString(){return _brk("mixin("~e.toString()~")");}
}
class ImportExp: Expression{
	Expression e;
	this(Expression exp){e=exp;}
	override string toString(){return _brk("import("~e.toString()~")");}
}
class AssertExp: Expression{
	Expression[] a;
	this(Expression[] args){a = args;}
	override string toString(){return _brk("assert("~join(map!(to!string)(a),",")~")");}
}

class UnaryExp(TokenType op): Expression{
	Expression e;
	this(Expression next){e = next;}
	override string toString(){return _brk(TokChars!op~e.toString());}
}
class PostfixExp(TokenType op): Expression{
	Expression e;
	this(Expression next){e = next;}
	override string toString(){return _brk(e.toString()~TokChars!op);}
}
class IndexExp: Expression{ //e[a...]
	Expression e;
	Expression[] a;
	this(Expression exp, Expression[] args){e=exp; a=args;}
	override string toString(){return _brk(e.toString()~(a.length?'['~join(map!(to!string)(a),",")~']':"[]"));}
}
class SliceExp: Expression{//e[l..r]
	Expression e;
	Expression l,r;
	this(Expression exp, Expression left, Expression right){e=exp; l=left; r=right;}
	override string toString(){return _brk(e.toString()~'['~l.toString()~".."~r.toString()~']');}
}
class CallExp: Expression{
	Expression e;
	Expression[] a;
	this(Expression exp, Expression[] args){e=exp; a=args;}
	override string toString(){return _brk(e.toString()~(a.length?'('~join(map!(to!string)(a),",")~')':"()"));}
}
class TemplateInstanceExp: Expression{
	Expression e;
	Expression[] args;
	this(Expression exp, Expression[] a){e=exp; args=a;}
	override string toString(){return _brk(e.toString()~"!"~(args.length!=1?"(":"")~join(map!(to!string)(args),",")~(args.length!=1?")":""));}
}
class BinaryExp(TokenType op): Expression{
	Expression e1, e2;
	this(Expression left, Expression right){e1=left; e2=right;}
	override string toString(){
		static if(op==Tok!"in"||op==Tok!"is"||op==Tok!"!in"||op==Tok!"!is") return _brk(e1.toString() ~ " "~TokChars!op~" "~e2.toString());
		else return _brk(e1.toString() ~ TokChars!op ~ e2.toString());
	}
	//override string toString(){return e1.toString() ~ " "~ e2.toString~TokChars!op;} // RPN
}

class TernaryExp: Expression{
	Expression e1, e2, e3;
	this(Expression cond, Expression left, Expression right){e1=cond; e2=left; e3=right;}
	override string toString(){return _brk(e1.toString() ~ '?' ~ e2.toString() ~ ':' ~ e3.toString());}
}

enum WhichIsExp{
	type,
	implicitlyConverts,
	isEqual
}
class IsExp: Expression{
	WhichIsExp which;
	Expression type;
	Identifier ident;
	Expression typeSpec;
	TokenType typeSpec2;
	TemplateParameter[] tparams;
	this(WhichIsExp w, Expression t, Identifier i, Expression ts, TokenType ts2, TemplateParameter[] tp)
		in{assert(t&&(which==WhichIsExp.type||typeSpec||typeSpec2!=Tok!"")); assert(which!=WhichIsExp.type||!tparams);}body{
		which=w; type=t; ident=i; typeSpec=ts;
		typeSpec2=ts2; tparams=tp;
	}
	override string toString(){
		return "is("~type.toString()~(ident?" "~ident.toString():"")~(which!=WhichIsExp.type?(which==WhichIsExp.isEqual?"==":": ")~
			(typeSpec?typeSpec.toString():Token(typeSpec2).toString())~(tparams?","~join(map!(to!string)(tparams),","):""):"")~")";
	}
}

class TraitsExp: Expression{
	Expression[] args;
	this(Expression[] a){args=a;}
	override string toString(){return "__traits("~join(map!(to!string)(args),",")~")";}
}
class DeleteExp: Expression{ // why is this an expression and throw a statement? wtf...
	Expression e;
	this(Expression exp)in{assert(exp&&1);}body{e=exp;}
	override string toString(){return "delete "~e.toString();}
}

abstract class InitializerExp: Expression{}
class VoidInitializerExp: InitializerExp{
	override string toString(){return "void";}
}

class StructAssocExp: Expression{
	Identifier key;
	Expression value;
	this(Identifier k, Expression v){key=k; value=v;}
	override string toString(){return key.toString()~":"~value.toString();}
}
class ArrayInitAssocExp: Expression{
	Expression key;
	Expression value;
	this(Expression k, Expression v){key=k; value=v;}
	override string toString(){return key.toString()~":"~value.toString();}
}
class StructLiteralExp: InitializerExp{
	Expression[] args;
	this(Expression[] a){args=a;}
	override string toString(){return "{"~join(map!(to!string)(args),",")~"}";} 
}

class ErrorStm: Statement{
	this(){}
	override string toString(){return "__error;";}
}

private string indent(string code){
	import std.string;
	auto sl=splitLines(code);if(!sl.length) return "";
	string r="    "~sl[0];
	foreach(x;sl[1..$]) r~="\n    "~x;
	return r;
}
class CompoundStm: Statement{
	Statement[] s; bool newScope;
	this(Statement[] ss, bool newscope=true){s=ss; newScope=newscope;}
	override string toString(){return "{\n"~indent(join(map!(to!string)(s),"\n"))~"\n}";}
}

class LabeledStm: Statement{
	Identifier l;
	Statement s;
	this(Identifier label, Statement statement){l=label; s=statement;}
	override string toString(){return l.toString()~": "~s.toString();}
}

class ExpressionStm: Statement{
	Expression e;
	this(Expression next){e=next;}
	override string toString(){return e.toString() ~ ';';}
}

class ConditionDeclExp: Expression{
	STC stc;
	Expression type;
	Identifier name;
	Expression init;
	this(STC s, Expression t, Identifier n, Expression i){stc=s; type=t; name=n; init=i;}
	override string toString(){return (stc?STCtoString(stc)~" ":"")~(type?type.toString()~" ":"")~name.toString()~(init?"="~init.toString():"");}
}


class IfStm: Statement{
	Expression e; Statement s1,s2;
	this(Expression cond, Statement left, Statement right){e=cond, s1=left, s2=right;}
	override string toString(){return "if(" ~ e.toString ~ ") "~s1.toString()~(s2!is null?(cast(CompoundStm)s1?"":"\n")~"else "~s2.toString:"");}
}
class WhileStm: Statement{
	Expression e; Statement s;
	this(Expression cond, Statement statement){e=cond; s=statement;}
	override string toString(){return "while(" ~ e.toString ~ ") "~s.toString();}
}
class DoStm: Statement{
	Statement s; Expression e;
	this(Statement statement, Expression cond){s=statement;e=cond;}
	override string toString(){return "do "~s.toString()~"while("~e.toString()~");";}
}
class ForStm: Statement{
	Statement s1; Expression e1, e2;
	Statement s2;
	this(Statement init, Expression cond, Expression next, Statement statement){s1=init; e1=cond; e2=next; s2=statement;}
	override string toString(){return "for("~s1.toString()~(e1?e1.toString():"")~";"~(e2?e2.toString:"")~") "~s2.toString();}
}
class ForeachStm: Statement{
	Parameter[] vars;
	Expression aggregate;
	Statement bdy;
	bool isReverse;
	this(Parameter[] v,Expression a,Statement b, bool isr=false){ vars = v; aggregate = a; bdy = b; isReverse=isr; }
	override string toString(){return "foreach"~(isReverse?"_reverse":"")~"("~join(map!(to!string)(vars),",")~";"~aggregate.toString()~") "~bdy.toString();}
}
class ForeachRangeStm: Statement{
	Parameter var;
	Expression left,right;
	Statement bdy;
	bool isReverse;
	this(Parameter v,Expression l,Expression r,Statement b, bool isr=false){ var = v; left = l; right=r; bdy = b; isReverse=isr; }
	override string toString(){return "foreach"~(isReverse?"_reverse":"")~"("~var.toString()~";"~left.toString()~".."~right.toString()~") "~bdy.toString();}
}
class SwitchStm: Statement{
	bool f; Expression e; Statement s;
	this(bool isfinal, Expression exp, Statement statement){f=isfinal; e=exp; s=statement;}
	this(Expression exp, Statement statement){f=false; e=exp; s=statement;}
	override string toString(){return (f?"final ":"")~"switch("~e.toString()~") "~s.toString();}
}
class CaseStm: Statement{
	Expression[] e; Statement[] s;
	this(Expression[] es, Statement[] ss){e=es; s=ss;}
	override string toString(){return "case "~join(map!(to!string)(e),",")~":"~(s?"\n":"")~indent(join(map!(to!string)(s),"\n"));}
}
class CaseRangeStm: Statement{
	Expression e1,e2; Statement[] s;
	this(Expression first, Expression last, Statement[] ss){e1=first; e2=last; s=ss;}
	override string toString(){return "case "~e1.toString()~": .. case "~e2.toString()~":"~(s?"\n":"")~indent(join(map!(to!string)(s),"\n"));}
}
class DefaultStm: Statement{
	Statement[] s;
	this(Statement[] ss){s=ss;}
	override string toString(){return "default:"~(s?"\n":"")~indent(join(map!(to!string)(s),"\n"));}
}
class ContinueStm: Statement{
	Identifier e;
	this(Identifier identifier){e=identifier;}
	override string toString(){return "continue"~(e?" "~e.name:"")~";";}
}
class BreakStm: Statement{
	Identifier e;
	this(Identifier identifier){e=identifier;}
	override string toString(){return "break"~(e?" "~e.name:"")~";";}
}
class ReturnStm: Statement{
	Expression e;
	this(Expression exp){e=exp;}
	override string toString(){return "return"~(e?" "~e.toString():"")~";";}
}
enum WhichGoto{
	identifier,
	default_,
	case_,
	caseExp,
}
class GotoStm: Statement{
	WhichGoto t; Expression e;
	this(WhichGoto type,Expression exp){t=type; e=exp;}
	override string toString(){
		final switch(t){
			case WhichGoto.identifier: return "goto "~e.toString()~";";
			case WhichGoto.default_: return "goto default;";
			case WhichGoto.case_: return "goto case;";
			case WhichGoto.caseExp: return "goto case "~e.toString()~";";
		}
	}
}
class WithStm: Statement{
	Expression e; Statement s;
	this(Expression exp, Statement statement){e=exp; s=statement;}
	override string toString(){return "with("~e.toString()~") "~s.toString();}
}
class SynchronizedStm: Statement{
	Expression e; Statement s;
	this(Expression exp, Statement statement){e=exp; s=statement;}
	override string toString(){return "synchronized"~(e?"("~e.toString()~")":"")~" "~s.toString();}
}
class CatchStm: Statement{
	Expression type;
	Identifier ident;
	Statement statement;
	this(Expression t, Identifier i, Statement s)in{assert(s);}body{type=t; ident=i; statement=s;}
	override string toString(){return "catch"~(type?"("~type.toString()~(ident?" "~ident.toString():"")~")":" ")~statement.toString();}
}
class TryStm: Statement{
	Statement statement;
	CatchStm[] catches;
	Statement finally_;
	this(Statement s,CatchStm[] c, Statement f)in{assert(s&&1);foreach(x;c[0..$-1]) assert(x.type&&1);}body{
		statement=s;
		catches=c;
		finally_=f;
	}
	override string toString(){return "try "~statement.toString()~join(map!(to!string)(catches),"\n")~(finally_?"\nfinally "~finally_.toString():"");}
}
class ThrowStm: Statement{
	Expression e;
	this(Expression exp){e=exp;}
	override string toString(){return "throw "~e.toString()~";";}
}
enum WhichScopeGuard{
	exit,
	success,
	failure,
}
class ScopeGuardStm: Statement{
	WhichScopeGuard w; Statement s;
	this(WhichScopeGuard which, Statement statement){w=which; s=statement;}
	override string toString(){
		string r;
		switch(w){
			case WhichScopeGuard.exit: r="scope(exit) "; break;
			case WhichScopeGuard.success: r="scope(success) "; break;
			case WhichScopeGuard.failure: r="scope(failure) "; break;
			default: assert(0);
		}
		return r~s.toString();
	}
}
class AsmStm: Statement{
	Code asmcode; // TODO: Implement inline assembler parsing
	this(Code ac){asmcode=ac;}
	override string toString(){return "asm{ "~join(map!(to!string)(asmcode)," ")~" } /* TODO: fix this */";}
}
class MixinStm: Statement{
	Expression e;
	this(Expression exp){e=exp;}
	override string toString(){return "mixin("~e.toString()~");";}
}
// expression parser:
// left binding power
template lbp(TokenType type){enum lbp=getLbp(type);}
// right binding power: ^^, (op)= bind weaker to the right than to the left, '.' binds only primaryExpressions
template rbp(TokenType type){enum rbp=type==Tok!"."?180:lbp!type-(type==Tok!"^^"||lbp!type==30);}

auto arrLbp=mixin({string r="[";foreach(t;EnumMembers!TokenType) r~=to!string(getLbp(t))~",";return r~"]";}());

int getLbp(TokenType type) pure{ // operator precedence
	switch(type){
	//case Tok!"..": return 10; // range operator
	case Tok!",":  return 20; // comma operator
	// assignment operators
	case Tok!"/=",Tok!"&=",Tok!"|=",Tok!"-=":
	case Tok!"+=",Tok!"<<=",Tok!">>=", Tok!">>>=":
	case Tok!"=",Tok!"*=",Tok!"%=",Tok!"^=":
	case Tok!"^^=",Tok!"~=": 
		return 30;
	case Tok!"?":  return 40; // conditional operator
	case Tok!"||": return 50; // logical OR
	case Tok!"&&": return 60; // logical AND
	case Tok!"|":  return 70; // bitwise OR
	case Tok!"^":  return 80; // bitwise XOR
	case Tok!"&":  return 90; // bitwise AND
	// relational operators
	case Tok!"==",Tok!"!=",Tok!">",Tok!"<":
	case Tok!">=",Tok!"<=",Tok!"!>",Tok!"!<":
	case Tok!"!>=",Tok!"!<=",Tok!"<>",Tok!"!<>":
	case Tok!"<>=", Tok!"!<>=":
	case Tok!"in", Tok!"!in" ,Tok!"is",Tok!"!is":
		return 100;
	// bitwise shift operators
	case Tok!">>": return 110;
	case Tok!"<<": return 110;
	case Tok!">>>":return 110;
	// additive operators
	case Tok!"+",Tok!"-",Tok!"~": 
		return 120;
	// multiplicative operators
	case Tok!"*",Tok!"/",Tok!"%":
		return 130;
	/*/ prefix operators
	case Tok!"&",Tok!"++",Tok!"--",Tok!"*":
	case Tok!"-",Tok!"+",Tok!"!",Tok!"~":
		return 140;  */
	case Tok!"^^": return 150; // power
	// postfix operators
	case Tok!".",Tok!"++",Tok!"--":
	case Tok!"(", Tok!"[": // function call and indexing
		return 160;
	// template instantiation
	case Tok!"!":  return 170;
	//case Tok!"i": return 45; //infix
	default: return -1;
	}
}

enum literals=["``","``c","``w","``d","''","0","0U","0L","0LU",".0f",".0",".0L",".0fi",".0i",".0Li","null","true","false"];
template isLiteral(TokenType type){
	enum isLiteral = canFind(literals,TokChars!type);
}
// unary exp binding power
enum nbp=140;
template isUnaryOp(TokenType type){
	enum isUnaryOp = canFind(["&", "*", "-", "++", "--", "+", "!", "~"],TokChars!type);
}
template isSimplePostfixOp(TokenType type){
	enum bool isSimplePostfixOp = canFind([/*".",*/ "++", "--"],TokChars!type);
}
template isPostfixOp(TokenType type){
	enum bool isPostfixOp = isSimplePostfixOp!type || canFind(["(", "["],TokChars!type);
}
template isBinaryOp(TokenType type){
	enum bool isBinaryOp = lbp!type!=-1 && !isPostfixOp!type;
}

enum basicTypes=["bool","byte","ubyte","short","ushort","int","uint","long","ulong","char","wchar","dchar","float","double","real","ifloat","idouble","ireal","cfloat","cdouble","creal","void"];

enum storageClasses=protectionAttributes~["ref","auto ref","abstract","align","auto",/*"auto ref",*/"const","deprecated","enum","extern","final","immutable","in","inout","lazy","nothrow","out","override","pure","__gshared",/*"ref",*/"scope","shared","static","synchronized"]; // ref and auto ref taken to the front for easier handling by STCtoString

immutable toplevelSTC=protectionAttributes~["abstract","align","auto","auto ref","const","deprecated","enum","extern","final","immutable","inout","shared","nothrow","override","pure","__gshared","ref","scope","static","synchronized"]; // TODO: protection attributes must always come first!

immutable protectionAttributes=["export","package","private","protected","public"];

immutable attributeSTC=["property","safe","trusted","system","disable"];

immutable functionSTC=["const","immutable","inout","nothrow","pure","shared"];

immutable parameterSTC=["auto","const","final","immutable","in","inout","lazy","out","ref","scope","shared"];

enum typeQualifiers=["const","immutable","shared","inout"];

private string STCEnum(){
	string r="enum{";
	foreach(i,s;storageClasses~attributeSTC) r~="STC"~(s=="auto ref"?"autoref":s)~"="~to!string(1L<<i)~",";
	return r~"}";
}
//enum{STC...}; Solved this way because most storage classes are keywords and composition will be sane
mixin(STCEnum());
static assert(storageClasses.length+attributeSTC.length<64);
alias long STC;
string STCtoString(STC stc){
	if(!stc) return "";
	/*STC fstc=stc&-stc;
	stc-=fstc;
	int n=0; while(1<<n<fstc) n++;
	string r=n>=storageClasses.length?"@"~attributeSTC[n-storageClasses.length]:storageClasses[n]; */
	string r;
	foreach(i,s;storageClasses) if(stc&(1L<<i)) r~=" "~s;
	foreach(i,s;attributeSTC) if(stc&(1L<<(storageClasses.length+i))) r~=" @"~s;
	return r[1..$];
}

private string getTTCases(string[] s,string[] excl = []){
	string r="case ";
	foreach(x;s) if(!excl.canFind(x)) r~="Tok!\""~x~"\",";
	return r[0..$-1]~":";
}

template isBasicType(TokenType type){
	enum bool isBasicType = canFind(basicTypes,TokChars!type);
}

immutable leftDelimiters=["(","{","["];

template isLeftDelimiter(TokenType type){
	enum bool isLeftDelimiter = canFind(leftDelimiters,TokChars!type) !=null;
}
template matchingDelimiter(TokenType left) if(isLeftDelimiter){
	enum matchingDelimiter = {
		switch(left){
			case Tok!"(": return Tok!")";
			case Tok!"{": return Tok!"}";
			case Tok!"[": return Tok!"]";
			default: assert(0);
		}
	}();
}
//Private template isCode(R){enum isCode=isForwardRange!R && is(Unqual!(ElementType!R) == Token);}


private template getParseProc(T...){
	static if(is(T[0]==AssignExp)) enum prc=`parseExpression(rbp!(Tok!","))`, off=2;
	else static if(is(T[0]==ArgumentList)||is(T[0]==AssocArgumentList)||is(T[0]==Tuple)){ // ArgumentList, AssocArgumentList can take optional parameters
		static if(T[2][0]=='('&&T[2][$-1]==')')
			enum prc=`parse`~T[0].stringof~`!`~T[3].stringof~T[2], off=3;
		else enum prc=`parse`~T[0].stringof~`!`~T[2].stringof~"()", off=2;
	}else static if(is(T[0]==StorageClass)) enum prc="parseSTC!toplevelSTC()", off=2;
	else static if(is(T[0]==CondDeclBody)) enum prc="parseCondDeclBody(flags)", off=2; // flags is a variable in parseDeclDef
	else enum prc="parse"~T[0].stringof~"()", off=2;
}
//dummy structs for some of the parsing procedures:
private{
	struct StorageClass{}   struct ArgumentList{}          struct AssocArgumentList{}
	struct IdentifierList{} struct AssignExp{}             struct Condition{}
	struct Existing{}       struct DebugCondition{}        struct VersionCondition{}
	struct CondDeclBody{}   struct OptTemplateConstraint{} struct TemplateParameterList{}
	struct Tuple{}          struct TypeOrExpression{}      struct Initializer{}
	struct DeclDef{}
}
private template TTfromStr(string arg){ // turns "a,b,c,..." into TypeTuple(a,b,c,...)
	alias TypeTuple!(mixin("TypeTuple!("~arg~")")) TTfromStr;
}

private template doParseImpl(bool d,T...){
	static if(T.length==0) enum doParseImpl="";
	else static if(is(typeof(T[0]):string)) enum doParseImpl={
			static if(T[0].length>3 && T[0][0..3]=="OPT") return doOptParse!(TTfromStr!(T[0][3..$]))~doParseImpl!(d,T[1..$]);
			else switch(T[0]){
				case "_": return "nextToken();\n"~doParseImpl!(d,T[1..$]);
				case "NonEmpty":
					enum what=is(T[1]==CondDeclBody)?"declaration":"statement";
					return `nonEmpty!"`~what~`"();`"\n"~doParseImpl!(d,T[1..$]);
				case "OPT":
				static if(T[0]=="OPT")
					return (d?"auto ":"")~T[2]~" = tok.type==Tok!\""~T[3]~"\" || tok.type==Tok!\")\" ? null : "~
						"parse"~T[1].stringof~"();\n"~doParseImpl!(d,T[3..$]);
				default: return "expect(Tok!\""~T[0]~"\");\n"~doParseImpl!(d,T[1..$]);;
			}
		}();
	else static if(is(T[0]==Existing)) alias doParseImpl!(d,T[2..$]) doParseImpl;
	else enum doParseImpl=(d?"auto ":"")~T[1]~" = "~getParseProc!T.prc~";\n"~doParseImpl!(d,T[getParseProc!T.off..$]);
}

private template doParse(T...){ alias doParseImpl!(true,T) doParse; }
private template doParseNoDef(T...){ alias doParseImpl!(false,T) doParseNoDef; }

private template parseDefOnly(T...){
	static if(T.length==0) enum parseDefOnly="";
	else static if(is(typeof(T[0]):string)){
		static if(T[0]=="OPT") alias parseDefOnly!(T[1..$]) parseDefOnly;
		else alias parseDefOnly!(T[1..$]) parseDefOnly;
	}else static if(is(T[0]==Existing)) alias parseDefOnly!(T[2..$]) parseDefOnly;
	else enum parseDefOnly="typeof("~getParseProc!T.prc~") "~T[1]~"=null;\n"~parseDefOnly!(T[2..$]);
}
private template doOptParse(T...){
	static assert(is(typeof(T[0]):string));
	enum doOptParse=parseDefOnly!T~"if(tok.type==Tok!\""~T[0]~"\"){\n"~doParseImpl!(false,"_",T[1..$])~"}\n";
}

private template fillParseNamesImpl(int n,string b,T...){ // val: new TypeTuple, off: that many names have been filled in
	static if(T.length==0){alias T val; enum off=0;}
	else static if(is(typeof(T[0])==string)){
		static if(T[0].length>3 && T[0][0..3]=="OPT"){
			private alias fillParseNamesImpl!(n,b,TTfromStr!(T[0][3..$])) a;
			static assert(a.val.stringof[0..6]=="tuple(", "apparently something has finally been fixed");
			alias TypeTuple!("OPT"~a.val.stringof[6..$-1],fillParseNamesImpl!(n+a.off,b,T[1..$]).val) val;
			alias a.off off;
		}else{
			private alias fillParseNamesImpl!(n,b,T[1..$]) rest;
			alias TypeTuple!(T[0],rest.val) val;enum off=rest.off;
		}
	}else static if(is(T[0]==Existing)){
		private alias fillParseNamesImpl!(n,b,T[2..$]) rest;
		alias TypeTuple!(T[0],T[1],rest.val) val; enum off=rest.off;
	}else{
		private alias fillParseNamesImpl!(n+1,b,T[1..$]) rest;
		alias TypeTuple!(T[0],b~to!string(n),rest.val) val;enum off=rest.off+1;
	}
}

private template fillParseNames(string base,T...){
	alias fillParseNamesImpl!(0,base,T).val fillParseNames;
}
private template getParseNames(T...){
	static if(T.length==0) enum getParseNames=""; // next line: ':' instead of '==' is workaround
	else static if(!is(typeof(T[0]):string)) enum getParseNames=T[1]~","~getParseNames!(T[2..$]);
	else{
		static if(T[0].length>3 && T[0][0..3]=="OPT") enum getParseNames=getParseNames!(TTfromStr!(T[0][3..$]))~getParseNames!(T[1..$]);
		else enum getParseNames=getParseNames!(T[1..$]);
	}
}

private template rule(T...){ // applies a grammar rule and returns the result
	enum rule={
		alias fillParseNames!("e",T[1..$]) a;
		return doParse!(a)~"return new "~T[0].stringof~"("~getParseNames!a~");";
	}();
}


alias immutable(Token)[] Code;

private struct Parser{
	enum filename = "tt.d";
	Code code;
	Location loc;
	int muteerr=0;
	this(Code code){
		this.code = code;
		this.loc = Location(filename,1);
		if(tok.type==Tok!"Error"){loc.error(tok.str);}
		for(;;nextToken){
			if(tok.type==Tok!"\n") loc.line++;
			else if(tok.type!=Tok!"Error") break;
		}
	}
	@property ref immutable(Token) tok(){return code[0];}
	void nextToken(){
	tryagain:
		if(tok.type==Tok!"EOF") return;
		code.popFront();
		if(tok.type==Tok!"\n"){loc.line++; goto tryagain;}
		else if(tok.type==Tok!"Error" && !muteerr){loc.error(tok.str); goto tryagain;}
	}
	struct State{Location loc; Code code;}
	State saveState(){muteerr++; return State(loc, code);} // saves the state and mutes all error messages until the state is restored
	void restoreState(State state){muteerr--; loc=state.loc; code=state.code;}
	Token peek(int x=1){
		auto save = saveState();
		foreach(i;0..x) nextToken();
		auto t=tok;
		restoreState(save);
		return t;
	}
	Token peekPastParen(){
		auto save = saveState();
		nextToken();
		skipToUnmatched();
		nextToken();
		auto t=tok;
		restoreState(save);
		return t;
		
	}
	static class ParseErrorException: Exception{this(string s){super(s);}} alias ParseErrorException PEE;
	void error(string msg){loc.error(msg);}
	void expect(TokenType type){
		if(tok.type==type) nextToken();
		else{ // employ some bad heuristics to avoid cascading error messages. TODO: make this better
			if(tok.type==Tok!"__error") error("expected '"~Token(type).toString()~"'");
			else error("found '" ~ tok.toString() ~ "' when expecting '" ~ Token(type).toString() ~"'");
			if(tok.type!=Tok!")" && tok.type!=Tok!"}" && tok.type!=Tok!"]"){
				nextToken();
				if(tok.type==type) nextToken();
			}
		}
	}
	void expectErr(string what)(){
		if(tok.type==Tok!"__error") error("expected "~what);
		else error("found '" ~ tok.toString() ~ "' when expecting " ~ what);
		if(tok.type!=Tok!")" && tok.type!=Tok!"}" && tok.type!=Tok!"]") nextToken();
	}
	bool skip(TokenType type){
		if(tok.type != type) return false;
		nextToken(); return true;
	}
	bool skip(){nextToken(); return true;}
	auto dp(alias a, T...)(T args){ // dynamic dispatch based on token type (TODO: redesign, too much code replication)
		final switch(tok.type){
			mixin({
				string r;
				foreach(t;__traits(allMembers, TokenType)) r~=`case TokenType.` ~ t ~ `:  return a!(TokenType.` ~ t ~ `)(args);`;
				return r;
			}());
		}
	}
	Identifier parseIdentifier(){ // Identifier(null) is the error value
		string name;
		if(tok.type==Tok!"i") name=tok.name;
		else expectErr!"identifier"();
		auto e=new Identifier(name); nextToken();
		return e;
	}
	Expression parseIdentifierList(T...)(T args){
		TokenType tt;
		Expression e;
		void errori(){expectErr!"identifier following '.'"();}
		static if(T.length==0){
			if(tok.type==Tok!"."){nextToken(); e = new Identifier(""); goto middle;}
			if(tok.type!=Tok!"i"){expectErr!"identifier"(); return new ErrorExp;}
			e = new Identifier(tok.str); nextToken();
		}else{e=args[0]; goto middle;}
		for(;;){
			if(tok.type==Tok!"."){
				nextToken(); 
			middle:
				if(tok.type!=Tok!"i"){errori(); return new BinaryExp!(Tok!".")(e,new ErrorExp);}
				e = new BinaryExp!(Tok!".")(e,new Identifier(tok.str));
				nextToken();
			}else if(tok.type==Tok!"!" && (tt=peek().type)!=Tok!"in" && tt!=Tok!"is"){e=led!(Tok!"!")(e);}
			else break;
		}
		return e;
	}
	bool skipIdentifierList(){
		TokenType tt;
		skip(Tok!".");
		if(!skip(Tok!"i")) return false;
		for(;;){
			if(skip(Tok!".")){if(!skip(Tok!"i")) return false;}
			else if(tok.type==Tok!"!" && (tt=peek().type)!=Tok!"in" && tt!=Tok!"is"){
				nextToken();
				if(tok.type==Tok!"("){
					nextToken();
					if(!skipToUnmatched()||!skip(Tok!")")) return false;
				}else skip();
			}else return true;
		}
	}
	// allows only non-associative expressions
	Expression[] parseArgumentList(string delim, bool nonempty=false, Entry=AssignExp, T...)(T args){
		Expression[] e;
		foreach(x;args) e~=x; // static foreach
		static if(args.length) if(tok.type==Tok!",") nextToken(); else return e;
		static if(!nonempty) if(tok.type==Tok!delim) return e;
		do{
			mixin(doParse!(Entry,"e1")); e~=e1;
			if(tok.type==Tok!",") nextToken();
			else break;
		}while(tok.type!=Tok!delim && tok.type!=Tok!"EOF");
		return e;
	}
	// allows interspersed associative and non-associative expressions. Entry.key must be a subset of Entry.value
	Expression[] parseAssocArgumentList(string delim, bool nonempty=false, Entry=ArrayAssocExp, T...)(T args) if(T.length%2==0){
		alias typeof({Entry x; return x.key;}()) Key;
		alias typeof({Entry x; return x.value;}()) ValueType;
		static if(is(Entry==ArrayInitAssocExp)||is(Entry==StructAssocExp)) alias InitializerExp Value;
		else static if(is(ValueType==Expression)) alias AssignExp Value;
		else alias ValueType Value;
		Expression[] e;
		e.length=args.length/2;
		foreach(i,x;args) e[i/2][i%2]=x; // static foreach
		static if(args.length) if(tok.type==Tok!",") nextToken();
		static if(!nonempty) if(tok.type==Tok!delim) return e;
		do{
			mixin(doParse!(Value,"e1"));
			auto e2=cast(Key)e1;
			if(tok.type==Tok!":" && e2){
				mixin(doParse!("_",Value,"e3"));
				e~=new Entry(e2,e3);
			}else e~=e1;
			if(tok.type==Tok!",") nextToken();
			else break;
		}while(tok.type!=Tok!delim && tok.type!=Tok!"EOF");
		return e;
	}
	Expression parseTypeOrExpression(){
		Expression e;
		auto save=saveState();
		auto ist=skipType()&&(tok.type==Tok!","||tok.type==Tok!")");
		restoreState(save);
		e=ist?parseType():parseExpression(rbp!(Tok!","));
		return e;
	}
	Expression[] parseTuple(string delim, bool nonempty=false)(){
		Expression[] e;
		static if(!nonempty) if(tok.type==Tok!delim) return e;
		do{
			e~=parseTypeOrExpression();
			if(tok.type==Tok!",") nextToken();
			else break;
		}while(tok.type!=Tok!delim && tok.type!=Tok!"EOF");
		return e;
	}
	Expression parseTemplateSingleArg(){
		switch(tok.type){
			case Tok!"i": 
				{auto e = new Identifier(tok.name); nextToken(); return e;}
			mixin(getTTCases(basicTypes));
				{auto e = new BasicType(tok.type); nextToken(); return e;}
			mixin(getTTCases(literals));
				{auto e = new LiteralExp(tok); nextToken(); return e;}
			default: expectErr!"template argument"();
		}
		return new ErrorExp;
	}
	// Operator precedence expression parser
	// null denotation
	Expression nud(TokenType type)() {
		static if(type==Tok!"i" || type == Tok!".") return parseIdentifierList();
		else static if(isBasicType!type){mixin(doParse!("_","."));return parseIdentifierList(new BasicType(type));}
		else static if(type==Tok!"``"||type==Tok!"``c"||type==Tok!"``w"||type==Tok!"``d"){ // adjacent string tokens get concatenated
			Token t=tok;
			static if(type!=Tok!"``") for(nextToken();tok.type==type||tok.type==Tok!"``";nextToken()) t.str~=tok.str;
			else for(nextToken();tok.type==Tok!"``";nextToken()) t.str~=tok.str;
			return new LiteralExp(t);
		}else static if(isLiteral!type){auto e=new LiteralExp(tok); nextToken(); return e;}
		else static if(type == Tok!"this"){mixin(rule!(ThisExp,"_"));}
		else static if(type == Tok!"super"){mixin(rule!(SuperExp,"_"));}
		else static if(type == Tok!"$"){mixin(rule!(DollarExp,"_"));}
		else static if(type == Tok!"cast"){
			nextToken(); expect(Tok!"(");
			STC stc;
			Expression tt=null;
			if(tok.type!=Tok!")"){
				stc=parseSTC!toplevelSTC();
				if(tok.type!=Tok!")") tt=parseType();
			}
			expect(Tok!")");
			auto e=dp!nud();
			return new CastExp(stc,tt,e);
		}else static if(type == Tok!"is"){
			mixin(doParse!("_","(",Type,"type"));
			Identifier ident; // optional
			if(tok.type==Tok!"i") ident=new Identifier(tok.name), nextToken();
			auto which = WhichIsExp.type;
			if(tok.type==Tok!":") which = WhichIsExp.implicitlyConverts;
			else if(tok.type==Tok!"==") which = WhichIsExp.isEqual;
			else if(tok.type==Tok!"*=" && peek().type==Tok!"=") type = new Pointer(type), nextToken(), which=WhichIsExp.isEqual; // EXTENSION
			else{expect(Tok!")");return new IsExp(which,type,ident,null,Tok!"",null);}
			nextToken();
			Expression typespec=null;
			TokenType typespec2=Tok!"";
			if(which==WhichIsExp.isEqual){
				switch(tok.type){
					case Tok!"const", Tok!"immutable", Tok!"inout", Tok!"shared":
						auto tt=peek().type; if(tt==Tok!","||tt==Tok!")") goto case; goto default;
					case Tok!"struct", Tok!"union", Tok!"class", Tok!"interface", Tok!"enum", Tok!"function", Tok!"delegate", 
						 Tok!"super", Tok!"return", Tok!"typedef":
						typespec2=tok.type; nextToken(); break;
					default: goto parsetype;
			}
			}else parsetype: typespec=parseType();
			TemplateParameter[] tparams = null;
			if(tok.type==Tok!","){
				nextToken();
				if(ident&&tok.type!=Tok!")") tparams = parseTemplateParameterList();
			}
			expect(Tok!")");
			return new IsExp(which,type,ident,typespec,typespec2,tparams);
		}else static if(type == Tok!"__traits"){mixin(rule!(TraitsExp,"_","(",Tuple,")"));}
		else static if(type == Tok!"delete"){mixin(rule!(DeleteExp,"_",Expression));}
		else static if(type == Tok!"__error"){mixin(rule!(ErrorExp,"_"));}
		else static if(type==Tok!"("){
			if(peekPastParen().type==Tok!"{") return parseFunctionLiteralExp();
			nextToken();
			auto save=saveState();
			bool isType=skipType() && tok.type==Tok!")";
			restoreState(save);
			Expression e;
			if(isType){mixin(doParseNoDef!(Type,"e",")"));} // does not necessarily parse a type, eg arr[10]
			else{mixin(doParseNoDef!(Expression,"e",")"));}
			e.brackets++;
			return e;
		}else static if(typeQualifiers.canFind(TokChars!type)){
			nextToken(); expect(Tok!"(");
			auto e=parseType(); e.brackets++;
			expect(Tok!")");
			return new QualifiedType!type(e);
		}else static if(type==Tok!"{" || type==Tok!"delegate" || type==Tok!"function") return parseFunctionLiteralExp(); // TODO: struct literals
		else static if(type==Tok!"["){
			nextToken(); if(tok.type==Tok!"]") return nextToken(), new ArrayLiteralExp(null);
			mixin(rule!(ArrayLiteralExp,AssocArgumentList,"]"));
		}else static if(isUnaryOp!type){nextToken(); return new UnaryExp!type(parseExpression(nbp));}
		else static if(type == Tok!"new"){
			nextToken();
			if(tok.type==Tok!"class"){
				mixin(doParse!("_","OPT"q{"(",ArgumentList,"args",")"}));
				auto aggr=cast(ClassDecl)cast(void*)parseAggregateDecl(STC.init,true); // it is an anonymous class, static cast is safe
				return new NewClassExp(args,aggr);
			}else{mixin(rule!(NewExp,"OPT"q{"(",ArgumentList,")"},Type,"OPT"q{"(",ArgumentList,")"}));}
		}else static if(type == Tok!"assert"){mixin(rule!(AssertExp,"_","(",ArgumentList,")"));}
		else static if(type == Tok!"mixin"){mixin(rule!(MixinExp,"_","(",AssignExp,")"));}
		else static if(type == Tok!"import"){mixin(rule!(ImportExp,"_","(",AssignExp,")"));}
		else static if(type == Tok!"typeid"){mixin(rule!(TypeidExp,"_","(",TypeOrExpression,")"));}
		else static if(type==Tok!"typeof"){
			nextToken(); expect(Tok!"(");
			if(tok.type==Tok!"return"){nextToken(); expect(Tok!")"); return new TypeofReturnExp();}
			mixin(doParse!(Expression,"e1",")"));
			Expression e2=new TypeofExp(e1);
			if(tok.type==Tok!"."){nextToken(); e2=parseIdentifierList(e2);}
			return e2;
		}
		else throw new PEE("invalid unary operator '"~tok.toString()~"'");
	}
	// left denotation
	Expression led(TokenType type)(Expression left){
		//static if(type == Tok!"i") return new CallExp(new BinaryExp!(Tok!".")(left,new Identifier(self.name)),parseExpression(45));else // infix
		static if(type == Tok!"?"){mixin(rule!(TernaryExp,"_",Existing,"left",Expression,":",Expression));}
		else static if(type == Tok!"["){
			nextToken();
			if(tok.type==Tok!"]"){nextToken(); return new IndexExp(left,[]);}
			auto l=parseExpression(rbp!(Tok!","));
			if(tok.type==Tok!".."){nextToken(); auto r=parseExpression(rbp!(Tok!",")); expect(Tok!"]"); return new SliceExp(left, l,r);}
			else{auto e=new IndexExp(left,parseArgumentList!"]"(l)); expect(Tok!"]"); return e;}
		}
		else static if(type == Tok!"("){mixin(rule!(CallExp,"_",Existing,"left",ArgumentList,")"));}
		else static if(type == Tok!"!"){
			nextToken();
			if(tok.type==Tok!"is") return led!(Tok!"!is")(left);
			else if(tok.type==Tok!"in") return led!(Tok!"!in")(left);
			if(tok.type==Tok!"("){
				nextToken(); auto e=new TemplateInstanceExp(left,parseTuple!")");
				if(e.args.length==1) e.args[0].brackets++; expect(Tok!")"); return e;
			}
			return new TemplateInstanceExp(left,[parseTemplateSingleArg()]);
		}
		else static if(type == Tok!"."){nextToken(); return parseIdentifierList(left);}
		else static if(isBinaryOp!type){nextToken(); return new BinaryExp!type(left,parseExpression(rbp!type));}
		else static if(isPostfixOp!type){nextToken();return new PostfixExp!type(left);}
		else throw new PEE("invalid binary operator '"~TokChars!type~"'");
	}
	Expression parseExpression(int rbp = 0){
		Expression left;
		try left = dp!nud();catch(PEE err){error("found '"~tok.toString()~"' when expecting expression");nextToken();return new ErrorExp();}
		while(rbp < arrLbp[tok.type]){ // TODO: replace with array lookup
			try left = dp!led(left); catch(PEE err){error(err.msg);}
		}
		return left;
	}
	Expression parseExpression2(Expression left, int rbp = 0){ // already know what left is
		while(rbp < arrLbp[tok.type]){ // TODO: replace with array lookup
			try left = dp!led(left); catch(PEE err){error(err.msg);}
		}
		return left;
	}
	bool skipToUnmatched(bool skipcomma=true)(){
		int pnest=0, cnest=0, bnest=0; // no local templates >:(
		for(;;nextToken()){
			switch(tok.type){
				case Tok!"(": pnest++; continue;
				case Tok!"{": cnest++; continue;
				case Tok!"[": bnest++; continue;
				case Tok!")": if(pnest--) continue; break;
				case Tok!"}": if(cnest--) continue; break;
				case Tok!"]": if(bnest--) continue; break;
				static if(!skipcomma) case Tok!",": if(pnest) continue; break;
				case Tok!";": if(cnest) continue; break;
				case Tok!"EOF": return false;
				//case Tok!"..": if(bnest) continue; break;
				default: continue;
			}
			break;
		}
		return true;
	}
	void nonEmpty(string what="statement")(){if(tok.type==Tok!";") error("use '{}' for an empty "~what~", not ';'");}
	Statement parseStmError(){
		while(tok.type != Tok!";" && tok.type != Tok!"}" && tok.type != Tok!"EOF") nextToken();
		if(tok.type == Tok!";") nextToken();
		return new ErrorStm;
	}
	private static template pStm(T...){
		enum pStm="case Tok!\""~T[0]~"\":\n"~rule!(mixin(T[0][0]+('A'-'a')~T[0][1..$]~"Stm"),"_",T[1..$]);
	}
	Statement parseStatement(){
		bool isfinal = false; //for final switch
		bool isreverse = false; //for foreach_reverse
		if(tok.type == Tok!"i" && peek().type == Tok!":"){
			auto l = new Identifier(tok.name);
			nextToken(); nextToken();
			return new LabeledStm(l,parseStatement());
		}
		switch(tok.type){
		    case Tok!";":
			    nextToken();
				return new Statement;
		    case Tok!"{":
				auto r=parseCompoundStm();
				if(tok.type!=Tok!"(") return r;
				else{
					auto e=parseExpression2(new FunctionLiteralExp(null,r));
					expect(Tok!";");
					return new ExpressionStm(e);
				}
			mixin(pStm!("if","(",Condition,")","NonEmpty",Statement,"OPT"q{"else","NonEmpty",Statement}));
			mixin(pStm!("while","(",Condition,")","NonEmpty",Statement));
			mixin(pStm!("do","NonEmpty",Statement,"while","(",Expression,")",";"));
			mixin(pStm!("for","(",Statement,"OPT",Condition,";","OPT",Expression,")","NonEmpty",Statement));
			case Tok!"foreach_reverse":
				isreverse=true;
			case Tok!"foreach": 
				nextToken();
				expect(Tok!"(");
				Parameter[] vars;
				do{
					auto stc=STC.init;
					if(tok.type==Tok!"ref") stc=STCref;
					stc|=parseSTC!toplevelSTC();
					Expression type;
					TokenType tt;
					if(tok.type!=Tok!"i" || (tt=peek().type)!=Tok!"," && tt!=Tok!";") type=parseType();
					auto name=parseIdentifier();
					vars~=new Parameter(stc,type,name,null);
					if(tok.type==Tok!",") nextToken();
					else break;
				}while(tok.type!=Tok!";" && tok.type!=Tok!"EOF");
				expect(Tok!";");
				auto e=parseExpression();
				if(vars.length==1&&tok.type==Tok!".."){
					nextToken();
					auto e2=parseExpression();
					expect(Tok!")"); nonEmpty();
					return new ForeachRangeStm(vars[0],e,e2,parseStatement(),isreverse);
				}
				expect(Tok!")"); nonEmpty();
				return new ForeachStm(vars,e,parseStatement(),isreverse);
			case Tok!"final":
				if(peek().type != Tok!"switch") goto default;
				nextToken();
				isfinal=true;
			case Tok!"switch":
				mixin(doParse!("_","(",Expression,"e",")","NonEmpty",Statement,"s"));
				return new SwitchStm(isfinal,e,s);
			case Tok!"case":
				Expression[] e;
				Statement[] s;
				bool isrange=false;
				nextToken();
				e = parseArgumentList!(":",true)(); // non-empty!
				expect(Tok!":");				
				
				if(tok.type == Tok!".."){ // CaseRange
					isrange=true;
					if(e.length>1) error("only one case allowed for start of case range");
					e.length=2;
					nextToken();
					expect(Tok!"case");
					e[1]=parseExpression(lbp!(Tok!","));
					expect(Tok!":");
				}
				
				while(tok.type!=Tok!"case" && tok.type!=Tok!"default" && tok.type!=Tok!"}"&&tok.type!=Tok!"EOF") s~=parseStatement();
				return isrange?new CaseRangeStm(e[0],e[1],s):new CaseStm(e,s);
			case Tok!"default":
				mixin(doParse!("_",":"));
				Statement[] s;
				while(tok.type!=Tok!"case" && tok.type!=Tok!"default" && tok.type!=Tok!"}"&&tok.type!=Tok!"EOF") s~=parseStatement();
				return new DefaultStm(s);
			case Tok!"continue":
				nextToken();
				Statement r;
				if(tok.type==Tok!"i") r=new ContinueStm(new Identifier(tok.name)), nextToken();
				else r=new ContinueStm(null);
				expect(Tok!";");
				return r;
			//mixin(pStm!("break", "OPT", Identifier, ";");
			case Tok!"break":
				nextToken();
				Statement r;
				if(tok.type==Tok!"i") r=new BreakStm(new Identifier(tok.name)), nextToken();
				else r=new BreakStm(null);
				expect(Tok!";");
				return r;
			mixin(pStm!("return","OPT",Expression,";"));
			case Tok!"goto":
				nextToken();
				switch(tok.type){
					case Tok!"i":
						auto r=new GotoStm(WhichGoto.identifier,new Identifier(tok.name));
						nextToken(); expect(Tok!";");
						return r;
					case Tok!"default":
						nextToken();
						expect(Tok!";");
						return new GotoStm(WhichGoto.default_,null);
					case Tok!"case":
						nextToken();
						if(tok.type == Tok!";"){nextToken(); return new GotoStm(WhichGoto.case_,null);}
						auto e = parseExpression();
						expect(Tok!";");
						return new GotoStm(WhichGoto.caseExp,e);
					default:
						expectErr!"location following goto"();
						return parseStmError();
				}
			mixin(pStm!("with","(",Expression,")","NonEmpty",Statement));
			mixin(pStm!("synchronized","OPT"q{"(",Expression,")"},Statement));
			case Tok!"try":
				mixin(doParse!("_",Statement,"ss"));
				CatchStm[] catches;
				do{ // TODO: abstract loop away, as soon as compile memory usage is better
					mixin(doParse!("catch","OPT"q{"(",Type,"type","OPT",Identifier,"ident",")"},"NonEmpty",Statement,"s"));
					catches~=new CatchStm(type,ident,s);
					if(!type) break; // this really should work as loop condition!
				}while(tok.type==Tok!"catch");
				mixin(doParse!("OPT"q{"finally",Statement,"finally_"}));
				return new TryStm(ss,catches,finally_);
			mixin(pStm!("throw",Expression,";"));
			case Tok!"scope":
				if(peek().type != Tok!"(") goto default;
				nextToken(); nextToken();
				WhichScopeGuard w;
				if(tok.type != Tok!"i"){expectErr!"scope identifier"(); return parseStmError();}
				switch(tok.name){
					case "exit": w=WhichScopeGuard.exit; break;
					case "success": w=WhichScopeGuard.success; break;
					case "failure": w=WhichScopeGuard.failure; break;
					default: error("valid scope identifiers are exit, success, or failure, not "~tok.name); return parseStmError();
				}
				nextToken();
				expect(Tok!")");
				return new ScopeGuardStm(w,parseStatement());
			case Tok!"asm":
				nextToken();
				expect(Tok!"{");
				//error("inline assembly not implemented yet!");
				auto start = code.ptr;
				for(int nest=1;tok.type!=Tok!"EOF";nextToken()) if(!(tok.type==Tok!"{"?++nest:tok.type==Tok!"}"?--nest:nest)) break;
				auto asmcode=start[0..code.ptr-start];
				expect(Tok!"}");
				return new AsmStm(asmcode);
			case Tok!"mixin":
				if(peek().type!=Tok!"(") goto default; // mixin template declaration
				mixin(doParse!("_","_",AssignExp,"e",")"));
				if(tok.type != Tok!";"){// is mixin expression, not mixin statement
					auto e2=parseExpression2(new MixinExp(e));
					expect(Tok!";");
					return new ExpressionStm(e2);
				}
				nextToken();
				return new MixinStm(e);
			default: // TODO: replace by case list
				if(auto d=parseDeclDef(tryonly|allowstm)) return d;
				auto e = parseExpression(); // note: some other cases may invoke parseExpression2 and return an ExpressionStm!
				expect(Tok!";");
				return new ExpressionStm(e);
			case Tok!")", Tok!"}", Tok!":": // this will be default
				expectErr!"statement"; return parseStmError();
		}
	}
	//auto parse(){return parseStatement();}
	Expression parseType(string expectwhat="type"){
		Expression tt;
		bool brk=false;
		switch(tok.type){
			mixin(getTTCases(basicTypes)); tt = new BasicType(tok.type); nextToken(); break;
			case Tok!".": goto case;
			case Tok!"i": tt=parseIdentifierList(); break;
			mixin({string r;
					foreach(x;typeQualifiers) r~=`case Tok!"`~x~`": nextToken();
if(tok.type==Tok!"(") brk=true, nextToken(); auto e=parseType(); e.brackets+=brk; tt=new QualifiedType!(Tok!"`~x~`")(e);brk&&expect(Tok!")"); break;`;
					return r;}());
			case Tok!"typeof": tt=nud!(Tok!"typeof")(); break;
			default: error("found '"~tok.toString()~"' when expecting "~expectwhat); nextToken(); return new ErrorExp;
		}
		for(;;){
			switch(tok.type){
				case Tok!"*": nextToken(); tt=new Pointer(tt); continue;
				case Tok!"[": 
					auto save = saveState();
					bool isAA=skip()&&skipType()&&tok.type==Tok!"]";
					restoreState(save);
					if(isAA){mixin(doParse!("_",Type,"e","]")); tt=new IndexExp(tt,[e]);}
					else tt=led!(Tok!"[")(tt); continue; //'Bug': allows int[1,2].
				case Tok!"function":
					nextToken();
					VarArgs vararg;
					auto params=parseParameterList(vararg);
					STC stc=parseSTC!functionSTC();
					tt=new FunctionPtr(new FunctionType(stc,tt,params,vararg));
					continue;
				case Tok!"delegate":
					nextToken();
					VarArgs vararg;
					auto params=parseParameterList(vararg);
					STC stc=parseSTC!functionSTC();
					tt=new DelegateType(new FunctionType(stc,tt,params,vararg));
					continue;
				default: break;
			}
			break;
		}
		return tt;
	}
	bool skipType(){
		switch(tok.type){
			mixin(getTTCases(basicTypes)); nextToken(); break;
			case Tok!".": nextToken(); case Tok!"i": 
				if(!skipIdentifierList()) goto Lfalse; break;
			mixin({string r;
					foreach(x;typeQualifiers)
						r~=`case Tok!"`~x~`": nextToken(); bool brk=skip(Tok!"("); if(!skipType()||brk&&!skip(Tok!")")) return false; break;`;
					return r;}());
			case Tok!"typeof":
				nextToken();
				if(!skip(Tok!"(")||!skipToUnmatched()||!skip(Tok!")")) goto Lfalse;
				if(tok.type==Tok!"."){
					nextToken();
					if(!skipIdentifierList()) goto Lfalse;
				}
				break;
			default: goto Lfalse;
		}
	skipbt2: for(;;){
			switch(tok.type){
				case Tok!"*": nextToken(); continue;
				case Tok!"[": 
					nextToken(); 
					if(!skipToUnmatched()||!skip(Tok!"]")) goto Lfalse;
					continue;
				case Tok!"function", Tok!"delegate":
					nextToken();
					if(!skip(Tok!"(")||!skipToUnmatched()||!skip(Tok!")")) goto Lfalse;
					skipSTC!functionSTC();
					continue;
				default: return true;
			}
		}
		Lfalse: return false;
	}
	Expression parseInitializerExp(bool recursive=true){
		if(!recursive&&tok.type==Tok!"void"){nextToken(); return new VoidInitializerExp();}
		else if(tok.type==Tok!"["&&(recursive||peekPastParen().type==Tok!";")){
			nextToken();
			auto e=parseAssocArgumentList!("]",false,ArrayInitAssocExp)();
			expect(Tok!"]");
			return new ArrayLiteralExp(e);
		}else if(tok.type!=Tok!"{") return parseExpression(rbp!(Tok!","));
		else{
			auto save=saveState();
			nextToken();
			for(int nest=1;nest;nextToken()){
				switch(tok.type){
					case Tok!"{": nest++; continue;
					case Tok!"}": nest--; continue;
                    case Tok!";", Tok!"return", Tok!"if", Tok!"while", Tok!"do", Tok!"for", Tok!"foreach",
                         Tok!"switch", Tok!"with", Tok!"synchronized", Tok!"try", Tok!"scope", Tok!"asm", Tok!"pragma": // TODO: complete!
						if(nest!=1) continue; // EXTENSION: This is a DMD bug
						restoreState(save); // if it contains return or ;, it is a delegate literal
						return parseExpression(rbp!(Tok!","));
					case Tok!"EOF": break;
					default: continue;
				}
				break;
			}
			restoreState(save);
			nextToken();
			auto e=parseAssocArgumentList!("}",false,StructAssocExp)();
			expect(Tok!"}");
			return new StructLiteralExp(e);
		}
	}
	STC parseSTC(alias which,bool properties=true)(){
		STC stc,cstc;
	readstc: for(;;){
			switch(tok.type){
				mixin({string r;
						foreach(x;which){
							if(x=="auto ref") continue;
							else r~="case Tok!\""~x~"\": "~(typeQualifiers.canFind(x)?"if(peek().type==Tok!\"(\") break readstc;":"")~
								     (x=="auto"&&(cast(immutable(char[])[])which).canFind("auto ref")?
								      "if(peek().type!=Tok!\"ref\") cstc=STCauto;else{nextToken();cstc=STCautoref;}":
								      "cstc=STC"~x)~";"~"goto Lstc;";
						}
						return r;}());
				static if(properties){
					case Tok!"@":
						nextToken();
						if(tok.type!=Tok!"i"){expectErr!"attribute identifier after '@'"(); nextToken(); continue;}
						switch(tok.name){
							mixin({string r;foreach(x;attributeSTC) r~="case \""~x~"\": cstc=STC"~x~"; goto Lstc;";return r;}());
							default: error("unknown attribute identifier '"~tok.name~"'");
						}
				}
				Lstc:
					if(stc&cstc) error("redundant storage class "~tok.name);
					stc|=cstc;
					nextToken();
					break;
				default:
					break readstc;
			}
		}
		return stc;
	}
	bool skipSTC(alias which,bool properties=true)(){
		bool ret=false;
		for(;;nextToken()){
			switch(tok.type){
				mixin({string r;
						foreach(x;which){
							if(x=="auto ref") continue;
							r~="case Tok!\""~x~"\": "~(typeQualifiers.canFind(x)?"if(peek().type==Tok!\"(\") break;":"")~"ret=true; continue;";
						}
						return r;}());
				case Tok!"@": nextToken(); ret=true; continue;
				default: return ret;
			}
			break;
		}
		return ret;
	}
	CompoundStm parseCompoundStm(){
		expect(Tok!"{");
		Statement[] s;
		while(tok.type!=Tok!"}" && tok.type!=Tok!"EOF"){
			s~=parseStatement();
		}
		expect(Tok!"}");
		return new CompoundStm(s);
	}
	Declaration parseDeclaration(STC stc=STC.init){
		Expression type;
		Declaration d;
		bool isAlias=tok.type==Tok!"alias";
		if(isAlias) nextToken();
		STC nstc, ostc=stc; // hack to make alias this parsing easy. TODO: refactor a little
		stc|=nstc=parseSTC!toplevelSTC();
		bool needtype=true;
		if(tok.type==Tok!"this" || tok.type==Tok!"~"&&peek().type==Tok!"this" || tok.type==Tok!"invariant") needtype=false;
		TokenType p;
		if(needtype&&(!stc||(tok.type!=Tok!"i" || (p=peek().type)!=Tok!"=" && p!=Tok!"("))) type=parseType("declaration");
		if(cast(ErrorExp)type) return new ErrorDecl;
		if(isAlias){
			if(tok.type==Tok!"this"){
				nextToken();
				d=new AliasDecl(ostc,new VarDecl(nstc,type,new ThisExp,null)); expect(Tok!";"); // alias this
			}else d=new AliasDecl(ostc,parseDeclarators(nstc,type));
		}else if(!needtype||peek.type==Tok!"(") d=parseFunctionDeclaration(stc,type);
		else d=parseDeclarators(stc,type);
		return d;
	}
	bool skipDeclaration(){
		TokenType p;
		if(tok.type==Tok!"alias") nextToken();
		if(skipSTC!toplevelSTC()){
			if((tok.type!=Tok!"i"||(p=peek().type)!=Tok!"=") && p!=Tok!"(" && !skipType()) return false;
		}else if(!skipType()) return false;
		return peek().type==Tok!"(" && skipFunctionDeclaration() || skipDeclarators();
	}
	bool isDeclaration(){ // is the parser sitting on the beginning of a Declaration?
		if(tok.type==Tok!"alias") return true;
		auto save=saveState();
		bool res=skipDeclaration();
		restoreState(save);
		return res;
	}
	Expression parseCondition(){
		if(!isDeclaration()) return parseExpression(rbp!(Tok!","));
		else{
			Expression type,init;
			auto stc=parseSTC!toplevelSTC();
			if(!stc||tok.type!=Tok!"i") type=parseType();
			auto name=parseIdentifier();
			if(tok.type!=Tok!"="){expectErr!"initializer for condition"(); skipToUnmatched(); return new ErrorExp;}
			nextToken();
			init=parseExpression(rbp!(Tok!","));
			return new ConditionDeclExp(stc,type,name,init);
		}
	}
	Parameter[] parseParameterList(out VarArgs vararg){
		vararg=VarArgs.none;
		Parameter[] params;
		expect(Tok!"(");
		for(;;){
			STC stc;
			Expression type;
			Identifier name;
			Expression init;
			if(tok.type==Tok!")") break;
			else if(tok.type==Tok!"..."){vararg=VarArgs.cStyle; nextToken(); break;}
			stc=parseSTC!(parameterSTC, false)(); // false means no @attributes allowed
			type=parseType();
			if(tok.type==Tok!"i"){name=new Identifier(tok.name); nextToken();}
			if(tok.type==Tok!"="){nextToken();init=parseExpression(rbp!(Tok!","));}
			params~=new Parameter(stc,type,name,init);
			if(tok.type==Tok!",") nextToken();
			else{
				if(tok.type==Tok!"..."){vararg=VarArgs.dStyle; nextToken();}
				break;
			}
		}
		expect(Tok!")");
		return params;
	}
	void parsePostcondition(out CompoundStm post,out Identifier pres){ // out(pres){...}
		expect(Tok!"out");
		if(tok.type==Tok!"("){
			nextToken();
			pres=parseIdentifier();
			expect(Tok!")");
		}
		post=parseCompoundStm();
	}
	Declaration parseFunctionDeclaration(STC stc, Expression ret){
		Identifier name;
		VarArgs vararg;
		Expression constr;
		TemplateParameter[] tparam; bool isTemplate=false;
		Parameter[] params;
		if(ret) goto notspecial; // so that I don't have to test for ret multiple times
		if(tok.type==Tok!"this"){
			name=new ThisExp, nextToken();
			if(tok.type==Tok!"("&&peek().type==Tok!"this"){
				nextToken(), nextToken(), expect(Tok!")");
				params = [new PostblitParameter]; goto isspecial;
			}
		}else if(tok.type==Tok!"~" && peek().type==Tok!"this") name=new TildeThisExp, nextToken(), nextToken();
		else if(tok.type==Tok!"invariant"){mixin(doParse!("_","(",")")); name=new InvariantExp; params=[]; goto isspecial;}
		else{
			notspecial:
			if(tok.type!=Tok!"i") expectErr!"function name"(), name=new Identifier(null);
			else{name=new Identifier(tok.name);nextToken();}
		}
		if(tok.type==Tok!"(" && peekPastParen().type==Tok!"(") nextToken(), tparam=parseTemplateParameterList(), expect(Tok!")"), isTemplate=true;
		params=parseParameterList(vararg);
		isspecial:
		stc|=parseSTC!functionSTC();
		if(isTemplate) constr=parseOptTemplateConstraint();
		CompoundStm pre, post, bdy;
		Identifier pres;
		if(tok.type==Tok!"in"){
			nextToken(); pre=parseCompoundStm();
			if(tok.type==Tok!"out") parsePostcondition(post,pres);
		}else if(tok.type==Tok!"out"){
			parsePostcondition(post,pres);
			if(tok.type==Tok!"in"){nextToken();pre=parseCompoundStm();}
		}
		FunctionDecl r;
		if(tok.type==Tok!"{"||tok.type==Tok!"body"){
			if(pre||post) expect(Tok!"body");
			else if(tok.type==Tok!"body") nextToken();
			bdy=parseCompoundStm();
			r=new FunctionDef(new FunctionType(stc,ret,params,vararg),name,pre,post,pres,bdy);
		}else{
			if(!pre&&!post) expect(Tok!";");
			r=new FunctionDecl(new FunctionType(stc,ret,params,vararg),name,pre,post,pres);
		}
		return isTemplate ? new TemplateFunctionDecl(stc,tparam,constr,r) : r;
	}
	bool skipFunctionDeclaration(){ // does not skip Parameters, STC contracts or body. I think it does not have to.
		return skip(Tok!"i") && skip(Tok!"(");// && skipToUnmatched() && skip(Tok!")");//skipSTC!functionSTC();
	}
	Expression parseFunctionLiteralExp(){
		STC stc;
		Expression ret;
		bool isStatic = tok.type==Tok!"function";
		VarArgs vararg;
		Parameter[] params;
		bool hastype=false;
		if(isStatic || tok.type==Tok!"delegate"){
			nextToken();
			if(tok.type!=Tok!"(") stc=parseSTC!toplevelSTC(), ret=parseType();
			goto readp;
		}
		if(tok.type==Tok!"(") readp: params=parseParameterList(vararg), stc|=parseSTC!functionSTC(), hastype=true;
		auto bdy=parseCompoundStm();
		return new FunctionLiteralExp(hastype?new FunctionType(stc,ret,params,vararg):null,bdy,isStatic);
	}
	Declaration parseDeclarators(STC stc, Expression type){
		if(peek().type==Tok!"[") return parseCArrayDecl(stc,type);
		VarDecl[] r;
		do{
			auto name=parseIdentifier();
			Expression init;
			if(tok.type==Tok!"=") nextToken(), init=parseInitializerExp(false);
			r~=new VarDecl(stc,type,name,init);
			if(tok.type==Tok!",") nextToken();else break;
		}while(tok.type != Tok!";" && tok.type != Tok!"EOF"); 
		expect(Tok!";");
		return r.length>1?new Declarators(r):r[0];
	}
	bool skipDeclarators(){ // only makes sure there is at least one declarator
		return skip(Tok!"i");// && (skip(Tok!"=")||skip(Tok!",")||skip(Tok!";"));
	}
	Declaration parseCArrayDecl(STC stc, Expression type){ // support stupid C syntax
		Identifier name=parseIdentifier();
		Expression pfix=name, init=null;
		while(tok.type==Tok!"["){ // kludgy way of parsing, semantic will reverse the order
			auto save = saveState();
			bool isAA=skip()&&skipType()&&tok.type==Tok!"]";
			restoreState(save);
			if(isAA){mixin(doParse!("_",Type,"e","]")); pfix=new IndexExp(pfix,[e]);}
			else pfix=led!(Tok!"[")(pfix);//'Bug': allows int[1,2].
		}
		if(tok.type==Tok!"=") nextToken(), init=parseInitializerExp(false);
		expect(Tok!";");
		return new CArrayDecl(stc,type,name,pfix,init);
	}
	Declaration parseImportDecl(STC stc=STC.init){
		expect(Tok!"import");
		Expression[] symbols;
		Expression[] bind;
		bool isBindings=false;
		for(;;){
			Expression s=parseIdentifierList();
			if(tok.type==Tok!"=") nextToken(), s=new BinaryExp!(Tok!"=")(s,parseIdentifierList());
			else if(!isBindings&&tok.type==Tok!":"){nextToken(); isBindings=true; symbols~=s; continue;}
			(isBindings?bind:symbols)~=s;
			if(tok.type==Tok!",") nextToken();
			else break;
		}
		expect(Tok!";");
		if(isBindings) symbols[$-1]=new ImportBindingsExp(symbols[$-1],bind);
		return new ImportDecl(stc, symbols);
	}
	EnumDecl parseEnumDecl(STC stc=STC.init){
		expect(Tok!"enum");
		Identifier tag;
		Expression base;
		Expression[2][] members;
		if(tok.type==Tok!"i") tag=new Identifier(tok.name), nextToken();
		if(tok.type==Tok!":") nextToken(), base = parseType();
		expect(Tok!"{");
		for(;tok.type!=Tok!"}" && tok.type!=Tok!"EOF";){ // BUG: only uniform type allowed
			Expression e,i;
			if(tok.type==Tok!"i") e=new Identifier(tok.name), nextToken();
			else break;
			if(tok.type==Tok!"=") nextToken(), i=parseExpression(rbp!(Tok!","));
			members.length=members.length+1;
			members[$-1][0]=e;
			members[$-1][1]=i;
			if(tok.type!=Tok!"}") expect(Tok!",");
		}
		expect(Tok!"}");
		return new EnumDecl(stc,tag,base,members);
	}
	TemplateParameter[] parseTemplateParameterList(){
		TemplateParameter[] r;
		while(tok.type!=Tok!")" && tok.type!=Tok!"EOF"){
			Expression type;
			bool isAlias=tok.type==Tok!"alias", isTuple=false;
			if(isAlias) nextToken();
			else{
				auto tt=peek().type;
				if(tt!=Tok!"," && tt!=Tok!":" && tt!=Tok!"=" && tt!=Tok!")" && tt!=Tok!"...") type=parseType();
			}
			auto name=parseIdentifier();
			if(!type && tok.type==Tok!"...") isTuple=true, nextToken();
			Expression spec, init;
			if(!isTuple){
				if(tok.type==Tok!":"){
					nextToken(); spec=isAlias ? parseTypeOrExpression() : type?parseExpression(rbp!(Tok!",")):parseType();}
				if(tok.type==Tok!"=") {parseinit: nextToken(); init=isAlias ? parseTypeOrExpression() : type?parseExpression(rbp!(Tok!",")):parseType();}
				else if(tok.type==Tok!"*=" && spec){spec = new Pointer(spec); goto parseinit;} // EXTENSION
			}
			r~=new TemplateParameter(isAlias,isTuple,type,name,spec,init);
			if(tok.type==Tok!",") nextToken();
			else break;
		}
		return r;
	}
	Expression parseOptTemplateConstraint(){ // returns null if no template constraint
		if(tok.type!=Tok!"if") return null;
		mixin(doParse!("_","(",Expression,"e",")"));
		return e;
	}
	Declaration parseAggregateDecl(STC stc=STC.init, bool anonclass=false)in{assert(anonclass||tok.type==Tok!"struct"||tok.type==Tok!"union"||tok.type==Tok!"class"||tok.type==Tok!"interface");}body{
		enum{Struct,Union,Class,Interface}
		int type;
		Identifier name;
		TemplateParameter[] params; Expression constraint; bool isTemplate=false;
		ParentListEntry[] parents;
		if(!anonclass){
			switch(tok.type){
				case Tok!"struct": type=Struct; break;
				case Tok!"union": type=Union; break;
				case Tok!"class": type=Class; break;
				case Tok!"interface": type=Interface; break;
				default: assert(0);
			}
			nextToken();
			if(tok.type==Tok!"i") name=new Identifier(tok.name), nextToken();
			if(tok.type==Tok!"(") nextToken(),params=parseTemplateParameterList(),expect(Tok!")"),constraint=parseOptTemplateConstraint(),isTemplate=true;
		}else type=Class;
		if(type>=Class && (!anonclass&&tok.type==Tok!":")||(anonclass&&tok.type!=Tok!"{")){
			if(!anonclass) nextToken();
		readparents: for(;;){
				auto s=STC.init, nonefound=false;
				switch(tok.type){
					mixin({string r; foreach(x;protectionAttributes) r~=`case Tok!"`~x~`": s=STC`~x~`; nextToken(); goto case Tok!"i";`;return r;}());
					case Tok!".", Tok!"i": parents~=ParentListEntry(s,parseIdentifierList()); break;
					default: break readparents;
				}
				if(tok.type==Tok!",") nextToken();
				else break;
			}
			if(!parents.length) expectErr!"base class or interface"();
		}
		auto bdy=anonclass||tok.type!=Tok!";" ? parseCompoundDecl() : (nextToken(),null);
		auto r=
			type==Struct    ? new StructDecl(stc,name,bdy)           :
			type==Union     ? new UnionDecl(stc,name,bdy)            :
			type==Class     ? new ClassDecl(stc,name,parents,bdy)    :
			                  new InterfaceDecl(stc,name,parents,bdy);
		return isTemplate ? new TemplateAggregateDecl(stc,params,constraint,r) : r;
	}
	Expression parseVersionCondition(bool allowunittest=true){
		if(tok.type==Tok!"i"){auto e=new Identifier(tok.name); nextToken(); return e;}
		if(tok.type==Tok!"0"||tok.type==Tok!"0L"||tok.type==Tok!"0U"||tok.type==Tok!"0LU"){auto e=new LiteralExp(tok); nextToken(); return e;}
		if(tok.type==Tok!"unittest"&&allowunittest) return nextToken(), new Identifier("unittest");
		expectErr!"condition";
		return new ErrorExp;
	}
	Expression parseDebugCondition(){return parseVersionCondition(false);}
	Statement parseCondDeclBody(int flags){ // getParseProc fills in an argument called 'flags'
		if(flags&allowstm) return parseStatement();
		else return parseDeclDef(allowcompound);
	}
	enum{tryonly=1, allowcompound=2, allowstm=4}
	Declaration parseDeclDef(int flags=0){ // tryonly: return null if not start of decldef. allowcompound: allow { Decls }
		bool isStatic=false;
		bool isMix=false;
		STC stc=STC.init;
		alias CondDeclBody Body;
	    dispatch: 
		switch(tok.type){
			case Tok!";": nextToken(); return new Declaration(STC.init,null);
			case Tok!"module":
				mixin(rule!(ModuleDecl,Existing,"stc","_",IdentifierList,";"));
			case Tok!"static":
				nextToken();
				auto tt=tok.type;
				if(tt==Tok!"assert"){mixin(rule!(StaticAssertDecl,Existing,"stc","_","(",ArgumentList,")",";"));}
				if(tt==Tok!"if"){mixin(rule!(StaticIfDecl,Existing,"stc","_","(",AssignExp,")","NonEmpty",Body,"OPT"q{"else","NonEmpty",CondDeclBody}));}
				stc|=STCstatic;
				goto dispatch;
			case Tok!"debug":
				nextToken();
				if(tok.type==Tok!"="){mixin(rule!(DebugSpecDecl,Existing,"stc","_",DebugCondition,";"));}
				mixin(rule!(DebugDecl,Existing,"stc","OPT"q{"(",DebugCondition,")"},"NonEmpty",Body,"OPT"q{"else","NonEmpty",CondDeclBody}));
			case Tok!"version":
				nextToken();
				if(tok.type==Tok!"="){mixin(rule!(VersionSpecDecl,Existing,"stc","_",DebugCondition,";"));}
				mixin(rule!(VersionDecl,Existing,"stc","(",VersionCondition,")","NonEmpty",Body,"OPT"q{"else","NonEmpty",CondDeclBody}));
			case Tok!"pragma":
				mixin(rule!(PragmaDecl,Existing,"stc","_","(",ArgumentList,")",CondDeclBody)); // Body can be empty
			case Tok!"import": return parseImportDecl(stc);
			case Tok!"enum":
				auto x=peek(), y=peek(2);
				if(x.type!=Tok!"{" && x.type!=Tok!":" && x.type!=Tok!"i" || x.type==Tok!"i" && y.type!=Tok!"{" && y.type!=Tok!":") goto default;
				return parseEnumDecl(stc);
			case Tok!"mixin":
				nextToken(); if(tok.type==Tok!"("){mixin(rule!(MixinDecl,Existing,"stc","_",AssignExp,")",";"));}
				if(tok.type==Tok!"template"){isMix=true; goto case;}
				mixin(rule!(TemplateMixinDecl,Existing,"stc",IdentifierList,"OPT",Identifier,";"));
			case Tok!"template":
				mixin(rule!(TemplateDecl,Existing,"isMix",Existing,"stc","_",Identifier,"(",TemplateParameterList,")",OptTemplateConstraint,CompoundDecl));
			case Tok!"struct", Tok!"union", Tok!"class", Tok!"interface": return parseAggregateDecl(stc);
			case Tok!"unittest": return nextToken(), new UnitTestDecl(stc,parseCompoundStm());
			case Tok!"align":
				nextToken();
				if(tok.type!=Tok!"("){stc|=STCalign;goto dispatch;}
				nextToken();
				if(tok.type!=Tok!"0"&&tok.type!=Tok!"0U"&&tok.type!=Tok!"0L"&&tok.type!=Tok!"0LU") expectErr!"positive integer"(); // ENHANCEMENT: U,L,LU
				auto i=tok.int64;
				mixin(rule!(AlignDecl,Existing,"stc",Existing,"i","_",")",DeclDef));
			case Tok!"extern":
				LinkageType lt;
				nextToken();
				if(tok.type!=Tok!"("){stc|=STCextern; goto dispatch;}
				nextToken();
				if(tok.type!=Tok!"i") expectErr!"linkage type"();
				else{
					switch(tok.name){
						case "C": nextToken();
							if(tok.type==Tok!"++") lt=LinkageType.CPP, nextToken();
							else lt=LinkageType.C; break;
						case "D": nextToken(); lt=LinkageType.D; break;
						case "Windows": nextToken(); lt=LinkageType.Windows; break;
						case "Pascal": nextToken(); lt=LinkageType.Pascal; break;
						case "System": nextToken(); lt=LinkageType.System; break;
						default: error("unsupported linkage type "~tok.name); nextToken(); break;
					}
				}
				expect(Tok!")");
				return new ExternDecl(stc,lt,cast(Declaration)cast(void*)parseCondDeclBody(flags));
			case Tok!"typedef": nextToken(); return new TypedefDecl(stc,parseDeclaration());
			case Tok!"@": goto case;
			mixin(getTTCases(cast(string[])toplevelSTC,["align", "enum", "extern","static"]));
				STC nstc; // parseSTC might parse nothing in case it is actually a type constructor
				enum STCs={string[] r; foreach(x;toplevelSTC) if(x!="align"&&x!="enum"&&x!="extern"&&x!="static") r~=x;return r;}();
				stc|=nstc=parseSTC!STCs();
				if(tok.type==Tok!"{") return parseCompoundDecl(stc);
				else if(nstc) goto dispatch;
				else goto default;
			case Tok!"{": if(!stc&&!(flags&allowcompound)) goto default; return parseCompoundDecl(stc);
			case Tok!":": if(!stc&&!(flags&allowcompound)) goto default; nextToken(); return new AttributeDecl(stc,parseDeclDefs());
			default:
				if(!(flags&tryonly)) return parseDeclaration(stc);
				else return stc || isDeclaration() ? parseDeclaration(stc) : null;
		}
	}

	CompoundDecl parseCompoundDecl(STC stc=STC.init){
		expect(Tok!"{");
		Declaration[] r;
		while(tok.type!=Tok!"}" && tok.type!=Tok!"EOF"){
			r~=parseDeclDef();
		}
		expect(Tok!"}");
		return new CompoundDecl(stc,r);
	}

	Declaration[] parseDeclDefs(){
		Declaration[] x;
		while(tok.type!=Tok!"}" && tok.type!=Tok!"EOF") x~=parseDeclDef();
		return x;
	}

	auto parse(){
		Declaration[] r;
		while(tok.type!=Tok!"EOF"){
			if(tok.type==Tok!"}") expectErr!"declaration"(), nextToken();
			r~=parseDeclDefs();
		}
		return r;
	}
	//auto parse(){return skipDeclarations()?"wee, declarations":"boring statement";}
}

Declaration[] parse(Code code){
	return Parser(code).parse();
}
